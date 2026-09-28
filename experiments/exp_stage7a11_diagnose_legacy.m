function result=exp_stage7a11_diagnose_legacy(root,run_id)
%EXP_STAGE7A11_DIAGNOSE_LEGACY Rebuild frozen D observations without edits.
%   Reads Stage 7A.10 confirm1 and R.1 formal CSV; writes only Stage 7A.11.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(run_id),run_id='audit1';end
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')),'stage7a11:RunId');
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    out=fullfile(root,'results','data','stage7a_11','diagnostic',run_id);
    assert(exist(out,'dir')~=7,'stage7a11:ExistingRun');
    t=tic;base=default_config(root);cfg=stage7a10_config(base,'formal');
    [candidates,truths]=graphs(base);
    bank=stage7a4_template_bank(candidates,base,cfg);
    old=load(fullfile(root,'results','data','stage7a_10','formal', ...
        'confirm1','config_snapshot.mat'),'models','metadata','library');
    assert(strcmp(char(old.metadata.bank_identity),bank.identity), ...
        'stage7a11:FrozenBankIdentity');
    ref10=readtable(fullfile(root,'results','data','stage7a_10','formal', ...
        'confirm1','samples.csv'),'TextType','string','Delimiter',',');
    ref10=ref10(ref10.method=="D_adaptive",:);
    refR=readtable(fullfile(root,'results','data','stage7a_10_r1','formal', ...
        'formal1','samples.csv'),'TextType','string','Delimiter',',');
    refR=refR(refR.method=="D_adaptive",:);
    rows=repmat(proto(),0,1);names={'original_three','expanded_six','diagnostic_pair'};
    scenarios={'T20','T10','T_node_port_error', ...
        'T_termination_error','T_load_drift'};
    conditions={'standard','standard','node_port_error', ...
        'termination_error','load_drift'};
    seeds=[900000000 910000000 911000000 912000000 913000000];
    reps=[30 15 15 15 15];snrs=[20 10 20 20 20];
    for h=1:numel(scenarios)
        ss=stage7a4_generate_split(truths,1:8,base,cfg,seeds(h), ...
            reps(h),snrs(h),conditions{h});
        for i=1:numel(ss)
            [part,~]=audit_one(ss(i).observed,ss(i),truths,bank,old,names, ...
                'stage7a10_confirm1',scenarios{h},ref10);
            rows=[rows;part]; %#ok<AGROW>
        end
    end
    cfgR=stage7a10r1_config(base,'formal');
    ss=stage7a4_generate_split(truths,1:8,base,cfgR,cfgR.seed_T, ...
        cfgR.n_T_per_topology,20,'standard');
    conditions={'baseline','node_port_bias','node_acquisition_load_drift'};
    for i=1:numel(ss)
        sample=ss(i);rep=mod(sample.parameter_seed,100000);
        sign=1;if mod(rep,2)==0,sign=-1;end
        for c=1:3
            kind=conditions{c};observed=sample.observed;
            if c>1
                if c==2,bias=sign*cfgR.node_port_bias_fraction;
                else,bias=sign*cfgR.node_acquisition_load_drift_fraction;end
                [~,observed]=stage7a10r1_measure_views( ...
                    truths(sample.truth_global_index).network,sample.theta, ...
                    base,cfgR,sample.noise_seed,20,kind,bias);
            end
            [part,~]=audit_one(observed,sample,truths,bank,old,names, ...
                'stage7a10r1_formal1',kind,refR);
            rows=[rows;part]; %#ok<AGROW>
        end
    end
    data=struct2table(rows);
    assert(height(data)==height(ref10)+height(refR), ...
        'stage7a11:LegacyRowCount');
    metadata=table(string(version),string(computer('arch')), ...
        string(bank.identity),height(data),toc(t), ...
        'VariableNames',{'matlab_version','computer_arch', ...
        'bank_identity','audited_rows','wall_s'});
    mkdir(out);writetable(data,fullfile(out,'legacy_diagnostics.csv'));
    writetable(metadata,fullfile(out,'metadata.csv'));
    fprintf('PASS Stage 7A.11 legacy audit: %d D rows match frozen records.\n',height(data));
    result=struct('output_dir',out,'rows',height(data));
end

function [rows,matched]=audit_one(observed,sample,truths,bank,old,names,source,scenario,ref)
    rows=repmat(proto(),3,1);matched=0;
    truth=truths(sample.truth_global_index).topology_id;
    for q=1:3
        ix=old.library{q};model=old.models{5,q};
        z=stage7a10_decide(observed,bank,model);
        ez=stage7a4_decide(observed,bank,old.models{6,q});
        f=stage7a4_profile_views(observed,bank,ix,5,model.sigma);
        keep=f.distances<=model.first_threshold;
        [~,order]=sort(f.distances);local=find(keep);
        if numel(local)==1,local=unique([local order(2)]);end
        pair=string("");worst=NaN;
        if numel(local)>1 && z.selected_view>0
            v=find(model.selector.extra_views==z.selected_view,1);
            worst=Inf;
            for a=1:numel(local)-1
                for b=a+1:numel(local)
                    sep=model.selector.separation(ix(local(a)),ix(local(b)),v);
                    if sep<worst
                        worst=sep;pair=string(bank.candidate_ids{ix(local(a))})+ ...
                            "/"+string(bank.candidate_ids{ix(local(b))});
                    end
                end
            end
        end
        mask=ref.library==string(names{q}) & ref.truth_id==string(truth) & ...
            ref.noise_seed==sample.noise_seed;
        if strcmp(source,'stage7a10_confirm1'),mask=mask & ref.scenario==string(scenario);
        else,mask=mask & ref.scenario==string(scenario);end
        hit=ref(mask,:);
        assert(height(hit)==1,'stage7a11:LegacyKey');
        if ~(hit.decision_state==string(z.decision_state) && ...
                hit.decision_reason==string(z.decision_reason) && ...
                hit.candidate_set==string(z.candidate_set) && ...
                hit.best_candidate==string(z.best_candidate) && ...
                hit.selected_view==z.selected_view && ...
                (abs(hit.distance-z.distance)<1e-9 || ...
                (isinf(hit.distance) && isinf(z.distance))))
            error('stage7a11:LegacyDecisionMismatch', ...
                '%s %s %s seed %d: archived %s/%s/%g; rebuilt %s/%s/%g', ...
                source,scenario,names{q},sample.noise_seed, ...
                char(hit.decision_state),char(hit.best_candidate),hit.distance, ...
                z.decision_state,z.best_candidate,z.distance);
        end
        r=proto();r.source=string(source);r.scenario=string(scenario);
        r.library=string(names{q});r.truth_id=string(truth);
        r.truth_in_library=ismember(truth,bank.candidate_ids(ix));
        r.parameter_seed=sample.parameter_seed;r.noise_seed=sample.noise_seed;
        r.first_set=string(strjoin(bank.candidate_ids(ix(keep)),','));
        r.truth_in_first=r.truth_in_library && ...
            ismember(truth,bank.candidate_ids(ix(keep)));
        r.first_distances=string(mat2str(f.distances,16));
        r.first_thresholds=string(mat2str(model.first_threshold,16));
        r.final_set=string(z.candidate_set);
        r.truth_in_final=r.truth_in_library && ...
            ismember(truth,strsplit(z.candidate_set,','));
        r.final_distances=string(mat2str(z.all_distances,16));
        r.final_thresholds=string(mat2str(model.class_threshold,16));
        r.selected_view=z.selected_view;r.worst_pair=pair;
        r.worst_pair_separation=worst;
        r.best_candidate=string(z.best_candidate);
        [~,final_order]=sort(z.all_distances);
        r.second_candidate=string(bank.candidate_ids{ix(final_order(2))});
        r.best_distance=z.distance;r.second_distance=z.second_distance;
        r.margin=z.margin;r.margin_threshold=model.margin_threshold;
        r.fit_threshold=model.fit_threshold;r.fit_pass=z.fit_accepted;
        r.decision_state=string(z.decision_state);
        r.decision_reason=string(z.decision_reason);
        r.e_state=string(ez.decision_state);
        r.e_truth_unique=strcmp(ez.decision_state,'UNIQUE_CONFIDENT') && ...
            strcmp(ez.best_candidate,truth);
        rows(q)=r;matched=matched+1;
    end
end

function [candidates,truths]=graphs(base)
    [~,~,~,catalog]=stage7a6_candidate_space(base);
    ids={'G001','G002','G003','MIRROR_M3','ADD_M1_M3', ...
        'EXT_111','EXT_021','MID30'};
    truths=repmat(struct('topology_id','','network',struct()),1,8);
    all={catalog.topology_id};
    for i=1:8
        j=find(strcmp(all,ids{i}),1);assert(~isempty(j));
        truths(i)=struct('topology_id',ids{i},'network',catalog(j).network);
    end
    candidates=truths(1:6);
end
function r=proto()
    r=struct('source',"",'scenario',"",'library',"",'truth_id',"", ...
        'truth_in_library',false,'parameter_seed',0,'noise_seed',0, ...
        'first_set',"",'truth_in_first',false,'first_distances',"", ...
        'first_thresholds',"",'final_set',"",'truth_in_final',false, ...
        'final_distances',"",'final_thresholds',"",'selected_view',0, ...
        'worst_pair',"",'worst_pair_separation',NaN, ...
        'best_candidate',"",'second_candidate',"", ...
        'best_distance',NaN,'second_distance',NaN, ...
        'margin',NaN,'margin_threshold',NaN,'fit_threshold',NaN, ...
        'fit_pass',false,'decision_state',"",'decision_reason',"", ...
        'e_state',"",'e_truth_unique',false);
end
