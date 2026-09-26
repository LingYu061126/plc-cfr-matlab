function test_stage7a4_continuous_fit(root,mode)
%TEST_STAGE7A4_CONTINUOUS_FIT Verify bounded fit and archived diagnostics.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='unit';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_continuous_fit_config(base,'formal');
    assert(cfg.single_read_error_rms_ohm==1&&~cfg.use_parallel&& ...
        isequal(cfg.repeat_counts,[1 256])&& ...
        isequal(cfg.branch_lengths_m,[0.0001 0.002 0.01]));
    assert(numel(unique([cfg.seed_A cfg.seed_F cfg.seed_C ...
        cfg.seed_T cfg.seed_D]))==5);
    [all4,~,~]=stage7a4_fixed_topologies(base);
    pair=all4([3 4]);pair(1).topology_id='WEAK_M1';
    pair(2).topology_id='WEAK_M3';
    for k=1:2
        pair(k).network.branches.length=0.01;
        pair(k).network.branches.load=cfg.branch_load_ohm;
    end
    [m,l]=ndgrid(cfg.main_scale_grid,cfg.branch_load_grid);
    params=[m(:),l(:),ones(numel(m),1)];
    templates=cell(2,1);
    for k=1:2
        templates{k}=complex(zeros(size(params,1),numel(cfg.frequency_hz)));
        for p=1:size(params,1)
            z=stage7a4_forward_state(pair(k).network, ...
                theta_at(params(p,1),params(p,2)),base, ...
                cfg.frequency_hz,cfg.state);
            templates{k}(p,:)=z.Zin;
        end
    end
    bank=struct('templates',{templates},'params',params, ...
        'candidate_ids',{{'WEAK_M1','WEAK_M3'}}, ...
        'view_names',{{'Zin50'}},'frequency_hz',cfg.frequency_hz, ...
        'identity','unit');
    truth_theta=theta_at(1.013,0.9);
    z=stage7a4_forward_state(pair(1).network,truth_theta,base, ...
        cfg.frequency_hz,cfg.state);
    p=stage7a4_continuous_profile_zin(z.Zin,pair,bank,base,cfg,1);
    assert(p.grid_distances(1)>p.continuous_distances(1)&& ...
        p.continuous_distances(1)<0.01&& ...
        abs(p.continuous_params(1,1)-truth_theta.main_length_scale)<1e-4&& ...
        all(p.continuous_distances<=p.grid_distances+1e-10)&& ...
        all(p.exitflag>0));
    assert(all(p.continuous_params(:,1)>=cfg.main_scale_bounds(1))&& ...
        all(p.continuous_params(:,1)<=cfg.main_scale_bounds(2))&& ...
        all(p.continuous_params(:,2)>=cfg.load_scale_bounds(1))&& ...
        all(p.continuous_params(:,2)<=cfg.load_scale_bounds(2)));
    if strcmp(mode,'unit')
        fprintf('PASS test_stage7a4_continuous_fit(unit): bounded noise-free fit\n');
        return;
    end
    assert(ismember(mode,{'smoke','formal'}));
    cfg=stage7a4_continuous_fit_config(base,mode);out=cfg.output_dir;
    design=readtable(fullfile(out,'continuous_design.csv'),'TextType','string');
    checks=readtable(fullfile(out,'continuous_clean_diagnostics.csv'), ...
        'TextType','string');
    samples=readtable(fullfile(out,'continuous_samples.csv'),'TextType','string');
    summary=readtable(fullfile(out,'continuous_summary.csv'),'TextType','string');
    frontier=readtable(fullfile(out,'continuous_frontier.csv'),'TextType','string');
    source=readtable(fullfile(out,'continuous_source_identity.csv'),'TextType','string');
    nl=numel(cfg.branch_lengths_m);nr=numel(cfg.repeat_counts);
    assert(height(design)==nl&& ...
        height(checks)==nl*2*2*cfg.n_diagnostic_per_truth&& ...
        height(samples)==nl*2*nr*2*cfg.n_test_per_truth*4&& ...
        height(summary)==nl*2*nr*4*3&&height(frontier)==2*nr*4);
    assert(all(samples.continuous_distance_truth<= ...
        samples.grid_distance_truth+1e-10));
    assert(~any(samples.correct_unique & samples.false_unique));
    assert(all(summary.correct_unique_k+summary.false_unique_k<=summary.n));
    assert(all(ismember(samples.decision_state, ...
        ["UNIQUE_CONFIDENT","MULTIPLE_AMBIGUOUS","LOW_CONFIDENCE","REJECTED"])));
    for i=1:height(source)
        path=fullfile(root,strrep(char(source.relative_path(i)),'/',filesep));
        assert(exist(path,'file')==2);
        d=dir(path);assert(d.bytes==source.size_bytes(i));
        assert(strcmp(stage4a7_2_r2_sha256_file(path),char(source.sha256(i))));
    end
    fprintf('PASS test_stage7a4_continuous_fit(%s): %d sample-method rows\n', ...
        mode,height(samples));
end

function theta=theta_at(main,load)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end
