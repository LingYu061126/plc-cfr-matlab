function summary = exp_stage4a7_2_r2_candidate_coverage_validity(root_dir,mode)
%EXP_STAGE4A7_2_R2_CANDIDATE_COVERAGE_VALIDITY R.2 controlled experiment.
%   The experiment evaluates all forward-compatible candidates before any
%   optional Top-K truncation.  Truth is used only to label offline scores.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));
    base=default_config(root_dir);sc=stage4a7_2_r2_candidate_coverage_config(base,mode);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);t0=tic;
    source_hash=stage4a7_2_r2_source_hash(root_dir);
    [reference,read_audit]=read_stage4a7_2_r1_public_subnetwork(sc.derived_subnetwork); %#ok<NASGU>
    [ledger,spec,reference,prior_audit]=build_stage4a7_2_r1_uncertain_engineering_prior(reference, ...
        stage4a7_2_r1_data_driven_config(base,'pilot'));
    spec.maximum_candidate_count=sc.maximum_candidate_count;
    [engineering,eng_audit]=generate_engineering_topology_candidates(spec);
    ref_key=reference_key(reference); compatible=false(1,numel(engineering)); reports=cell(1,numel(engineering)); updated=cell(1,numel(engineering));
    for k=1:numel(engineering)
        [updated{k},reports{k}]=check_forward_model_compatibility(engineering(k),base);
        compatible(k)=logical(updated{k}.forward_model_compatible);
    end
    updated=normalize_candidate_cells(updated);engineering=[updated{:}];
    scored=engineering(compatible); scored=sort_candidates(scored);
    for k=1:numel(scored),scored(k).topology_id=sprintf('R2C_%03d',k);scored(k).id=scored(k).topology_id;end
    ref_rank=find(strcmp({scored.canonical_graph_key},ref_key),1);
    theta_grid=topology_parameter_grid(sc.parameter_search);
    topk_rows=stage4a7_2_r2_exact_topk_audit(spec,sc.top_k_values);
    cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,scored,theta_grid,base,sc.measurement_kind);
    cache.template_count_per_candidate=numel(theta_grid);cache.total_template_count=numel(theta_grid)*numel(scored);
    cache.cache_hash=stage4a4_scientific_config_hash(struct('ids',{cache.candidate_ids}, ...
        'theta_grid',theta_grid,'frequency_hz',sc.frequency_hz));
    [dev,devD]=materialize_score('development',sc.scenario_design.development_per_candidate, ...
        sc.seeds.development,scored,cache,base,sc);
    truth_ids={dev.truth_topology_id};
    [selected,selection_rows,selection_manifest]=stage4a7_2_r2_method_selection(devD,truth_ids, ...
        cache.candidate_ids,sc,source_hash);
    [cal,calD]=materialize_score('calibration',sc.scenario_design.calibration_per_candidate, ...
        sc.seeds.calibration,scored,cache,base,sc);
    cal_idx=truth_indices(cal,cache.candidate_ids);
    cal_model=stage4a7_2_r1_calibrate_profile_method(calD,cal_idx,cache.candidate_ids, ...
        selected,sc.alpha,struct('minimum_per_candidate',sc.scenario_design.calibration_per_candidate, ...
        'compatibility_hash',source_hash,'resolution',max(128*eps,sc.profile.resolution_floor)));
    cal_model.p_min=1/(sc.scenario_design.calibration_per_candidate+1);
    if cal_model.p_min>sc.alpha,warning('stage4a7_2_r2:InsufficientPResolution', ...
        'p_min=%.6g exceeds alpha=%.6g.',cal_model.p_min,sc.alpha);end
    [pilot,pilotD]=materialize_score('pilot',sc.scenario_design.pilot_per_candidate, ...
        sc.seeds.pilot,scored,cache,base,sc);
    [pilot_decisions,pilot_metrics]=apply_and_measure(pilot,pilotD,cal_model,selected,sc,source_hash);
    eq=stage4a7_2_r2_scenario_equivalence(scored,theta_grid,sc.frequency_hz,base, ...
        sc.measurement_kind,sc.scenario_design.scenario_equivalence_count,sc.profile.equivalence_tolerance);
    ext=stage4a7_2_r2_external_manifest(root_dir,sc.derived_subnetwork);
    coverage=coverage_rows(engineering,scored,ref_key,ref_rank,source_hash,topk_rows);
    write_rows(fullfile(sc.results_data,'external_data_manifest.csv'),ext);
    write_rows(fullfile(sc.results_data,'candidate_coverage_audit.csv'),coverage);
    write_rows(fullfile(sc.results_data,'topk_exactness.csv'),topk_rows);
    write_rows(fullfile(sc.results_data,'topk_sensitivity.csv'),topk_rows);
    write_rows(fullfile(sc.results_data,'development_method_selection.csv'),selection_rows);
    write_rows(fullfile(sc.results_data,'frozen_method_manifest.csv'),selection_manifest_row(selection_manifest));
    write_rows(fullfile(sc.results_data,'calibration_resolution.csv'),calibration_rows(cal_model,sc));
    write_rows(fullfile(sc.results_data,'pilot_metrics.csv'),pilot_metrics);
    write_rows(fullfile(sc.results_data,'scenario_equivalence_audit.csv'),equivalence_summary(eq,sc,source_hash));
    write_rows(fullfile(sc.results_data,'nonunique_scenarios.csv'),equivalence_summary(eq,sc,source_hash));
    write_rows(fullfile(sc.results_data,'near_symmetry_boundary.csv'),near_symmetry_summary(eq,sc,source_hash));
    write_rows(fullfile(sc.results_data,'profile_cache_audit.csv'),cache_audit(cache,sc,source_hash));
    write_rows(fullfile(sc.results_data,'runtime_summary.csv'),runtime_row(mode,sc, ...
        numel(engineering),nnz(compatible),numel(scored),numel(dev),numel(cal),numel(pilot), ...
        cache,source_hash,toc(t0)));
    write_rows(fullfile(sc.results_data,'pilot_decisions.csv'),pilot_decisions);
    summary=struct('stage_name',sc.stage_name,'mode',mode,'engineering_candidate_count',numel(engineering), ...
        'forward_compatible_candidate_count',nnz(compatible),'scored_candidate_count',numel(scored), ...
        'reference_rank_by_prior',ref_rank,'truth_in_engineering_space',any(strcmp({engineering.canonical_graph_key},ref_key)), ...
        'truth_forward_model_compatible',any(strcmp({scored.canonical_graph_key},ref_key)), ...
        'truth_in_scored_library',any(strcmp({scored.canonical_graph_key},ref_key)), ...
        'calibration_per_candidate',sc.scenario_design.calibration_per_candidate,'calibration_p_min',cal_model.p_min, ...
        'alpha',sc.alpha,'selected_for_execution',selected,'scientifically_unique_winner', ...
        selection_manifest.scientifically_unique_winner,'scenario_equivalent_pair_count',numel(eq.rows), ...
        'pilot_count',numel(pilot),'status','controlled_audit_completed','source_tree_hash',source_hash, ...
        'stage4b_started',false,'final_status','not_run');
    save(fullfile(sc.results_data,'stage4a7_2_r2_results.mat'),'summary','sc','reference','ledger','spec', ...
        'engineering','scored','theta_grid','cache','dev','cal','pilot','cal_model','selection_rows', ...
        'selection_manifest','pilot_decisions','pilot_metrics','eq','topk_rows','coverage','-v7.3');
    save(fullfile(sc.results_data,'stage4a7_2_r2_summary.mat'),'summary');write_rows(fullfile(sc.results_data,'summary.csv'),summary);
    fprintf('Stage 4A.7.2-R.2 %s completed: engineering=%d compatible=%d scored=%d cal=%d pilot=%d ref_rank=%d in %.3f s.\n', ...
        mode,numel(engineering),nnz(compatible),numel(scored),numel(cal),numel(pilot),ref_rank,toc(t0));
end

function [rows,D]=materialize_score(split,nper,seed,candidates,cache,base,sc)
    rows=repmat(scenario_row(),0,1);D=zeros(0,numel(candidates));stream=RandStream('mt19937ar','Seed',seed);
    for k=1:numel(candidates)
        for q=1:nper
            ix=1+floor(rand(stream)*numel(cache.theta_grid));theta=cache.theta_grid(ix);
            [net,local]=topology_apply_parameters(candidates(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);
            o=stage4a7_2_r1_profile_distance({v{1}},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));
            r=scenario_row();r.sample_id=sprintf('r2_%s_%03d_%03d',split,k,q);r.physical_scenario_id=r.sample_id;r.split=split;r.truth_topology_id=candidates(k).topology_id;r.truth_set=candidates(k).topology_id;r.truth_theta=theta;r.parameter_vector_hash=stage4a4_scientific_config_hash(theta);r.noiseless_cfr_hash=stage4a4_scientific_config_hash(v{1});r.observation_hash=r.noiseless_cfr_hash;r.case_seed=seed+1009*k+q;r.profile_runtime_s=o.runtime_s;rows(end+1)=r;D(end+1,:)=o.profile_distances; %#ok<AGROW>
        end
    end
end
function [decisions,metrics]=apply_and_measure(rows,D,model,method,sc,h)
    decisions=repmat(decision_row(),numel(rows),1);hits=false(numel(rows),1);sizes=zeros(numel(rows),1);empty=false(numel(rows),1);single=false(numel(rows),1);
    for k=1:numel(rows)
        o=stage4a7_2_r1_apply_profile_candidate_set(D(k,:),model,method);a=o.accepted_candidate_set;decisions(k).sample_id=rows(k).sample_id;decisions(k).accepted_set=strjoin(a,',');decisions(k).set_size=numel(a);decisions(k).hit=any(strcmp(a,rows(k).truth_set));decisions(k).empty=isempty(a);decisions(k).singleton=numel(a)==1;decisions(k).method_id=method;decisions(k).calibration_hash=o.calibration_hash;hits(k)=decisions(k).hit;sizes(k)=decisions(k).set_size;empty(k)=decisions(k).empty;single(k)=decisions(k).singleton;
    end
    metrics=repmat(metric_row(),1,7);names={'truth_set_coverage','mean_set_size','median_set_size','singleton_rate','empty_set_rate','selective_risk','false_unique_rate'};vals={mean(hits),mean(sizes),median(sizes),mean(single),mean(empty),ratio(nnz(~hits&~empty),nnz(~empty)),NaN};
    for k=1:numel(metrics),metrics(k).metric_id=names{k};metrics(k).value=vals{k};metrics(k).numerator=NaN;metrics(k).denominator=numel(rows);metrics(k).scientific_hash=h;metrics(k).method_id=method;end
    metrics(1).numerator=nnz(hits);metrics(1).denominator=numel(hits);metrics(2).numerator=sum(sizes);metrics(2).denominator=numel(sizes);metrics(3).numerator=NaN;metrics(4).numerator=nnz(single);metrics(4).denominator=numel(single);metrics(5).numerator=nnz(empty);metrics(5).denominator=numel(empty);metrics(6).numerator=nnz(~hits&~empty);metrics(6).denominator=nnz(~empty);metrics(7).numerator=0;metrics(7).denominator=0;metrics(7).value=NaN;
    for k=[1 4 5 6], [metrics(k).ci_low,metrics(k).ci_high]=stage4a7_2_wilson_interval(metrics(k).numerator,metrics(k).denominator);end
    metrics(2).ci_low=NaN;metrics(2).ci_high=NaN;metrics(3).ci_low=NaN;metrics(3).ci_high=NaN;
end
function rows=coverage_rows(engineering,scored,key,rank,h,topk)
    rows=repmat(struct('engineering_candidate_count',numel(engineering),'compatible_candidate_count',numel(scored),'scored_candidate_count',numel(scored),'reference_rank_by_prior',rank,'truth_in_engineering_space',any(strcmp({engineering.canonical_graph_key},key)),'truth_forward_model_compatible',any(strcmp({scored.canonical_graph_key},key)),'truth_in_scored_library',any(strcmp({scored.canonical_graph_key},key)),'topk_coverage_loss',false,'top_k',0,'candidate_keys','','prior_costs','','scientific_hash',h),1,numel(topk));for k=1:numel(topk),rows(k).top_k=topk(k).top_k;rows(k).scored_candidate_count=topk(k).returned_count;rows(k).truth_in_scored_library=contains([';' topk(k).candidate_keys ';'],[';' key ';']);rows(k).topk_coverage_loss=~rows(k).truth_in_scored_library;rows(k).candidate_keys=topk(k).candidate_keys;rows(k).prior_costs=topk(k).candidate_costs;end
end
function rows=calibration_rows(model,sc),rows=repmat(struct('candidate_id','','sample_count',0,'minimum_attainable_p',NaN,'status','','alpha',sc.alpha,'calibration_resolution_status',''),1,numel(model.classes));for k=1:numel(rows),rows(k).candidate_id=model.classes(k).candidate_id;rows(k).sample_count=model.classes(k).sample_count;rows(k).minimum_attainable_p=model.classes(k).minimum_attainable_p;rows(k).status=model.classes(k).status;rows(k).calibration_resolution_status=ternary(model.classes(k).minimum_attainable_p<=sc.alpha,'meets_alpha_resolution','insufficient_alpha_resolution');end,end
function rows=cache_audit(cache,sc,h),rows=struct('theta_grid_count',numel(cache.theta_grid),'templates_per_candidate',cache.template_count_per_candidate,'candidate_count',numel(cache.candidate_ids),'total_template_count',cache.total_template_count,'cache_hash',cache.cache_hash,'feature',sc.feature,'scientific_hash',h,'cache_contains_truth',cache.cache_contains_truth);end
function r=selection_manifest_row(m)
    hp=m.selected_hyperparameters;
    r=struct('selected_method',m.selected_method,'selected_for_execution',m.selected_for_execution, ...
        'scientifically_unique_winner',m.scientifically_unique_winner,'tied_methods',m.tied_methods, ...
        'selection_rule',m.selection_rule,'set_k',hp.set_k,'alpha',hp.alpha, ...
        'tie_tolerance',hp.tie_tolerance,'compatibility_hash',m.compatibility_hash, ...
        'frozen_method_hash',m.frozen_method_hash,'status',m.status);
end
function r=equivalence_summary(eq,sc,h),r=struct('status',eq.status,'requested_count',eq.requested_count,'unique_count',eq.unique_count,'duplicate_count',eq.duplicate_count,'equivalent_pair_count',numel(eq.rows),'candidate_count',eq.candidate_count,'equivalence_tolerance',eq.tolerance,'definition',eq.definition,'scientific_hash',h,'final_reserved_status',sc.final_reserved.status);end
function r=near_symmetry_summary(eq,sc,h),r=struct('status',ternary(strcmp(eq.status,'completed'),'candidate_pair_available','no_scenario_equivalent_pair_found'),'candidate_pair_count',numel(eq.rows),'perturbation_levels_tested',numel(sc.scenario_design.near_symmetry_levels),'resolution_status','not_evaluable_without_observation-equivalent_pair','scientific_hash',h);end
function r=runtime_row(mode,sc,ne,nc,ns,nd,ncal,np,cache,h,rt),r=struct('mode',mode,'engineering_candidate_count',ne,'forward_compatible_candidate_count',nc,'scored_candidate_count',ns,'development_count',nd,'calibration_count',ncal,'pilot_count',np,'theta_grid_count',numel(cache.theta_grid),'templates_per_candidate',cache.template_count_per_candidate,'total_template_count',cache.total_template_count,'profile_cache_runtime_s',cache.build_runtime_s,'total_runtime_s',rt,'use_parallel',sc.use_parallel,'num_workers',sc.num_workers,'scientific_hash',h,'final_reserved_status',sc.final_reserved.status);end
function key=reference_key(ref),x=canonicalize_asset_graph(ref.node_ids,ref.edges,struct());key=x.canonical_graph_key;end
function ix=truth_indices(rows,ids),ix=zeros(numel(rows),1);for k=1:numel(rows),ix(k)=find(strcmp(ids,rows(k).truth_topology_id),1);end,end
function c=sort_candidates(c),if isempty(c),return;end;cost=[c.prior_cost].';keys={c.canonical_graph_key};[~,ord]=sortrows([cost,(1:numel(c)).']);out=repmat(c(1),1,0);for i=1:numel(ord),j=ord(i);if i>1&&cost(j)==cost(ord(i-1)),tie=ord(i-1:i);[~,z]=sort(keys(tie));if z(1)==2,j=ord(i-1);end,end;out(end+1)=c(j);end;c=out;end
function r=scenario_row(),r=struct('sample_id','','physical_scenario_id','','split','','truth_topology_id','','truth_set','','truth_theta',struct(),'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','case_seed',0,'profile_runtime_s',NaN);end
function r=decision_row(),r=struct('sample_id','','accepted_set','','set_size',0,'hit',false,'singleton',false,'empty',false,'method_id','','calibration_hash','');end
function r=metric_row(),r=struct('metric_id','','value',NaN,'numerator',NaN,'denominator',NaN,'ci_low',NaN,'ci_high',NaN,'method_id','','scientific_hash','');end
function r=ratio(a,b),if b==0,r=NaN;else,r=a/b;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function cells=normalize_candidate_cells(cells)
    if isempty(cells),return;end
    names={};for k=1:numel(cells),names=[names;fieldnames(cells{k})];end %#ok<AGROW>
    names=unique(names,'stable');
    for k=1:numel(cells)
        f=fieldnames(cells{k});
        for j=1:numel(names)
            if ~any(strcmp(f,names{j})),cells{k}.(names{j})=[];end
        end
    end
end
function write_rows(path,rows),if isempty(rows),fid=fopen(path,'w');fprintf(fid,'empty\n');fclose(fid);elseif istable(rows),writetable(rows,path);else,writetable(struct2table(rows),path);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
