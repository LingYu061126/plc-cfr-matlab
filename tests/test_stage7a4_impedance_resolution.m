function test_stage7a4_impedance_resolution(root,mode)
%TEST_STAGE7A4_IMPEDANCE_RESOLUTION Check the independent resolution audit.
%   With no mode, checks the frozen design without generating artifacts.
%   With smoke/formal, additionally checks the corresponding result tables.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='unit';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_impedance_resolution_config(base,'formal');
    assert(cfg.single_read_error_rms_ohm==1&&cfg.alpha==0.05&& ...
        isequal(cfg.repeat_counts,[1 4 16 64 256 1024])&& ...
        cfg.n_per_truth==100&&~cfg.use_parallel&&cfg.worker_count==0);
    assert(numel(cfg.frequency_hz)==61&&cfg.frequency_hz(1)==2e6&& ...
        cfg.frequency_hz(end)==30e6);
    assert(all(diff(cfg.branch_lengths_m)>0)&& ...
        cfg.branch_lengths_m(1)==0.0001&&cfg.branch_lengths_m(end)==0.01);
    assert(numel(unique([cfg.seed_A cfg.seed_F cfg.seed_C cfg.seed_T]))==4);
    old=stage7a4_mirror_observation_config(base,'formal');
    assert(isequal(cfg.frequency_hz,old.frequency_hz)&& ...
        isequal(cfg.main_scale_grid,old.main_scale_grid)&& ...
        isequal(cfg.branch_load_grid,old.branch_load_grid)&& ...
        cfg.separation_threshold==old.separation_threshold);
    [all4,~,~]=stage7a4_fixed_topologies(base);
    pair=all4([3 4]);theta=struct('main_length_scale',1, ...
        'branch_length_scale',1,'branch_load_scale',1, ...
        'first_segment_scale',1,'source_impedance_ohm',50, ...
        'receiver_impedance_ohm',50);
    gap=zeros(1,2);
    for j=1:2
        for k=1:2
            pair(k).network.branches.length=cfg.branch_lengths_m(j);
            pair(k).network.branches.load=cfg.branch_load_ohm;
        end
        a=stage7a4_forward_state(pair(1).network,theta,base, ...
            cfg.frequency_hz,cfg.state);
        b=stage7a4_forward_state(pair(2).network,theta,base, ...
            cfg.frequency_hz,cfg.state);
        gap(j)=sqrt(mean(abs(a.Zin-b.Zin).^2));
    end
    assert(all(isfinite(gap))&&gap(1)>0&&gap(2)>gap(1)&&gap(2)<1, ...
        'The weak-stub control does not resolve the planned sub-ohm grid.');
    if strcmp(mode,'unit')
        fprintf('PASS test_stage7a4_impedance_resolution(unit): design and sub-ohm control\n');
        return;
    end
    assert(ismember(mode,{'smoke','formal'}));
    cfg=stage7a4_impedance_resolution_config(base,mode);out=cfg.output_dir;
    design=readtable(fullfile(out,'resolution_design.csv'),'TextType','string');
    samples=readtable(fullfile(out,'resolution_samples.csv'),'TextType','string');
    summary=readtable(fullfile(out,'resolution_summary.csv'),'TextType','string');
    frontier=readtable(fullfile(out,'resolution_frontier.csv'),'TextType','string');
    source=readtable(fullfile(out,'resolution_source_identity.csv'),'TextType','string');
    nl=numel(cfg.branch_lengths_m);nr=numel(cfg.repeat_counts);
    assert(height(design)==nl&& ...
        height(samples)==nl*2*nr*2*cfg.n_per_truth*2&& ...
        height(summary)==nl*2*nr*2*3&&height(frontier)==2*nr*2);
    assert(all(samples.effective_error_rms_ohm== ...
        cfg.single_read_error_rms_ohm./sqrt(samples.repeat_count), 'all'));
    assert(all(ismember(samples.decision_state, ...
        ["UNIQUE_CONFIDENT","MULTIPLE_AMBIGUOUS","LOW_CONFIDENCE","REJECTED"])));
    assert(~any(samples.correct_unique & samples.false_unique));
    assert(all(summary.correct_unique_k+summary.false_unique_k<=summary.n));
    assert(all(summary.truth_covered_k<=summary.n));
    assert(all(source.verification_baseline_commit== ...
        string(cfg.verification_baseline_commit)));
    for i=1:height(source)
        p=fullfile(root,strrep(char(source.relative_path(i)),'/',filesep));
        assert(exist(p,'file')==2);
        d=dir(p);assert(d.bytes==source.size_bytes(i));
        assert(strcmp(stage4a7_2_r2_sha256_file(p),char(source.sha256(i))));
    end
    fprintf('PASS test_stage7a4_impedance_resolution(%s): %d sample-method rows\n', ...
        mode,height(samples));
end
