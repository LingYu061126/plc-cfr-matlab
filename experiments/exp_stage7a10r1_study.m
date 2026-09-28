function result=exp_stage7a10r1_study(root,mode,run_id)
%EXP_STAGE7A10R1_STUDY Paired synthetic node-state pressure, no recalibration.
%   Truth, graph ID and generating theta remain in the experiment layer;
%   scoring receives only observations, fixed bank and frozen models.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='smoke1';end
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')), ...
        'stage7a10r1:RunId');
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    t_all=tic;base=default_config(root);cfg=stage7a10r1_config(base,mode);
    out=fullfile(cfg.output_dir,run_id);
    assert(exist(out,'dir')~=7,'stage7a10r1:ExistingRun');
    old=load(fullfile(root,'results','data','stage7a_10','formal', ...
        'confirm1','config_snapshot.mat'),'models','methods','library','metadata');
    assert(strcmp(old.metadata.run_id,'confirm1')&& ...
        old.metadata.T_seed==900000000,'stage7a10r1:FrozenModelIdentity');
    [candidates,truths]=topologies(base);
    bank=stage7a4_template_bank(candidates,base,cfg);
    assert(strcmp(bank.identity,char(old.metadata.bank_identity)), ...
        'stage7a10r1:BankIdentity');
    for q=1:numel(old.library)
        assert(isequal(old.library{q},library_indices(q)), ...
            'stage7a10r1:LibraryIdentity');
        for m=1:numel(old.methods)
            assert(strcmp(old.models{m,q}.bank_identity,bank.identity), ...
                'stage7a10r1:ModelIdentity');
        end
    end
    [base_samples,~]=stage7a4_generate_split(truths,1:numel(truths), ...
        base,cfg,cfg.seed_T,cfg.n_T_per_topology,20,'standard');
    conditions={'baseline','node_port_bias','node_acquisition_load_drift'};
    rows=repmat(sample_row(),0,1);
    observation_calls=numel(base_samples)*numel(cfg.states);
    for i=1:numel(base_samples)
        sample=base_samples(i);
        rep=mod(sample.parameter_seed,100000);
        sign=1;if mod(rep,2)==0,sign=-1;end
        for c=1:numel(conditions)
            kind=conditions{c};bias=0;
            if c==1
                clean=sample.clean;observed=sample.observed;
            else
                if c==2,bias=sign*cfg.node_port_bias_fraction;
                else,bias=sign*cfg.node_acquisition_load_drift_fraction;end
                [clean,observed,calls]=stage7a10r1_measure_views( ...
                    truths(sample.truth_global_index).network,sample.theta, ...
                    base,cfg,sample.noise_seed,20,kind,bias);
                observation_calls=observation_calls+calls;
                assert(isequal(clean{5},sample.clean{5})&& ...
                    isequal(observed{5},sample.observed{5})&& ...
                    isequal(clean{6},sample.clean{6})&& ...
                    isequal(observed{6},sample.observed{6}), ...
                    'stage7a10r1:FirstAcquisitionChanged');
            end
            for q=1:numel(old.library)
                ix=old.library{q};
                for m=1:numel(old.methods)
                    timer=tic;model=old.models{m,q};name=old.methods(m).name;
                    if strcmp(name,'D_adaptive')
                        z=stage7a10_decide(observed,bank,model);
                        selected=z.selected_view;
                        if selected==0,used=5;
                        elseif selected>=12,used=[selected-1 selected];
                        else,used=[5 selected];end
                    else
                        z=stage7a4_decide(observed,bank,model);
                        selected=0;used=model.view_indices;
                    end
                    rr=sample_row();rr.scenario=string(kind);
                    rr.method=string(name);rr.library=library_name(q);
                    rr.truth_id=string(truths(sample.truth_global_index).topology_id);
                    rr.truth_signature=string(stage6b_network_signature( ...
                        truths(sample.truth_global_index).network));
                    rr.truth_in_library=ismember(char(rr.truth_id),bank.candidate_ids(ix));
                    rr.parameter_seed=sample.parameter_seed;
                    rr.noise_seed=sample.noise_seed;rr.replicate=rep;
                    rr.selected_view=selected;rr.used_views=string(mat2str(used));
                    rr.bias_fraction=bias;
                    delta=zeros(1,numel(used));
                    for v=1:numel(used)
                        delta(v)=sqrt(mean(abs(clean{used(v)}-sample.clean{used(v)}).^2));
                    end
                    rr.used_clean_rms_delta=max(delta);
                    rr.effective_on_used_observation=any(delta>0);
                    rr.best_candidate=string(z.best_candidate);
                    rr.candidate_set=string(z.candidate_set);
                    rr.candidate_set_size=z.candidate_set_size;
                    rr.decision_state=string(z.decision_state);
                    rr.decision_reason=string(z.decision_reason);
                    rr.truth_in_set=rr.truth_in_library&& ...
                        ismember(char(rr.truth_id),strsplit(z.candidate_set,','));
                    rr.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                        strcmp(z.best_candidate,char(rr.truth_id));
                    rr.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                        ~rr.correct_unique;
                    rr.distance=z.distance;rr.margin=z.margin;
                    rr.wall_s=toc(timer);
                    [rr.source_excitations,rr.node_port_switches, ...
                        rr.termination_switches,rr.internal_receiver_nodes]= ...
                        cost(name,selected);
                    rows(end+1)=rr; %#ok<AGROW>
                end
            end
        end
        if mod(i,30)==0
            fprintf('Stage 7A.10-R.1 %s: %d/%d physical observations scored.\n', ...
                mode,i,numel(base_samples));
        end
    end
    samples=struct2table(rows);derived=stage7a10r1_derive_statistics(samples);
    pairs=paired_changes(samples);
    metadata=table(string(cfg.stage),string(mode),string(run_id), ...
        string(cfg.audit_baseline_commit),string(old.metadata.bank_identity), ...
        string(version),string(computer('arch')),0,cfg.seed_T, ...
        cfg.n_T_per_topology,numel(truths),numel(base_samples), ...
        bank.forward_calls,observation_calls,bank.logical_cache_bytes,toc(t_all), ...
        'VariableNames',{'stage','mode','run_id','audit_baseline_commit', ...
        'bank_identity','matlab_version','architecture','parallel_workers', ...
        'T_seed','repetitions_per_graph','physical_graphs','physical_observations', ...
        'template_forward_calls','observation_forward_calls', ...
        'template_logical_bytes','wall_s'});
    mkdir(out);
    writetable(samples,fullfile(out,'samples.csv'));
    writetable(derived,fullfile(out,'derived_statistics.csv'));
    writetable(pairs,fullfile(out,'paired_changes.csv'));
    writetable(metadata,fullfile(out,'metadata.csv'));
    save(fullfile(out,'config_snapshot.mat'),'cfg','metadata');
    fprintf('PASS Stage 7A.10-R.1 %s %s: %d paired observations, %d scored rows.\n', ...
        mode,run_id,numel(base_samples),height(samples));
    result=struct('output_dir',out,'metadata',metadata, ...
        'sample_rows',height(samples));
end

function [candidates,truths]=topologies(base)
    [pool,~,~,catalog]=stage7a6_candidate_space(base);
    wanted={'G001','G002','G003','MIRROR_M3','ADD_M1_M3', ...
        'EXT_111','EXT_021','MID30'};
    truths=repmat(struct('topology_id','','network',struct()),1,numel(wanted));
    ids={catalog.topology_id};
    for i=1:numel(wanted)
        j=find(strcmp(ids,wanted{i}),1);assert(~isempty(j),'stage7a10r1:Graph');
        truths(i)=struct('topology_id',wanted{i},'network',catalog(j).network);
    end
    candidates=truths(1:6);
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),truths, ...
        'UniformOutput',false);
    assert(numel(unique(sigs))==8&&numel(pool)==17,'stage7a10r1:GraphIdentity');
end
function ix=library_indices(q)
    bank={1:3,1:6,[3 4]};ix=bank{q};
end
function name=library_name(q)
    names=["original_three","expanded_six","diagnostic_pair"];
    name=names(q);
end
function [exc,node_switch,term_switch,receivers]=cost(name,selected)
    exc=1;node_switch=0;term_switch=0;receivers=0;
    if strcmp(name,'B_H50_H200'),exc=2;term_switch=1;end
    if ismember(name,{'C_M2_node','C_M2_simple_joint'}),receivers=1;end
    if strcmp(name,'D_adaptive')
        if selected>0,exc=2;end
        if selected>=12,node_switch=1;receivers=1;
        elseif selected>0,term_switch=1;end
    end
end
function r=sample_row()
    r=struct('scenario',"",'method',"",'library',"",'truth_id',"", ...
        'truth_signature',"",'truth_in_library',false,'parameter_seed',0, ...
        'noise_seed',0,'replicate',0,'selected_view',0,'used_views',"", ...
        'bias_fraction',0,'used_clean_rms_delta',0, ...
        'effective_on_used_observation',false,'best_candidate',"", ...
        'candidate_set',"",'candidate_set_size',0,'decision_state',"", ...
        'decision_reason',"",'truth_in_set',false,'correct_unique',false, ...
        'false_unique',false,'distance',NaN,'margin',NaN,'wall_s',NaN, ...
        'source_excitations',0,'node_port_switches',0, ...
        'termination_switches',0,'internal_receiver_nodes',0);
end
function pairs=paired_changes(samples)
    base=samples(samples.scenario=="baseline",:);
    others=samples(samples.scenario~="baseline",:);
    proto=struct('scenario',"",'method',"",'library',"",'truth_id',"", ...
        'noise_seed',0,'selected_view',0,'effective',false, ...
        'baseline_state',"",'perturbed_state',"",'state_changed',false, ...
        'baseline_correct_unique',false,'perturbed_correct_unique',false, ...
        'baseline_truth_in_set',false,'perturbed_truth_in_set',false);
    rows=repmat(proto,height(others),1);
    keybase=string(base.method)+"/"+string(base.library)+"/"+string(base.noise_seed);
    assert(numel(unique(keybase))==height(base),'stage7a10r1:PairIdentity');
    map=containers.Map(cellstr(keybase),num2cell(1:height(base)));
    for i=1:height(others)
        k=char(string(others.method(i))+"/"+string(others.library(i))+"/"+ ...
            string(others.noise_seed(i)));
        assert(isKey(map,k),'stage7a10r1:MissingPair');
        b=base(map(k),:);v=others(i,:);
        assert(b.truth_id==v.truth_id&&b.parameter_seed==v.parameter_seed&& ...
            b.selected_view==v.selected_view,'stage7a10r1:PairMismatch');
        rows(i)=struct('scenario',v.scenario,'method',v.method, ...
            'library',v.library,'truth_id',v.truth_id, ...
            'noise_seed',v.noise_seed,'selected_view',v.selected_view, ...
            'effective',v.effective_on_used_observation, ...
            'baseline_state',b.decision_state,'perturbed_state',v.decision_state, ...
            'state_changed',b.decision_state~=v.decision_state, ...
            'baseline_correct_unique',b.correct_unique, ...
            'perturbed_correct_unique',v.correct_unique, ...
            'baseline_truth_in_set',b.truth_in_set, ...
            'perturbed_truth_in_set',v.truth_in_set);
    end
    pairs=struct2table(rows);
end
