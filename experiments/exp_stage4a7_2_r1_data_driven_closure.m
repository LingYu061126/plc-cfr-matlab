function summary=exp_stage4a7_2_r1_data_driven_closure(root_dir,mode)
%EXP_STAGE4A7_2_R1_DATA_DRIVEN_CLOSURE Shared-prior controlled pilot.
%   Truth is used only while materialising offline scenarios and scoring the
%   outputs. Candidate generation, adaptation, profile matching and method
%   application receive no truth labels.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));
    base=default_config(root_dir);sc=stage4a7_2_r1_data_driven_config(base,mode);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);
    t0=tic;source_hash=stage4a7_2_r1_source_tree_hash(root_dir);
    scientific_hash=stage4a4_scientific_config_hash(struct('stage',sc.stage_name, ...
        'version',sc.version,'grid',sc.frequency_hz,'prior_source',sc.prior_source, ...
        'top_k',sc.top_k,'parameter_search',sc.parameter_search, ...
        'method_selection',sc.method_selection,'source_tree_hash',source_hash));
    [reference,read_audit]=read_stage4a7_2_r1_public_subnetwork(sc.derived_subnetwork);
    [ledger,spec,reference,audit]=build_stage4a7_2_r1_uncertain_engineering_prior(reference,sc);
    [engineering,gen_audit]=generate_engineering_topology_candidates(spec);
    fprintf('R1 progress: engineering candidates=%d.\n',numel(engineering));
    engineering=label_candidates(engineering,'ENWL13E');
    [engineering,adapter_rows]=adapt_all(engineering,base,scientific_hash);
    topk_timer=tic;[topk,topk_audit]=generate_topk_topology_candidates(spec,sc.top_k);topk_runtime=toc(topk_timer);
    topk=label_candidates(topk,'ENWL13K');[topk,topk_adapter_rows]=adapt_all(topk,base,scientific_hash);
    scored=topk(arrayfun(@(x)getb(x,'scored_library_included',false),topk));
    fprintf('R1 progress: topk=%d scored=%d.\n',numel(topk),numel(scored));
    ref_candidate=reference_candidate_id(reference,engineering);
    ref_key=reference_graph_key(reference);
    coverage=stage4a7_2_r1_build_coverage_audit(engineering,arrayfun(@candidate_id,scored,'UniformOutput',false),ref_candidate,scientific_hash,ref_key);
    theta_grid=topology_parameter_grid(sc.parameter_search);
    if isempty(scored),error('stage4a7_2_r1:NoScoredCandidates','No compatible Top-K candidate is available.');end
    profile_cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,scored,theta_grid,base,sc.measurement_kind);
    fprintf('R1 progress: profile cache ready in %.3f s.\n',profile_cache.build_runtime_s);
    [dev,devD]=materialize_and_score('development',sc.scenario_design.development_per_candidate,sc.seeds.development,scored,profile_cache,base,sc);
    sc.profile.resolution_floor=128*eps(max(1,max(abs(devD(:)))));
    dev_truth_sets=cell(numel(dev),1);for k=1:numel(dev),dev_truth_sets{k}=dev(k).truth_set;end
    [selected,selection_rows,selection_manifest]=stage4a7_2_r1_method_selection(devD,dev_truth_sets,profile_cache.candidate_ids,sc,scientific_hash);
    [cal,calD]=materialize_and_score('calibration',sc.scenario_design.calibration_per_candidate,sc.seeds.calibration,scored,profile_cache,base,sc);
    fprintf('R1 progress: development=%d calibration=%d.\n',numel(dev),numel(cal));
    cal_idx=truth_indices(cal,profile_cache.candidate_ids);
    if strcmp(selected,'no_method_meets_gate')
        cal_model=struct('status','no_method_meets_gate','method_id',selected,'calibration_hash','');
        pilot=[];pilotD=[];pilot_decisions=[];
    else
        cal_model=stage4a7_2_r1_calibrate_profile_method(calD,cal_idx,profile_cache.candidate_ids,selected,sc.alpha,struct('minimum_per_candidate',max(1,sc.scenario_design.calibration_per_candidate),'compatibility_hash',scientific_hash,'resolution',sc.profile.resolution_floor));
        [pilot,pilotD]=materialize_and_score('pilot',sc.scenario_design.pilot_per_candidate,sc.seeds.pilot,scored,profile_cache,base,sc);
        pilot_decisions=apply_rows(pilot,pilotD,cal_model,selected);
        fprintf('R1 progress: pilot=%d decisions=%d.\n',numel(pilot),numel(pilot_decisions));
    end
    nonunique=struct('status','not_run','rows',[],'metrics',[],'calibration_status','not_run');near=[];
    if sc.scenario_design.nonunique_count>0
        [nonunique,near]=legacy_nonunique_audit(sc,base,theta_grid,source_hash,scientific_hash);
        fprintf('R1 progress: nonunique=%d near=%d.\n',numel(nonunique.rows),numel(near));
    end
    topk_scaling=stage4a7_2_r1_topk_scaling_audit(sc);
    write_rows(fullfile(sc.results_data,'external_data_manifest.csv'),struct('source_dataset','ENWL_LVNS_processed_OpenDSS','network_id',sc.source_network_id,'feeder_id',sc.source_feeder_id,'derived_subnetwork',sc.derived_subnetwork,'scientific_hash',scientific_hash));
    write_rows(fullfile(sc.results_data,'selected_public_subnetwork.csv'),reference.source_table);
    write_rows(fullfile(sc.results_data,'uncertain_engineering_ledger.csv'),ledger);
    write_rows(fullfile(sc.results_data,'uncertainty_generation_audit.csv'),audit);
    write_rows(fullfile(sc.results_data,'generated_candidates.csv'),candidate_rows(engineering,topk,scientific_hash));
    write_rows(fullfile(sc.results_data,'candidate_coverage_audit.csv'),coverage);
    write_rows(fullfile(sc.results_data,'adapter_roundtrip_audit.csv'),[adapter_rows(:);topk_adapter_rows(:)]);
    write_rows(fullfile(sc.results_data,'topk_scaling_audit.csv'),topk_scaling);
    profile_rows=distance_rows_all({dev,cal,pilot},profile_cache,scientific_hash);
    write_rows(fullfile(sc.results_data,'profile_distance_audit.csv'),profile_rows);
    write_rows(fullfile(sc.results_data,'development_method_selection.csv'),selection_rows);
    selection_manifest_csv=struct('selected_method',selection_manifest.selected_method, ...
        'selection_rule',selection_manifest.selection_rule, ...
        'alpha',selection_manifest.selected_hyperparameters.alpha, ...
        'top_k',selection_manifest.selected_hyperparameters.top_k, ...
        'compatibility_hash',selection_manifest.compatibility_hash, ...
        'frozen_method_hash',selection_manifest.frozen_method_hash, ...
        'status',selection_manifest.status);
    write_rows(fullfile(sc.results_data,'frozen_method_manifest.csv'),selection_manifest_csv);
    write_rows(fullfile(sc.results_data,'pilot_confirmation_metrics.csv'),pilot_metrics(pilot,pilot_decisions,scientific_hash));
    write_rows(fullfile(sc.results_data,'nonunique_confirmation_metrics.csv'),nonunique.metrics);
    write_rows(fullfile(sc.results_data,'nonunique_decisions.csv'),nonunique.rows);
    write_rows(fullfile(sc.results_data,'near_symmetry_decisions.csv'),near);
    write_rows(fullfile(sc.results_data,'runtime_summary.csv'),struct('mode',mode,'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'engineering_candidate_count',numel(engineering),'forward_compatible_candidate_count',nnz([engineering.forward_model_compatible]),'scored_candidate_count',numel(scored),'profile_template_count',numel(theta_grid),'profile_cache_runtime_s',profile_cache.build_runtime_s,'topk_runtime_s',topk_runtime,'nonunique_count',sc.scenario_design.nonunique_count,'total_runtime_s',toc(t0),'use_parallel',sc.use_parallel,'num_workers',sc.num_workers,'scientific_hash',scientific_hash,'source_tree_hash',source_hash,'final_reserved_status',sc.final_reserved.status));
    summary=struct('stage_name',sc.stage_name,'mode',mode,'status',ternary(strcmp(selection_manifest.status,'frozen_from_development_only'),'completed_controlled_pilot','partial_no_method_meets_gate'),'engineering_candidate_count',numel(engineering),'forward_compatible_candidate_count',nnz([engineering.forward_model_compatible]),'scored_candidate_count',numel(scored),'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'selected_method',selected,'nonunique_count',sc.scenario_design.nonunique_count,'nonunique_false_unique_denominator',get_nonunique_den(nonunique),'source_tree_hash',source_hash,'scientific_hash',scientific_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);
    save(fullfile(sc.results_data,'stage4a7_2_r1_results.mat'),'summary','sc','reference','ledger','spec','engineering','topk','scored','profile_cache','dev','cal','pilot','cal_model','selection_rows','selection_manifest','coverage','topk_scaling','nonunique','near','-v7.3');
    write_rows(fullfile(sc.results_data,'summary.csv'),summary);
    fprintf('Stage 4A.7.2-R.1 %s completed: eng=%d forward=%d scored=%d dev=%d cal=%d pilot=%d in %.3f s.\n',mode,numel(engineering),nnz([engineering.forward_model_compatible]),numel(scored),numel(dev),numel(cal),numel(pilot),toc(t0));
end

function [rows,D]=materialize_and_score(split,nper,seed,candidates,cache,base,sc)
    first=scenario_template();rows=repmat(first,0,1);D=zeros(0,numel(candidates));stream=RandStream('mt19937ar','Seed',seed);
    for k=1:numel(candidates)
        for q=1:nper
            ix=1+floor(rand(stream)*numel(cache.theta_grid));theta=cache.theta_grid(ix);[net,local]=topology_apply_parameters(candidates(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);obs={v{1}};dist=stage4a7_2_r1_profile_distance(obs,cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));r=first;r.sample_id=sprintf('r1_%s_%03d_%02d',split,k,q);r.physical_scenario_id=r.sample_id;r.split=split;r.category='in_domain';r.truth_topology_id=candidate_id(candidates(k));r.truth_set=r.truth_topology_id;r.parameter_domain_truth='in_domain';r.parameter_vector_hash=stage4a4_scientific_config_hash(theta);r.noiseless_cfr_hash=stage4a4_scientific_config_hash(v{1});r.observation_hash=r.noiseless_cfr_hash;r.case_seed=seed+1009*k+q;r.observed_views=obs;r.truth_theta=theta;rows(end+1)=r;D(end+1,:)=dist.profile_distances; %#ok<AGROW>
        end
    end
end
function decisions=apply_rows(rows,D,model,method)
    n=size(D,1);decisions=repmat(struct('sample_id','','accepted_set','','set_size',0,'hit',false,'singleton',false,'empty',false,'method_id','','calibration_hash',''),n,1);
    for k=1:n,o=stage4a7_2_r1_apply_profile_candidate_set(D(k,:),model,method);decisions(k).sample_id=rows(k).sample_id;decisions(k).accepted_set=strjoin(o.accepted_candidate_set,',');decisions(k).set_size=numel(o.accepted_candidate_set);decisions(k).hit=any(strcmp(o.accepted_candidate_set,rows(k).truth_set));decisions(k).singleton=numel(o.accepted_candidate_set)==1;decisions(k).empty=isempty(o.accepted_candidate_set);decisions(k).method_id=method;decisions(k).calibration_hash=o.calibration_hash;
    end
end
function r=pilot_metrics(rows,decisions,h)
    if isempty(rows),r=struct('metric_id','no_method_meets_gate','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'scientific_hash',h);return;end
    hit=[decisions.hit];singleton=[decisions.singleton];empty=[decisions.empty];r=repmat(struct('metric_id','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'scientific_hash',''),3,1);names={'truth_set_coverage','singleton_rate','empty_set_rate'};vals={hit,singleton,empty};for k=1:3,r(k).metric_id=names{k};r(k).numerator=nnz(vals{k});r(k).denominator=numel(vals{k});r(k).rate=r(k).numerator/r(k).denominator;[r(k).ci_low,r(k).ci_high]=stage4a7_2_wilson_interval(r(k).numerator,r(k).denominator);r(k).scientific_hash=h;end
end
function [legacy_out,near]=legacy_nonunique_audit(sc,base,theta_grid,source_hash,h)
    legacy=stage4a7_1_adapt_legacy_candidates(generate_radial_topology_candidates(stage4a1_config(base).generator));for k=1:numel(legacy),[legacy(k),~]=check_forward_model_compatibility(legacy(k),base);legacy(k).topology_id=legacy(k).graph_candidate_id;legacy(k).id=legacy(k).graph_candidate_id;end
    legacy=legacy([legacy.forward_model_compatible]);cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,legacy,theta_grid,base,sc.measurement_kind);ids=cache.candidate_ids;pair=find(strcmp(ids,'G004'),1);pair2=find(strcmp(ids,'G007'),1);if isempty(pair)||isempty(pair2),legacy_out=struct('status','not_evaluable_missing_equivalence_members','rows',[],'metrics',[],'calibration_status','not_run','source_tree_hash',source_hash,'pair_ids','');near=[];return;end;caln=max(1,min(3,sc.scenario_design.calibration_per_candidate));calD=zeros(caln*numel(legacy),numel(legacy));truth=zeros(size(calD,1),1);row=0;stream=RandStream('mt19937ar','Seed',sc.seeds.calibration+7000);
    for k=1:numel(legacy),for q=1:caln,row=row+1;theta=theta_grid(1+floor(rand(stream)*numel(theta_grid)));[net,local]=topology_apply_parameters(legacy(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);calD(row,:)=stage4a7_2_r1_profile_distance({v{1}},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm)).profile_distances;truth(row)=k;end,end
    model=stage4a7_2_r1_calibrate_profile_method(calD,truth,ids,'absolute',sc.alpha,struct('minimum_per_candidate',caln,'compatibility_hash',h,'resolution',sc.profile.resolution_floor));n=sc.scenario_design.nonunique_count;rows=repmat(struct('sample_id','','truth_set','G004,G007','truth_member_count',2,'accepted_set','','set_size',0,'false_unique',false,'hit',false,'parameter_vector_hash','','noiseless_cfr_hash',''),n,1);stream=RandStream('mt19937ar','Seed',sc.seeds.nonunique);for q=1:n;theta=theta_grid(1+floor(rand(stream)*numel(theta_grid)));[net,local]=topology_apply_parameters(legacy(pair).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);profile=stage4a7_2_r1_profile_distance({v{1}},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));decision=stage4a7_2_r1_apply_profile_candidate_set(profile.profile_distances,model,'absolute');rows(q).sample_id=sprintf('r1_nonunique_%03d',q);rows(q).accepted_set=strjoin(decision.accepted_candidate_set,',');rows(q).set_size=numel(decision.accepted_candidate_set);rows(q).false_unique=rows(q).set_size==1;rows(q).hit=any(strcmp(decision.accepted_candidate_set,'G004'))&&any(strcmp(decision.accepted_candidate_set,'G007'));rows(q).parameter_vector_hash=stage4a4_scientific_config_hash(theta);rows(q).noiseless_cfr_hash=stage4a4_scientific_config_hash(v{1});if mod(q,10)==0,fprintf('R1 progress: nonunique %d/%d.\n',q,n);end;end
    for q=1:n,rows(q).truth_member_count=2;end
    metrics=stage4a7_2_r1_nonunique_metrics(rows,h);legacy_out=struct('status','completed','rows',rows,'metrics',metrics,'calibration_status',model.status,'source_tree_hash',source_hash,'pair_ids',sprintf('%s,%s',ids{pair},ids{pair2}));near=near_symmetry_rows(legacy(pair),legacy(pair2),cache,model,sc,base,h);
end
function rows=distance_rows(data,cache,h)
    rows=repmat(struct('sample_id','','candidate_id','','profile_distance',NaN,'best_template_index',0,'template_count',0,'scientific_hash',''),0,1);for k=1:numel(data),if ~isfield(data(k),'observed_views')||isempty(data(k).observed_views),continue;end;o=stage4a7_2_r1_profile_distance(data(k).observed_views,cache);for j=1:numel(cache.candidate_ids),r=rows_template();r.sample_id=data(k).sample_id;r.candidate_id=cache.candidate_ids{j};r.profile_distance=o.profile_distances(j);r.best_template_index=o.best_template_indices(j);r.template_count=cache.template_count; r.scientific_hash=h;rows(end+1)=r;end,end,end
function rows=distance_rows_all(groups,cache,h)
    rows=repmat(rows_template(),0,1);
    for k=1:numel(groups)
        part=distance_rows(groups{k},cache,h);
        if ~isempty(part),rows=[rows;part(:)];end %#ok<AGROW>
    end
end
function r=rows_template(),r=struct('sample_id','','candidate_id','','profile_distance',NaN,'best_template_index',0,'template_count',0,'scientific_hash','');end
function rows=candidate_rows(a,b,h)
    rows=repmat(struct('candidate_id','','canonical_graph_key','','generation_route','','prior_cost',NaN,'forward_model_compatible',false,'scored_library_included',false,'compatibility_reason','','scientific_hash',''),0,1);
    groups={a,b};
    for g=1:numel(groups)
        for k=1:numel(groups{g})
            c=groups{g}(k);r=rows_template_candidate();r.candidate_id=candidate_id(c);r.canonical_graph_key=c.canonical_graph_key;r.generation_route=c.generation_route;r.prior_cost=c.prior_cost;r.forward_model_compatible=getb(c,'forward_model_compatible',false);r.scored_library_included=getb(c,'scored_library_included',false);r.compatibility_reason=getf(c,'compatibility_reason','');r.scientific_hash=h;rows(end+1)=r;
        end
    end
end
function r=rows_template_candidate(),r=struct('candidate_id','','canonical_graph_key','','generation_route','','prior_cost',NaN,'forward_model_compatible',false,'scored_library_included',false,'compatibility_reason','','scientific_hash','');end
function [c,rows]=adapt_all(c,base,h)
    rows=repmat(struct('candidate_id','','round_trip_ok',false,'forward_model_compatible',false,'reason_code','','reconstruction_source','','attribute_mismatch_count',NaN,'scientific_hash',''),numel(c),1);
    updated=cell(1,numel(c));
    for k=1:numel(c)
        [updated{k},rep]=check_forward_model_compatibility(c(k),base);
        rows(k).candidate_id=candidate_id(updated{k});rows(k).round_trip_ok=getb(rep,'round_trip_ok',false);rows(k).forward_model_compatible=getb(rep,'forward_model_compatible',false);rows(k).reason_code=getf(rep,'reason_code','');
        if isfield(rep,'round_trip_report'),rows(k).reconstruction_source=getf(rep.round_trip_report,'reconstruction_source','');rows(k).attribute_mismatch_count=getf(rep.round_trip_report,'attribute_mismatch_count',NaN);end
        rows(k).scientific_hash=h;
    end
    updated=normalize_candidate_structs(updated);
    if ~isempty(updated),c=[updated{:}];else,c=c([]);end
end
function c=label_candidates(c,prefix),for k=1:numel(c),id=sprintf('%s_%03d',prefix,k);c(k).topology_id=id;c(k).id=id;c(k).graph_candidate_id=id;end,end
function id=reference_candidate_id(ref,candidates),target=canonicalize_asset_graph(ref.node_ids,ref.edges,struct());id='';for k=1:numel(candidates),if strcmp(candidates(k).canonical_graph_key,target.canonical_graph_key),id=candidate_id(candidates(k));return;end,end,end
function key=reference_graph_key(ref),target=canonicalize_asset_graph(ref.node_ids,ref.edges,struct());key=target.canonical_graph_key;end
function ix=truth_indices(rows,ids),ix=zeros(numel(rows),1);for k=1:numel(rows),ix(k)=find(strcmp(ids,rows(k).truth_topology_id),1);end,end
function r=scenario_template(),r=struct('sample_id','','physical_scenario_id','','split','','category','','truth_topology_id','','truth_set','','parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','case_seed',0,'observed_views',{{}},'truth_theta',struct());end
function id=candidate_id(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);elseif isfield(c,'graph_candidate_id'),id=char(c.graph_candidate_id);else,id='';end,end
function cells=normalize_candidate_structs(cells)
    if isempty(cells),return;end
    names={};
    for k=1:numel(cells),names=[names;fieldnames(cells{k})];end %#ok<AGROW>
    names=unique(names,'stable');
    for k=1:numel(cells)
        current=fieldnames(cells{k});
        for j=1:numel(names)
            if ~any(strcmp(current,names{j})),cells{k}.(names{j})=[];end
        end
    end
end
function x=getb(s,n,d),if isfield(s,n),x=logical(s.(n));else,x=d;end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_nonunique_den(s)
    x=0;if ~isstruct(s)||~isfield(s,'metrics')||isempty(s.metrics),return;end
    ix=find(strcmp({s.metrics.metric_id},'false_unique_conditional_rate'),1);if ~isempty(ix),x=s.metrics(ix).denominator;end
end
function rows=near_symmetry_rows(c1,c2,cache,model,sc,base,h)
    n=sc.scenario_design.near_symmetry_count;deltas=[.001 .005 .01 .02 .05];rows=repmat(struct('sample_id','','perturbation_fraction',NaN,'set_size',0,'accepted_set','','same_theta_distance',NaN,'source_tree_hash',''),n,1);for q=1:n;delta=deltas(1+mod(q-1,numel(deltas)));theta=cache.theta_grid(1+mod(q-1,numel(cache.theta_grid)));theta2=theta;theta2.main_length_scale=theta2.main_length_scale*(1+delta);[n1,l1]=topology_apply_parameters(c1.network,base,theta);[m1,~]=plc_measurement_bundle(sc.measurement_kind,n1,theta,l1);[v1,~]=plc_multiview_response(sc.frequency_hz,n1,m1,l1);[n2,l2]=topology_apply_parameters(c2.network,base,theta2);[m2,~]=plc_measurement_bundle(sc.measurement_kind,n2,theta2,l2);[v2,~]=plc_multiview_response(sc.frequency_hz,n2,m2,l2);same=sqrt(mean(abs(v1{1}-v2{1}).^2));o=stage4a7_2_r1_apply_profile_candidate_set(stage4a7_2_r1_profile_distance({v1{1}},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm)).profile_distances,model,'absolute');rows(q).sample_id=sprintf('r1_near_symmetry_%03d',q);rows(q).perturbation_fraction=delta;rows(q).set_size=numel(o.accepted_candidate_set);rows(q).accepted_set=strjoin(o.accepted_candidate_set,',');rows(q).same_theta_distance=same;rows(q).source_tree_hash=h;end
end
function write_rows(path,rows),if isempty(rows),fid=fopen(path,'w');fprintf(fid,'empty\n');fclose(fid);elseif istable(rows),writetable(rows,path);else,writetable(struct2table(rows),path);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
