function summary=exp_stage4a7_2_candidate_closure(root_dir,mode)
%EXP_STAGE4A7_2_CANDIDATE_CLOSURE Stage 4A.7.2 controlled second-tier Pilot.
%   The experiment keeps the stable physical model unchanged and records
%   engineering generation, adaptation, lazy Top-K, calibrated score
%   families, and independent non-unique clusters separately.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end;if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));base=default_config(root_dir);sc=stage4a7_2_candidate_closure_config(base,mode);ensure_dir(sc.results_data);ensure_dir(sc.results_logs);t0=tic;source_hash=stage4a7_2_source_tree_hash(root_dir);scientific_hash=stage4a4_scientific_config_hash(struct('stage',sc.stage_name,'version',sc.version,'grid',sc.frequency_hz,'mode',sc.mode,'seeds',sc.seeds,'design',sc.scenario_design,'nonunique',sc.nonunique,'source_tree_hash',source_hash));
    raw=generate_radial_topology_candidates(stage4a1_config(base).generator);[candidates,adapter_rows]=engineering_candidates(raw,base);ids={candidates.id};groups=ids;groups{4}='G004_G007';groups{7}='G004_G007';
    spec=small_spec(sc);[full,full_audit]=generate_engineering_topology_candidates(spec);[tk,tk_audit]=generate_topk_topology_candidates(spec,sc.top_k);tk_keys={tk.canonical_graph_key};full_keys={full.canonical_graph_key};[tk_all,tk_all_audit]=generate_topk_topology_candidates(spec,numel(full));tk_all_keys={tk_all.canonical_graph_key};topk_row=struct('mode',mode,'top_k_requested',sc.top_k,'returned_count_at_requested_k',numel(tk),'full_candidate_count',numel(full),'returned_count_at_full_k',numel(tk_all),'key_set_equal_when_k_full',isequal(full_keys,tk_all_keys),'topk_unique_at_requested_k',numel(unique(tk_keys))==numel(tk_keys),'states_pushed',tk_audit.states_pushed,'states_popped',tk_audit.states_popped,'states_expanded',tk_audit.states_expanded,'complete_candidates',tk_audit.complete_candidates,'cycle_pruned',tk_audit.cycle_pruned,'bound_pruned',tk_audit.bound_pruned,'duplicate_pruned',tk_audit.duplicate_pruned,'peak_queue_size',tk_audit.peak_queue_size,'exhausted_at_full_k',tk_all_audit.exhausted,'theoretical_edge_subset_count',full_audit.theoretical_edge_subset_count,'scientific_hash',scientific_hash);
    grid=topology_parameter_grid(stage4a5_1_integrity_config(base,'formal').parameter_search);
    dev=make_rows(candidates,candidates,base,grid,sc.scenario_design.development_per_candidate,sc.seeds.development,'development','in_domain',sc.frequency_hz);
    cal=make_rows(candidates,candidates,base,grid,sc.scenario_design.calibration_per_candidate,sc.seeds.calibration,'calibration','in_domain',sc.frequency_hz);
    pilot=make_rows(candidates,candidates,base,grid,sc.scenario_design.pilot_in_domain_per_candidate,sc.seeds.pilot,'pilot','in_domain',sc.frequency_hz);
    pilot=[pilot;make_rows(candidates,candidates,base,grid,sc.scenario_design.pilot_parameter_ood_per_candidate,sc.seeds.pilot+101,'pilot','parameter_ood',sc.frequency_hz)];
    outside=make_outside_candidate(raw,base);pilot=[pilot;make_rows({outside},candidates,base,grid,sc.scenario_design.pilot_structure_ool_count,sc.seeds.pilot+202,'pilot','structure_out',sc.frequency_hz)];
    nonunique_timer=tic;[clusters,cluster_audit]=build_stage4a7_2_nonunique_clusters(candidates,base,sc.nonunique.requested_count,sc.seeds.nonunique,sc.nonunique.tau_exact,sc.nonunique.profile_tolerance);near_symmetry=build_stage4a7_2_near_symmetry(candidates,base,sc.seeds.nonunique+20,[.001 .005 .01 .02 .05],10,sc.nonunique.tau_exact);nonunique_s=toc(nonunique_timer);
    Ddev=vertcat(dev.distances);Dcal=vertcat(cal.distances);Dpilot=vertcat(pilot.distances);scale=median(Ddev,1);scale(~isfinite(scale)|scale<=0)=1;model=calibrate_candidate_nonconformity_family(Dcal,[cal.truth_index],ids,groups,sc.alpha,struct('scales',scale,'minimum_per_candidate',sc.scenario_design.calibration_per_candidate));
    methods={'absolute','scaled','ratio','margin','absolute_I'};metric_rows=repmat(metric_template(),0,1);all_decisions=repmat(decision_template(),0,1);
    for q=1:numel(methods)
        [metric_rows,all_decisions]=append_method_results(metric_rows,all_decisions,methods{q},pilot,model,sc.alpha,candidates,scientific_hash);
    end
    dev_rows=score_rows(Ddev,dev,ids,groups,scale,scientific_hash);independence=independence_rows(dev,cal,pilot,scientific_hash);coverage_rows=coverage_audit_rows(candidates,outside,ids,scientific_hash);complexity_rows=complexity_audit_rows(candidates,grid,scientific_hash);
    write_rows(fullfile(sc.results_data,'topk_audit.csv'),topk_row);write_rows(fullfile(sc.results_data,'adapter_audit.csv'),adapter_rows);write_rows(fullfile(sc.results_data,'score_development.csv'),dev_rows);write_rows(fullfile(sc.results_data,'confirmation_metrics.csv'),metric_rows);write_rows(fullfile(sc.results_data,'nonunique_clusters.csv'),clusters);write_rows(fullfile(sc.results_data,'independence_audit.csv'),independence);write_rows(fullfile(sc.results_data,'candidate_coverage_audit.csv'),coverage_rows);write_rows(fullfile(sc.results_data,'complexity_audit.csv'),complexity_rows);write_rows(fullfile(sc.results_data,'scenario_manifest.csv'),manifest_rows([dev;cal;pilot],scientific_hash));write_rows(fullfile(sc.results_data,'near_symmetry.csv'),near_symmetry);
    runtime=struct('mode',mode,'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'nonunique_requested',sc.nonunique.requested_count,'nonunique_generated',numel(clusters),'nonunique_runtime_s',nonunique_s,'total_runtime_s',toc(t0),'use_parallel',false,'num_workers',1,'scientific_hash',scientific_hash,'source_tree_hash',source_hash,'final_reserved_status',sc.final_reserved.status);write_rows(fullfile(sc.results_data,'runtime_summary.csv'),runtime);
    summary=struct('stage_name',sc.stage_name,'mode',mode,'status',ternary(cluster_audit.generated_count>=50,'completed_controlled_pilot','partial_insufficient_nonunique_clusters'),'engineering_candidate_count',numel(candidates),'forward_compatible_candidate_count',nnz([candidates.forward_model_compatible]),'scored_candidate_count',nnz([candidates.scored_library_included]),'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'nonunique_cluster_count',numel(clusters),'profile_equivalent_cluster_count',nnz([clusters.profile_equivalent]),'near_symmetry_row_count',numel(near_symmetry),'candidate_set_calibration_status',model.status,'minimum_attainable_p_value',min([model.classes.minimum_attainable_p]),'scientific_hash',scientific_hash,'source_tree_hash',source_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);save(fullfile(sc.results_data,'stage4a7_2_results.mat'),'summary','sc','candidates','model','clusters','near_symmetry','metric_rows','all_decisions','runtime','-v7.3');write_rows(fullfile(sc.results_data,'summary.csv'),summary);fprintf('Stage 4A.7.2 %s completed: dev=%d cal=%d pilot=%d nonunique=%d in %.3f s.\n',mode,numel(dev),numel(cal),numel(pilot),numel(clusters),runtime.total_runtime_s);
end

function [out,rows]=engineering_candidates(raw,cfg)
    out_cell=cell(1,numel(raw));rows=repmat(struct('candidate_id','','forward_model_compatible',false,'reason_code','','round_trip_ok',false,'legacy_cfr_distance',NaN,'scientific_hash',''),1,0);f=linspace(2e6,30e6,61);for k=1:numel(raw),r=raw(k);spec=struct('node_ids',{ {r.nodes.id} },'source_node_id',r.source_node,'receiver_node_id',r.receiver_node,'allowed_edges',r.edges,'required_edges',r.edges,'forbidden_edges',[],'edge_prior_cost',zeros(1,numel(r.edges)),'maximum_candidate_count',4,'radial_only',true,'require_connected',true,'prior_source','synthetic_demo_prior_not_field_data');[x,~]=generate_engineering_topology_candidates(spec);x=x(1);x.id=r.topology_id;x.name=r.topology_id;[x,rep]=check_forward_model_compatibility(x,cfg);out_cell{k}=x;[a,la]=topology_apply_parameters(r.network,cfg,nominal_theta());[ma,~]=plc_measurement_bundle('siso_forward',a,nominal_theta(),la);[ha,~]=plc_multiview_response(f,a,ma,la);[b,lb]=topology_apply_parameters(x.network,cfg,nominal_theta());[mb,~]=plc_measurement_bundle('siso_forward',b,nominal_theta(),lb);[hb,~]=plc_multiview_response(f,b,mb,lb);rows(end+1)=struct('candidate_id',r.topology_id,'forward_model_compatible',rep.forward_model_compatible,'reason_code',getf(rep,'reason_code',''),'round_trip_ok',getf(rep,'round_trip_ok',false),'legacy_cfr_distance',sqrt(mean(abs(ha{1}-hb{1}).^2)),'scientific_hash',stage4a4_scientific_config_hash(struct('candidate',r.topology_id)));end;out=[out_cell{:}];
    end
function t=nominal_theta(),t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',50,'receiver_impedance_ohm',50,'regularization',0);end
function [rows]=make_rows(truth_candidates,score_candidates,cfg,grid,nper,seed,split,category,f)
    if ~iscell(truth_candidates),truth_candidates=num2cell(truth_candidates);end;if ~iscell(score_candidates),score_candidates=num2cell(score_candidates);end;first=template_row();rows=repmat(first,0,1);stream=RandStream('mt19937ar','Seed',seed);for k=1:numel(truth_candidates),c=truth_candidates{k};for q=1:nper,t=sample_independent_theta(grid,stream,k,q);if strcmp(category,'parameter_ood'),t=ood_theta(t,q);end;[~,~,d,h]=observe_and_score(c,score_candidates,cfg,t,f,score_candidates);r=first;r.sample_id=sprintf('stage4a7_2_%s_%s_%02d_%02d',split,category,k,q);r.physical_scenario_id=r.sample_id;r.split=split;r.category=category;r.truth_topology_id=getf(c,'id',getf(c,'graph_candidate_id',''));r.truth_index=ternary(strcmp(category,'structure_out'),0,k);r.truth_set=r.truth_topology_id;r.parameter_vector_hash=stage4a4_scientific_config_hash(t);r.noiseless_cfr_hash=stage4a4_scientific_config_hash(h);r.observation_hash=r.noiseless_cfr_hash;r.distances=d;r.case_seed=seed+1009*k+q;rows(end+1)=r;end;end;rows=rows(:);
end
function t=sample_independent_theta(grid,stream,k,q)
    t=grid(1+mod(k*7919+q*104729-1,numel(grid)));
    u=rand(stream,1,5);
    t.main_length_scale=.92+.16*u(1);
    t.branch_length_scale=.92+.16*u(2);
    t.branch_load_scale=.80+.40*u(3);
    t.source_impedance_ohm=40+20*u(4);
    t.receiver_impedance_ohm=40+20*u(5);
    t.regularization=0;
end
function [net,meta,d,h]=observe_and_score(c,candidates,cfg,t,f,scored)
    [net,lc]=topology_apply_parameters(c.network,cfg,t);[m,~]=plc_measurement_bundle('siso_forward',net,t,lc);[v,~]=plc_multiview_response(f,net,m,lc);h=v{1};d=zeros(1,numel(candidates));for j=1:numel(candidates),[nn,ll]=topology_apply_parameters(candidates{j}.network,cfg,t);[mm,~]=plc_measurement_bundle('siso_forward',nn,t,ll);[vv,~]=plc_multiview_response(f,nn,mm,ll);d(j)=sqrt(mean(abs(h-vv{1}).^2));end;meta=struct('scored_count',numel(scored));
end
function t=ood_theta(t,q),if mod(q,2)==0,t.main_length_scale=1.15+0.01*mod(q,5);else,t.branch_load_scale=1.35+0.02*mod(q,5);end;t.regularization=NaN;end
function c=make_outside_candidate(raw,cfg)
    % Build a graph outside the frozen seven-graph grammar rather than
    % relabeling an in-library graph.  This is still a model-internal
    % structure-OOL control, not a field network.
    g0=raw(1);g=stage4a1_config(cfg).generator;g.max_branches=3;g.max_side_branches_per_node=1;g.max_candidates=128;
    expanded=generate_radial_topology_candidates(g);known={raw.canonical_key};pick=[];
    for j=1:numel(expanded)
        if ~any(strcmp(expanded(j).canonical_key,known)),pick=j;break;end
    end
    if isempty(pick),error('stage4a7_2:NoStructureOutsideCandidate','Unable to construct an outside-grammar candidate.');end
    r=expanded(pick);spec=struct('node_ids',{ {r.nodes.id} },'source_node_id',r.source_node,'receiver_node_id',r.receiver_node,'allowed_edges',r.edges,'required_edges',r.edges,'forbidden_edges',[],'edge_prior_cost',zeros(1,numel(r.edges)),'maximum_candidate_count',4,'radial_only',true,'require_connected',true,'prior_source','synthetic_demo_prior_not_field_data'); %#ok<NASGU>
    % Use the generated graph directly as the engineering specification so
    % the adapter, not a nominal relabel, determines compatibility.
    [c,~]=generate_engineering_topology_candidates(spec);c=c(1);c.id='STRUCTURE_OOL_ENGINEERING_CANDIDATE';[c,~]=check_forward_model_compatibility(c,cfg);
end
function rows=score_rows(D,data,ids,groups,scale,hash),f=score_candidate_nonconformity_family(D,ids,groups,scale);methods={'absolute','scaled','ratio','margin'};rows=repmat(struct('method_id','','sample_count',0,'mean_score',NaN,'calibration_hash','','scientific_hash',''),1,numel(methods));for k=1:numel(methods),z=f.(methods{k});rows(k)=struct('method_id',methods{k},'sample_count',size(D,1),'mean_score',mean(z(:),'omitnan'),'calibration_hash','','scientific_hash',hash);end,end
function [metrics,decisions]=append_method_results(metrics,decisions,method,data,model,alpha,candidates,hash)
    start_idx=numel(decisions)+1;mr=repmat(metric_template(),0,1);
    for k=1:numel(data)
        if strcmp(method,'absolute_I')
            sets=apply_candidate_nonconformity_set_indistinguishable(data(k).distances,model,alpha,1e-12);
        else
            all_sets=apply_candidate_nonconformity_set(data(k).distances,model,alpha);
            q=find(strcmp({all_sets.method_id},method),1);sets=all_sets(q);
        end
        a=sets.accepted_candidate_set;hit=any(strcmp(a,data(k).truth_set));r=decision_template();
        r.sample_id=data(k).sample_id;r.method_id=method;r.category=data(k).category;
        r.accepted_set=strjoin(a,',');r.set_size=numel(a);r.hit=hit;
        r.parameter_vector_hash=data(k).parameter_vector_hash;r.calibration_hash=getf(model,'calibration_hash','');r.scientific_hash=hash;
        decisions(end+1)=r; %#ok<AGROW>
    end
    new_decisions=decisions(start_idx:end);cats=unique({data.category});
    for h=1:numel(cats)
        z=new_decisions(strcmp({new_decisions.category},cats{h}));
        mr(end+1)=make_metric(method,cats{h},'coverage',sum([z.hit]),numel(z),hash,getf(model,'calibration_hash','')); %#ok<AGROW>
        mr(end+1)=make_metric(method,cats{h},'singleton_rate',sum([z.set_size]==1),numel(z),hash,getf(model,'calibration_hash','')); %#ok<AGROW>
        mr(end+1)=make_metric(method,cats{h},'empty_set_rate',sum([z.set_size]==0),numel(z),hash,getf(model,'calibration_hash','')); %#ok<AGROW>
        mr(end+1)=make_metric(method,cats{h},'average_set_size',sum([z.set_size]),numel(z),hash,getf(model,'calibration_hash','')); %#ok<AGROW>
    end
    metrics=[metrics;mr]; %#ok<AGROW>
end
function r=make_metric(m,c,n,num,d,h,ch),r=metric_template();r.method_id=m;r.category=c;r.metric_name=n;r.numerator=num;r.denominator=d;if d>0,r.rate=num/d;else,r.rate=NaN;end;if ismember(n,{'coverage','singleton_rate','empty_set_rate'}),[r.ci_low,r.ci_high]=stage4a7_2_wilson_interval(num,d);end;r.scientific_hash=h;r.calibration_hash=ch;end
function r=metric_template(),r=struct('method_id','','category','','metric_name','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'calibration_hash','','scientific_hash','');end
function r=decision_template(),r=struct('sample_id','','method_id','','category','','accepted_set','','set_size',0,'hit',false,'parameter_vector_hash','','calibration_hash','','scientific_hash','');end
function r=template_row(),r=struct('sample_id','','physical_scenario_id','','split','','category','','truth_topology_id','','truth_index',0,'truth_set','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','distances',[],'case_seed',0);end
function rows=coverage_audit_rows(candidates,outside,ids,hash)
    first=struct('truth_category','','truth_topology_id','','truth_in_engineering_space',false, ...
        'truth_forward_model_compatible',false,'truth_in_scored_library',false, ...
        'coverage_failure_reason','','scientific_hash','');rows=repmat(first,0,1);
    for k=1:numel(candidates)
        a=build_candidate_coverage_audit(candidates,ids,struct('truth_topology_id',candidates(k).id));
        rows(end+1)=struct('truth_category','in_domain','truth_topology_id',candidates(k).id, ...
            'truth_in_engineering_space',a.truth_in_engineering_space, ...
            'truth_forward_model_compatible',a.truth_forward_model_compatible, ...
            'truth_in_scored_library',a.truth_in_scored_library, ...
            'coverage_failure_reason',a.coverage_failure_reason,'scientific_hash',hash); %#ok<AGROW>
    end
    a=build_candidate_coverage_audit(candidates,ids,struct('truth_topology_id',outside.id));
    rows(end+1)=struct('truth_category','structure_out','truth_topology_id',outside.id, ...
        'truth_in_engineering_space',a.truth_in_engineering_space, ...
        'truth_forward_model_compatible',a.truth_forward_model_compatible, ...
        'truth_in_scored_library',a.truth_in_scored_library, ...
        'coverage_failure_reason',a.coverage_failure_reason,'scientific_hash',hash);
end
function rows=complexity_audit_rows(candidates,grid,hash)
    first=struct('candidate_id','','parameter_dimension',0,'template_count_per_candidate',0, ...
        'edge_count',0,'node_count',0,'prior_cost',NaN,'complexity_audit_status','','scientific_hash','');
    rows=repmat(first,0,1);
    for k=1:numel(candidates)
        p=3;if isfield(candidates(k),'network')&&isfield(candidates(k).network,'branches')&&~isempty(candidates(k).network.branches),p=5;end
        rows(end+1)=struct('candidate_id',candidates(k).id,'parameter_dimension',p, ...
            'template_count_per_candidate',numel(grid),'edge_count',candidates(k).edge_count, ...
            'node_count',candidates(k).node_count,'prior_cost',candidates(k).prior_cost, ...
            'complexity_audit_status','descriptive_no_aic_bic','scientific_hash',hash); %#ok<AGROW>
    end
end
function rows=manifest_rows(data,hash),rows=repmat(struct('sample_id','','physical_scenario_id','','split','','category','','truth_topology_id','','truth_set','','truth_index',0,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','case_seed',0,'scientific_hash',''),1,numel(data));for k=1:numel(data),rows(k)=struct('sample_id',data(k).sample_id,'physical_scenario_id',data(k).physical_scenario_id,'split',data(k).split,'category',data(k).category,'truth_topology_id',data(k).truth_topology_id,'truth_set',data(k).truth_set,'truth_index',data(k).truth_index,'parameter_vector_hash',data(k).parameter_vector_hash,'noiseless_cfr_hash',data(k).noiseless_cfr_hash,'observation_hash',data(k).observation_hash,'case_seed',data(k).case_seed,'scientific_hash',hash);end,end
function rows=independence_rows(a,b,c,hash),rows=repmat(struct('split','','row_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',0,'duplicate_parameter_count',0,'duplicate_cfr_count',0,'scientific_hash',''),1,3);z={a,b,c};for k=1:3,rows(k).split=ternary(k==1,'development',ternary(k==2,'calibration','pilot'));rows(k).row_count=numel(z{k});rows(k).unique_parameter_hash_count=numel(unique({z{k}.parameter_vector_hash}));rows(k).unique_cfr_hash_count=numel(unique({z{k}.noiseless_cfr_hash}));rows(k).duplicate_parameter_count=rows(k).row_count-rows(k).unique_parameter_hash_count;rows(k).duplicate_cfr_count=rows(k).row_count-rows(k).unique_cfr_hash_count;rows(k).scientific_hash=hash;end,end
function write_rows(path,rows),if isempty(rows),fid=fopen(path,'w');fprintf(fid,'empty\n');fclose(fid);else,rows=rows(:);writetable(struct2table(rows),path);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function s=small_spec(sc),s=struct('node_ids',{{'A','B','C','D'}},'source_node_id','A','receiver_node_id','D','allowed_edges',{{'A','B';'A','C';'A','D';'B','C';'B','D';'C','D'}},'required_edges',{{'A','B'}},'forbidden_edges',{{'C','D'}},'maximum_degree',3,'maximum_candidate_count',128,'radial_only',true,'require_connected',true,'prior_source',sc.prior_source,'edge_prior_cost',[0;3;1;2;4;5]);end
