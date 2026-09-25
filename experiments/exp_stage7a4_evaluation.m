function result=exp_stage7a4_evaluation(root,mode,explore)
%EXP_STAGE7A4_EVALUATION Independent A/F calibration and fixed T tests.
%   All observations are synthetic and scored without passing truth labels
%   or generating parameters to the scoring/decision functions.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    if nargin<3||isempty(explore),explore=exp_stage7a4_exploration(root,mode);end
    cfg=explore.cfg;base=explore.base;all4=explore.all4;bank=explore.bank;
    pair=explore.pair_indices;original=explore.original_indices;
    sigma=explore.sigma;schemes=stage7a4_scheme_catalog(cfg, ...
        explore.selected_B_index,explore.selected_C_index);
    whole=tic;phase=struct('calibration_generation_s',0, ...
        'main_calibration_s',0,'asymmetry_calibration_s',0, ...
        'test_generation_s',0,'scoring_s',0,'summary_s',0);
    g=tic;
    [a,ta]=stage7a4_generate_split(all4,1:4,base,cfg,cfg.seed_A, ...
        cfg.n_A_per_topology,cfg.cfr_snr_db,'standard');
    [f,tf]=stage7a4_generate_split(all4,1:4,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_topology,cfg.cfr_snr_db,'standard');
    phase.calibration_generation_s=toc(g);
    [models,calrows]=calibrate_all(a,f,bank,schemes,sigma,cfg,pair,original,'main');
    phase.main_calibration_s=toc(g)-phase.calibration_generation_s;
    fprintf('Stage 7A.4 %s: A/F generated %.3f/%.3f s; %d schemes calibrated.\n', ...
        mode,ta,tf,numel(schemes));
    % The first-segment asymmetry expands nuisance support. Rebuild and
    % independently recalibrate E/A/F before scoring any asymmetric T row.
    g=tic;asym_bank=stage7a4_template_bank(all4,base,cfg,cfg.asymmetry_grid);
    [ea,~]=stage7a4_generate_split(all4,1:4,base,cfg,cfg.seed_E_asym, ...
        cfg.n_E_per_topology,cfg.cfr_snr_db,'first_segment_asymmetry');
    sigma_asym=stage7a4_calibrate_view_scales(ea,cfg);
    [aa,~]=stage7a4_generate_split(all4,1:4,base,cfg,cfg.seed_A_asym, ...
        cfg.n_A_per_topology,cfg.cfr_snr_db,'first_segment_asymmetry');
    [fa,~]=stage7a4_generate_split(all4,1:4,base,cfg,cfg.seed_F_asym, ...
        cfg.n_F_per_topology,cfg.cfr_snr_db,'first_segment_asymmetry');
    [asym_models,asym_calrows]=calibrate_all(aa,fa,asym_bank,schemes, ...
        sigma_asym,cfg,pair,original,'asymmetry');
    phase.asymmetry_calibration_s=toc(g);
    calrows=[calrows(:);asym_calrows(:)];
    fprintf('Stage 7A.4 %s: asymmetric search rebuilt/calibrated %.3f s, cache %d bytes.\n', ...
        mode,phase.asymmetry_calibration_s,asym_bank.logical_cache_bytes);
    g=tic;datasets=cell(1,6);scenario=cell(1,6);
    scenario{1}='T20';[datasets{1},~]=stage7a4_generate_split(all4,1:4,base,cfg, ...
        cfg.seed_T20,cfg.n_T_per_topology,cfg.cfr_snr_db,'standard');
    scenario{2}='T10';[datasets{2},~]=stage7a4_generate_split(all4,1:4,base,cfg, ...
        cfg.seed_T10,cfg.n_T_per_topology,cfg.shift_snr_db,'standard');
    scenario{3}='T_first_segment_asymmetry';
    [datasets{3},~]=stage7a4_generate_split(all4,1:4,base,cfg, ...
        cfg.seed_Tasym,cfg.n_extra_per_topology,cfg.cfr_snr_db,'first_segment_asymmetry');
    names={'T_termination_error','T_load_drift','T_node_port_error'};
    conditions={'termination_error','load_drift','node_port_error'};
    for k=1:3
        scenario{3+k}=names{k};
        [datasets{3+k},~]=stage7a4_generate_split(all4,1:4,base,cfg, ...
            cfg.seed_Tstress+(k-1)*1000000,cfg.n_extra_per_topology, ...
            cfg.cfr_snr_db,conditions{k});
    end
    phase.test_generation_s=toc(g);
    fprintf('Stage 7A.4 %s: six independent T scenario batches generated %.3f s.\n', ...
        mode,phase.test_generation_s);
    g=tic;rows=repmat(sample_row(),0,1);
    for s=1:numel(datasets)
        use_asym=(s==3);active_bank=bank;active_models=models;
        if use_asym,active_bank=asym_bank;active_models=asym_models;end
        block=datasets{s};
        for i=1:numel(block)
            truth=block(i).truth_global_index;
            for j=1:numel(schemes)
                if ismember(truth,pair)
                    z=stage7a4_decide(block(i).observed,active_bank,active_models{j,1});
                    rows(end+1)=make_sample_row(block(i),scenario{s},schemes(j), ...
                        'diagnostic_pair',z,all4,active_models{j,1},true); %#ok<AGROW>
                end
                z=stage7a4_decide(block(i).observed,active_bank,active_models{j,2});
                rows(end+1)=make_sample_row(block(i),scenario{s},schemes(j), ...
                    'original_three',z,all4,active_models{j,2},ismember(truth,original)); %#ok<AGROW>
            end
        end
        fprintf('Stage 7A.4 %s: scored %s (%d physical observations).\n', ...
            mode,scenario{s},numel(block));
    end
    phase.scoring_s=toc(g);
    g=tic;summary=summarize_rows(rows,schemes,scenario);
    info=information_rows(bank,asym_bank,schemes,sigma,sigma_asym,pair);
    [controls,control_bank,control_topologies]=control_rows(base,cfg,schemes,sigma);
    control_decisions=control_decision_rows(control_bank,control_topologies, ...
        base,cfg,schemes,sigma);
    [nominal_spectra,node_loading]=nominal_response_rows(bank,cfg,[3 4]);
    phase.summary_s=toc(g);phase.total_evaluation_s=toc(whole);
    out=cfg.output_dir;
    writetable(struct2table(schemes),fullfile(out,'stage7a4_scheme_catalog.csv'));
    writetable(struct2table(calrows),fullfile(out,'stage7a4_calibration.csv'));
    writetable(struct2table(info),fullfile(out,'stage7a4_information_distance.csv'));
    writetable(struct2table(rows),fullfile(out,'stage7a4_samples.csv'));
    writetable(struct2table(summary),fullfile(out,'stage7a4_summary.csv'));
    writetable(struct2table(controls),fullfile(out,'stage7a4_positive_controls.csv'));
    writetable(struct2table(control_decisions),fullfile(out,'stage7a4_control_decisions.csv'));
    writetable(struct2table(nominal_spectra),fullfile(out,'stage7a4_nominal_spectra.csv'));
    writetable(struct2table(node_loading),fullfile(out,'stage7a4_node_loading_effect.csv'));
    metadata=struct('verification_baseline_commit',cfg.verification_baseline_commit,'mode',mode, ...
        'matlab_version',version,'computer_arch',computer('arch'), ...
        'parallel_workers',0,'bank_identity',bank.identity, ...
        'asym_bank_identity',asym_bank.identity, ...
        'selected_B_termination_ohm',explore.selection.selected_B_termination_ohm, ...
        'selected_C_node',explore.selection.selected_C_main_label, ...
        'main_cache_bytes',bank.logical_cache_bytes, ...
        'asym_cache_bytes',asym_bank.logical_cache_bytes, ...
        'main_cache_build_s',bank.build_time_s, ...
        'asym_cache_build_s',asym_bank.build_time_s, ...
        'sample_method_rows',numel(rows),'summary_rows',numel(summary), ...
        'control_decision_rows',numel(control_decisions), ...
        'calibration_generation_s',phase.calibration_generation_s, ...
        'main_calibration_s',phase.main_calibration_s, ...
        'asymmetry_calibration_s',phase.asymmetry_calibration_s, ...
        'test_generation_s',phase.test_generation_s,'scoring_s',phase.scoring_s, ...
        'summary_s',phase.summary_s,'evaluation_wall_s',phase.total_evaluation_s, ...
        'exploration_wall_s',explore.selection.exploration_wall_s);
    writetable(struct2table(metadata),fullfile(out,'stage7a4_metadata.csv'));
    save(fullfile(out,'stage7a4_config_snapshot.mat'),'cfg','metadata','phase', ...
        'sigma','sigma_asym','schemes');
    write_source_inventory(root,out,cfg);
    write_artifact_manifest(root,out,mode);
    fprintf('Stage 7A.4 %s completed: %d decisions, %.3f s evaluation wall-clock.\n', ...
        mode,numel(rows),phase.total_evaluation_s);
    result=struct('metadata',metadata,'summary',summary,'information',info, ...
        'controls',controls,'control_decisions',control_decisions, ...
        'selection',explore.selection,'output_dir',out);
end

function [models,rows]=calibrate_all(a,f,bank,schemes,sigma,cfg,pair,original,variant)
    n=numel(schemes);models=cell(n,2);rows=repmat(cal_row(),0,1);
    libraries={pair,original};names={'diagnostic_pair','original_three'};
    for j=1:n
        for q=1:2
            ix=libraries{q};am=ismember([a.truth_global_index],ix);
            fm=ismember([f.truth_global_index],ix);
            a_rows=a(am);f_rows=f(fm);
            truth=zeros(numel(a_rows),1);
            for k=1:numel(a_rows),truth(k)=find(ix==a_rows(k).truth_global_index,1);end
            ad=distance_matrix(a_rows,bank,ix,schemes(j).view_indices,sigma);
            fd=distance_matrix(f_rows,bank,ix,schemes(j).view_indices,sigma);
            label=[variant '_' names{q} '_' schemes(j).name];
            model=stage7a4_calibrate_decision(ad,truth,fd,bank,ix, ...
                schemes(j).view_indices,sigma,cfg,label);
            models{j,q}=model;
            row=cal_row();row.variant=variant;row.library=names{q};
            row.scheme=schemes(j).name;row.view_indices=mat2str(schemes(j).view_indices);
            row.class_counts=mat2str(model.class_counts);
            row.class_thresholds=mat2str(model.class_threshold,16);
            row.fit_count=model.fit_count;row.fit_threshold=model.fit_threshold;
            row.margin_threshold=model.margin_threshold;
            row.E_seed_base=cfg.seed_E;row.A_seed_base=cfg.seed_A;row.F_seed_base=cfg.seed_F;
            if strcmp(variant,'asymmetry')
                row.E_seed_base=cfg.seed_E_asym;row.A_seed_base=cfg.seed_A_asym;
                row.F_seed_base=cfg.seed_F_asym;
            end
            row.bank_identity=bank.identity;
            row.calibration_identity=model.calibration_identity;
            rows(end+1)=row; %#ok<AGROW>
        end
    end
end
function d=distance_matrix(samples,bank,indices,views,sigma)
    d=zeros(numel(samples),numel(indices));
    for k=1:numel(samples)
        p=stage7a4_profile_views(samples(k).observed,bank,indices,views,sigma);
        d(k,:)=p.distances;
    end
end
function r=cal_row()
    r=struct('variant','','library','','scheme','','view_indices','', ...
        'class_counts','','class_thresholds','','fit_count',0,'fit_threshold',NaN, ...
        'margin_threshold',NaN,'E_seed_base',0,'A_seed_base',0,'F_seed_base',0, ...
        'bank_identity','','calibration_identity','');
end
function r=sample_row()
    r=struct('scenario','','scheme','','stage','','library','','truth_id','', ...
        'truth_signature','','truth_in_library',false,'parameter_seed',0, ...
        'noise_seed',0,'true_main_scale',NaN,'true_branch_load_scale',NaN, ...
        'true_first_segment_scale',NaN,'termination_error_fraction',NaN, ...
        'load_drift_fraction',NaN,'node_port_error_fraction',NaN, ...
        'decision_state','','decision_reason','','best_candidate','', ...
        'candidate_set','','candidate_set_size',0,'truth_in_set',false, ...
        'correct_unique',false,'false_unique',false,'nonempty_set',false, ...
        'best_distance',NaN,'second_distance',NaN,'margin',NaN, ...
        'fit_threshold',NaN,'fit_accepted',false,'all_distances','', ...
        'best_template_indices','','calibration_identity','');
end
function r=make_sample_row(sample,scenario,scheme,library,z,all4,model,truth_in_library)
    r=sample_row();truth=sample.truth_global_index;
    r.scenario=scenario;r.scheme=scheme.name;r.stage=scheme.stage;r.library=library;
    r.truth_id=all4(truth).topology_id;
    r.truth_signature=stage6b_network_signature(all4(truth).network);
    r.truth_in_library=truth_in_library;
    r.parameter_seed=sample.parameter_seed;r.noise_seed=sample.noise_seed;
    r.true_main_scale=sample.theta.main_length_scale;
    r.true_branch_load_scale=sample.theta.branch_load_scale;
    r.true_first_segment_scale=sample.theta.first_segment_scale;
    mods=sample.modifiers;
    if isfield(mods,'second_termination_error_fraction')
        r.termination_error_fraction=mods.second_termination_error_fraction;
    end
    if isfield(mods,'second_branch_load_drift_fraction')
        r.load_drift_fraction=mods.second_branch_load_drift_fraction;
    end
    if isfield(mods,'node_port_error_fraction')
        r.node_port_error_fraction=mods.node_port_error_fraction;
    end
    r.decision_state=z.decision_state;r.decision_reason=z.decision_reason;
    r.best_candidate=z.best_candidate;r.candidate_set=z.candidate_set;
    r.candidate_set_size=z.candidate_set_size;
    r.truth_in_set=truth_in_library&& ...
        ismember(r.truth_id,strsplit(z.candidate_set,','));
    r.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
        truth_in_library&&strcmp(z.best_candidate,r.truth_id);
    r.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
        (~truth_in_library||~strcmp(z.best_candidate,r.truth_id));
    r.nonempty_set=z.candidate_set_size>0;
    r.best_distance=z.distance;r.second_distance=z.second_distance;
    r.margin=z.margin;r.fit_threshold=z.fit_threshold;
    r.fit_accepted=z.fit_accepted;r.all_distances=mat2str(z.all_distances,16);
    r.best_template_indices=mat2str(z.best_template_indices);
    r.calibration_identity=model.calibration_identity;
end
function rows=summarize_rows(samples,schemes,scenarios)
    rows=repmat(summary_row(),0,1);
    libraries={'diagnostic_pair','original_three'};
    truths={'ALL','G001','G002','G003','MIRROR_M3'};
    for s=1:numel(scenarios)
        for j=1:numel(schemes)
            for q=1:numel(libraries)
                for t=1:numel(truths)
                    mask=strcmp({samples.scenario},scenarios{s})& ...
                        strcmp({samples.scheme},schemes(j).name)& ...
                        strcmp({samples.library},libraries{q});
                    if t>1,mask=mask&strcmp({samples.truth_id},truths{t});end
                    z=samples(mask);if isempty(z),continue;end
                    n=numel(z);in=nnz([z.truth_in_library]);
                    covered=nnz([z.truth_in_set]);correct=nnz([z.correct_unique]);
                    false=nnz([z.false_unique]);nonempty=nnz([z.nonempty_set]);
                    unique=nnz(strcmp({z.decision_state},'UNIQUE_CONFIDENT'));
                    ambiguous=nnz(strcmp({z.decision_state},'MULTIPLE_AMBIGUOUS'));
                    low=nnz(strcmp({z.decision_state},'LOW_CONFIDENCE'));
                    reject=nnz(strcmp({z.decision_state},'REJECTED'));
                    [fl,fh]=stage7a4_wilson(false,n);
                    [cl,ch]=stage7a4_wilson(correct,n);
                    [covl,covh]=stage7a4_wilson(covered,in);
                    r=summary_row();r.scenario=scenarios{s};r.scheme=schemes(j).name;
                    r.stage=schemes(j).stage;r.library=libraries{q};r.truth_group=truths{t};
                    r.n=n;r.truth_in_library_n=in;r.truth_set_covered_k=covered;
                    r.truth_set_coverage=safe_ratio(covered,in);
                    r.coverage_low95=covl;r.coverage_high95=covh;
                    r.mean_set_size=mean([z.candidate_set_size]);
                    r.correct_unique_k=correct;r.correct_unique_rate=correct/n;
                    r.correct_unique_low95=cl;r.correct_unique_high95=ch;
                    r.false_unique_k=false;r.false_unique_rate=false/n;
                    r.false_unique_low95=fl;r.false_unique_high95=fh;
                    r.unique_k=unique;r.ambiguous_k=ambiguous;
                    r.low_confidence_k=low;r.rejected_k=reject;
                    r.nonempty_set_k=nonempty;r.nonempty_set_rate=nonempty/n;
                    r.measurement_count=schemes(j).measurement_count;
                    r.receiver_port_count=schemes(j).receiver_port_count;
                    r.changes_termination=schemes(j).changes_termination;
                    rows(end+1)=r; %#ok<AGROW>
                end
            end
        end
    end
end
function r=summary_row()
    r=struct('scenario','','scheme','','stage','','library','','truth_group','', ...
        'n',0,'truth_in_library_n',0,'truth_set_covered_k',0, ...
        'truth_set_coverage',NaN,'coverage_low95',NaN,'coverage_high95',NaN, ...
        'mean_set_size',NaN,'correct_unique_k',0,'correct_unique_rate',NaN, ...
        'correct_unique_low95',NaN,'correct_unique_high95',NaN, ...
        'false_unique_k',0,'false_unique_rate',NaN, ...
        'false_unique_low95',NaN,'false_unique_high95',NaN, ...
        'unique_k',0,'ambiguous_k',0,'low_confidence_k',0,'rejected_k',0, ...
        'nonempty_set_k',0,'nonempty_set_rate',NaN, ...
        'measurement_count',0,'receiver_port_count',0,'changes_termination',false);
end
function out=information_rows(bank,asym_bank,schemes,sigma,sigma_asym,pair)
    out=repmat(struct('variant','','scheme','','stage','','view_indices','', ...
        'fixed_joint_distance',NaN,'min_profile_joint_distance',NaN, ...
        'fixed_abs_rms_per_view','','fixed_relative_rms_per_view','', ...
        'profiled_abs_rms_per_view','','best_params_G003','', ...
        'best_params_mirror','','numerically_identical_at_nominal',false),0,1);
    for variant=1:2
        b=bank;scale=sigma;name='main';
        if variant==2,b=asym_bank;scale=sigma_asym;name='asymmetry';end
        for j=1:numel(schemes)
            info=stage7a4_information_distance(b,pair,schemes(j).view_indices,scale);
            r=out_template();r.variant=name;r.scheme=schemes(j).name;
            r.stage=schemes(j).stage;r.view_indices=mat2str(schemes(j).view_indices);
            r.fixed_joint_distance=info.fixed_joint_distance;
            r.min_profile_joint_distance=info.min_joint_distance;
            r.fixed_abs_rms_per_view=mat2str(info.fixed_abs_rms_per_view,16);
            r.fixed_relative_rms_per_view=mat2str(info.fixed_relative_rms_per_view,16);
            r.profiled_abs_rms_per_view=mat2str(info.profiled_abs_rms_per_view,16);
            r.best_params_G003=mat2str(info.best_params_a,16);
            r.best_params_mirror=mat2str(info.best_params_b,16);
            r.numerically_identical_at_nominal=info.numerically_identical_at_nominal;
            out(end+1)=r; %#ok<AGROW>
        end
    end
end
function r=out_template()
    r=struct('variant','','scheme','','stage','','view_indices','', ...
        'fixed_joint_distance',NaN,'min_profile_joint_distance',NaN, ...
        'fixed_abs_rms_per_view','','fixed_relative_rms_per_view','', ...
        'profiled_abs_rms_per_view','','best_params_G003','', ...
        'best_params_mirror','','numerically_identical_at_nominal',false);
end
function [rows,cb,c]=control_rows(base,cfg,schemes,sigma)
    old=topology_candidates(base);ids={'T3','T5','T4'};
    ix=zeros(1,3);for k=1:3,ix(k)=find(strcmp({old.id},ids{k}),1);end
    c=repmat(struct('topology_id','','network',struct()),1,3);
    for k=1:3,c(k).topology_id=ids{k};c(k).network=old(ix(k)).network;end
    c(3).topology_id='T4_NEAR_T3';
    c(3).network.branches(1).length=1e-6;
    c(3).network.branches(1).load=1e12;
    cb=stage7a4_template_bank(c,base,cfg);
    selected=ismember({schemes.name},{'A0_H50','A0_Zin50','A0_H50_Zin50', ...
        'B_H50_repeat','B_H50_Hsecond','C_Hendpoint_Hnode'});
    rows=repmat(struct('scheme','','control_pair','','min_profile_distance',NaN, ...
        'nominal_fixed_distance',NaN,'still_overlap_below_three_sigma',false, ...
        'stage6b_legacy_state','','decision_rule_note',''),0,1);
    for j=find(selected)
        pairs=[1 2;1 3;2 3];names={'T3_T5','T3_T4close','T5_T4close'};
        for p=1:3
            info=stage7a4_information_distance(cb,pairs(p,:),schemes(j).view_indices,sigma);
            r=struct('scheme',schemes(j).name,'control_pair',names{p}, ...
                'min_profile_distance',info.min_joint_distance, ...
                'nominal_fixed_distance',info.fixed_joint_distance, ...
                'still_overlap_below_three_sigma', ...
                info.min_joint_distance<cfg.separation_threshold, ...
                'stage6b_legacy_state','MULTIPLE_AMBIGUOUS', ...
                'decision_rule_note','margin_below_three_cannot_be_unique_when_fit_and_set_hold');
            rows(end+1)=r; %#ok<AGROW>
        end
    end
end
function rows=control_decision_rows(bank,candidates,base,cfg,schemes,sigma)
    selected=ismember({schemes.name},{'A0_H50','A0_Zin50','A0_H50_Zin50', ...
        'B_H50_repeat','B_H50_Hsecond','C_Hendpoint_Hnode'});
    [a,~]=stage7a4_generate_split(candidates,1:3,base,cfg,cfg.seed_control_A, ...
        cfg.n_A_per_topology,cfg.cfr_snr_db,'standard');
    [f,~]=stage7a4_generate_split(candidates,1:3,base,cfg,cfg.seed_control_F, ...
        cfg.n_F_per_topology,cfg.cfr_snr_db,'standard');
    [t,~]=stage7a4_generate_split(candidates,1:3,base,cfg,cfg.seed_control_T, ...
        cfg.n_T_per_topology,cfg.cfr_snr_db,'standard');
    rows=repmat(struct('scheme','','truth_id','','n',0,'truth_set_covered_k',0, ...
        'mean_set_size',NaN,'correct_unique_k',0,'false_unique_k',0, ...
        'ambiguous_k',0,'low_confidence_k',0,'rejected_k',0, ...
        'calibration_identity',''),0,1);
    ix=1:3;
    for j=find(selected)
        views=schemes(j).view_indices;
        ad=distance_matrix(a,bank,ix,views,sigma);
        fd=distance_matrix(f,bank,ix,views,sigma);
        truth=[a.truth_global_index].';
        model=stage7a4_calibrate_decision(ad,truth,fd,bank,ix,views,sigma,cfg, ...
            ['control_' schemes(j).name]);
        for k=1:3
            decisions=cell(1,cfg.n_T_per_topology);
            subset=t([t.truth_global_index]==k);
            for r=1:numel(subset)
                decisions{r}=stage7a4_decide(subset(r).observed,bank,model);
            end
            state=cellfun(@(x)x.decision_state,decisions,'UniformOutput',false);
            covered=cellfun(@(x)ismember(candidates(k).topology_id, ...
                strsplit(x.candidate_set,',')),decisions);
            right=cellfun(@(x)strcmp(x.decision_state,'UNIQUE_CONFIDENT')&& ...
                strcmp(x.best_candidate,candidates(k).topology_id),decisions);
            wrong=cellfun(@(x)strcmp(x.decision_state,'UNIQUE_CONFIDENT')&& ...
                ~strcmp(x.best_candidate,candidates(k).topology_id),decisions);
            rows(end+1)=struct('scheme',schemes(j).name, ...
                'truth_id',candidates(k).topology_id,'n',numel(subset), ...
                'truth_set_covered_k',nnz(covered), ...
                'mean_set_size',mean(cellfun(@(x)x.candidate_set_size,decisions)), ...
                'correct_unique_k',nnz(right),'false_unique_k',nnz(wrong), ...
                'ambiguous_k',nnz(strcmp(state,'MULTIPLE_AMBIGUOUS')), ...
                'low_confidence_k',nnz(strcmp(state,'LOW_CONFIDENCE')), ...
                'rejected_k',nnz(strcmp(state,'REJECTED')), ...
                'calibration_identity',model.calibration_identity); %#ok<AGROW>
        end
    end
end
function [spectra,load_effect]=nominal_response_rows(bank,cfg,topology_indices)
    p=find(all(abs(bank.params-[1 1 1])<1e-12,2),1);
    spectra=repmat(struct('topology_id','','view_name','','frequency_hz',0, ...
        'response_real',0,'response_imag',0,'unit',''),0,1);
    load_effect=repmat(struct('topology_id','','node_index',0, ...
        'internal_input_ohm',NaN,'baseline_endpoint_rms',NaN, ...
        'loaded_endpoint_change_rms',NaN,'loaded_endpoint_relative_change',NaN),0,1);
    for k=topology_indices
        for v=1:numel(cfg.view_names)-1
            h=bank.templates{k,v}(p,:);
            unit='normalized_complex_CFR';
            if startsWith(cfg.view_names{v},'Zin'),unit='ohm';end
            for f=1:numel(cfg.frequency_hz)
                spectra(end+1)=struct('topology_id',bank.candidate_ids{k}, ...
                    'view_name',cfg.view_names{v},'frequency_hz',cfg.frequency_hz(f), ...
                    'response_real',real(h(f)),'response_imag',imag(h(f)), ...
                    'unit',unit); %#ok<AGROW>
            end
        end
        h0=bank.templates{k,5}(p,:);
        for j=1:numel(cfg.node_indices)
            ix=2*numel(cfg.termination_ohm)+2*j-1;
            loaded=bank.templates{k,ix}(p,:);
            rms0=sqrt(mean(abs(h0).^2));change=sqrt(mean(abs(loaded-h0).^2));
            load_effect(end+1)=struct('topology_id',bank.candidate_ids{k}, ...
                'node_index',cfg.node_indices(j), ...
                'internal_input_ohm',cfg.states(numel(cfg.termination_ohm)+j).node_load_ohm, ...
                'baseline_endpoint_rms',rms0,'loaded_endpoint_change_rms',change, ...
                'loaded_endpoint_relative_change',change/max(rms0,eps)); %#ok<AGROW>
        end
    end
end
function write_source_inventory(root,out,cfg)
    paths={'config/stage7a4_mirror_observation_config.m', ...
        'docs/stage7a4_mirror_observation_protocol.md', ...
        'src/stage7a4_fixed_topologies.m','src/stage7a4_forward_state.m', ...
        'src/stage7a4_template_bank.m','src/stage7a4_measure_views.m', ...
        'src/stage7a4_generate_split.m','src/stage7a4_calibrate_view_scales.m', ...
        'src/stage7a4_profile_views.m','src/stage7a4_information_distance.m', ...
        'src/stage7a4_calibrate_decision.m','src/stage7a4_decide.m', ...
        'src/stage7a4_scheme_catalog.m','src/stage7a4_wilson.m', ...
        'experiments/exp_stage7a4_exploration.m', ...
        'experiments/exp_stage7a4_evaluation.m', ...
        'run_stage7a4_mirror_observation.m', ...
        'tests/test_stage7a4_forward_state.m','tests/test_stage7a4_joint_profile.m', ...
        'tests/test_stage7a4_result_integrity.m'};
    records=repmat(struct('relative_path','','sha256','','size_bytes',0, ...
        'verification_baseline_commit',''),numel(paths),1);
    for i=1:numel(paths)
        path=fullfile(root,strrep(paths{i},'/',filesep));d=dir(path);
        assert(numel(d)==1,'stage7a4:SourceMissing','Missing source %s',paths{i});
        records(i)=struct('relative_path',paths{i}, ...
            'sha256',stage4a7_2_r2_sha256_file(path),'size_bytes',d.bytes, ...
            'verification_baseline_commit',cfg.verification_baseline_commit);
    end
    writetable(struct2table(records),fullfile(out,'stage7a4_source_inventory.csv'));
end
function write_artifact_manifest(root,out,mode)
    files=dir(out);records=repmat(struct('relative_path','','sha256','', ...
        'size_bytes',0,'artifact_type',''),0,1);
    for i=1:numel(files)
        if files(i).isdir||strcmp(files(i).name,'stage7a4_artifact_manifest.csv')
            continue;
        end
        [~,~,ext]=fileparts(files(i).name);
        if ~ismember(ext,{'.csv','.mat'}),continue;end
        path=fullfile(out,files(i).name);
        records(end+1)=struct('relative_path', ...
            strrep(fullfile('results','data','stage7a_4',mode,files(i).name),filesep,'/'), ...
            'sha256',stage4a7_2_r2_sha256_file(path), ...
            'size_bytes',files(i).bytes,'artifact_type',ext(2:end)); %#ok<AGROW>
    end
    writetable(struct2table(records),fullfile(out,'stage7a4_artifact_manifest.csv'));
end
function x=safe_ratio(a,b),if b==0,x=NaN;else,x=a/b;end,end
