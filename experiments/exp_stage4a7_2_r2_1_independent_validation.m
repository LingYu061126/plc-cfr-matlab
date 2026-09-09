function summary=exp_stage4a7_2_r2_1_independent_validation(root,mode,output_root,stage_name)
%EXP_STAGE4A7_2_R2_1_INDEPENDENT_VALIDATION Off-grid/noisy independent splits.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));base=default_config(root);
    if nargin<3,output_root=[];end;if nargin<4,stage_name=[];end
    sc=stage4a7_2_r2_1_protocol_config(base,mode,output_root,stage_name);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);t0=tic;
    [reference,~]=read_stage4a7_2_r1_public_subnetwork(sc.derived_subnetwork);
    manifest=stage4a7_2_r2_external_manifest(root,sc.derived_subnetwork);
    [ledger,bench_audit]=stage4a7_2_r2_1_build_benchmark_ledger(reference,sc,'nominal',sc.seeds.development); %#ok<NASGU>
    [spec,deploy_audit]=stage4a7_2_r2_1_build_deployment_spec(ledger,sc);
    [engineering,eng_audit]=generate_engineering_topology_candidates(spec);
    [engineering,compatible,reports]=adapt_all(engineering,base); %#ok<ASGLU>
    fprintf('R2.1 %s: generated engineering=%d compatible=%d\n',mode,numel(engineering),nnz(compatible));
    scored=stage4a7_2_r2_sort_candidates(engineering(compatible));
    for k=1:numel(scored),scored(k).topology_id=sprintf('R21C_%03d',k);scored(k).id=scored(k).topology_id;end
    theta_grid=topology_parameter_grid(sc.parameter_search);
    cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,scored,theta_grid,base,sc.measurement_kind);
    cache.template_count_per_candidate=numel(theta_grid);cache.total_template_count=numel(theta_grid)*numel(scored);
    ids=stage4a7_2_r2_1_build_hashes(root,sc,manifest,scored,cache);
    fprintf('R2.1 %s: template cache candidates=%d templates_per_candidate=%d total_templates=%d\n',mode,numel(scored),numel(theta_grid),cache.total_template_count);
    checkpoint(fullfile(sc.results_data,'checkpoint_identity.mat'),struct('ids',ids,'scored',scored,'cache',cache));
    fprintf('R2.1 %s: materialize development nper=%d\n',mode,sc.scenario_design.development_per_candidate);
    [dev,devD]=materialize('development',sc.scenario_design.development_per_candidate,sc.seeds.development,scored,cache,base,sc);
    checkpoint(fullfile(sc.results_data,'checkpoint_development.mat'),struct('dev',dev,'devD',devD,'ids',ids));
    fprintf('R2.1 %s: materialize calibration nper=%d\n',mode,sc.scenario_design.calibration_per_candidate);
    [cal,calD]=materialize('calibration',sc.scenario_design.calibration_per_candidate,sc.seeds.calibration,scored,cache,base,sc);
    checkpoint(fullfile(sc.results_data,'checkpoint_calibration.mat'),struct('cal',cal,'calD',calD,'ids',ids));
    fprintf('R2.1 %s: materialize pilot nper=%d\n',mode,sc.scenario_design.pilot_per_candidate);
    [pilot,pilotD]=materialize('pilot',sc.scenario_design.pilot_per_candidate,sc.seeds.pilot,scored,cache,base,sc);
    checkpoint(fullfile(sc.results_data,'checkpoint_pilot.mat'),struct('pilot',pilot,'pilotD',pilotD,'ids',ids));
    [selected,sel_rows,method_models,sel_manifest]=stage4a7_2_r2_calibrated_method_selection(devD,{dev.truth_topology_id},calD,{cal.truth_topology_id},{scored.topology_id},sc,ids.experiment_hash);
    selected_model=method_models{find(strcmp(sc.method_selection.method_ids,selected),1)};
    decisions=apply_split(pilot,pilotD,selected_model,selected,ids);
    pilot_metrics=stage4a7_2_r2_1_evaluate_pilot_metrics(decisions,ids.experiment_hash);
    [nearest,eqsummary]=equivalence_audit(scored,theta_grid,sc,base);
    [cov,corrupt,corruption_manifest]=coverage_audit(reference,sc,base);
    all_scenarios=[dev cal pilot];
    write_rows(fullfile(sc.results_data,'external_data_manifest.csv'),manifest);write_rows(fullfile(sc.results_data,'deployment_audit.csv'),deploy_audit);write_rows(fullfile(sc.results_data,'candidate_generation_audit.csv'),eng_audit);write_rows(fullfile(sc.results_data,'candidate_coverage_audit.csv'),cov);write_rows(fullfile(sc.results_data,'ledger_corruption_audit.csv'),corrupt);write_rows(fullfile(sc.results_data,'corruption_manifest.csv'),corruption_manifest);write_rows(fullfile(sc.results_data,'nearest_competitor_audit.csv'),nearest);write_rows(fullfile(sc.results_data,'scenario_equivalence_audit.csv'),eqsummary);write_rows(fullfile(sc.results_data,'pilot_decisions.csv'),decisions);write_rows(fullfile(sc.results_data,'method_selection.csv'),sel_rows);write_rows(fullfile(sc.results_data,'identity_manifest.csv'),identity_rows(ids));
    if isfield(sel_manifest,'bootstrap_comparisons'),write_rows(fullfile(sc.results_data,'method_selection_bootstrap.csv'),sel_manifest.bootstrap_comparisons);end
    write_rows(fullfile(sc.results_data,'scenario_manifest.csv'),scenario_manifest_rows(all_scenarios));
    write_rows(fullfile(sc.results_data,'independence_audit.csv'),independence_rows(all_scenarios));
    write_rows(fullfile(sc.results_data,'parameter_calibration_thresholds.csv'),calibration_rows(method_models,sc.method_selection.method_ids,ids));
    write_rows(fullfile(sc.results_data,'configuration_manifest.csv'),configuration_row(sc,ids,selected,selected_model,sel_manifest,run_status_if(mode)));
    write_rows(fullfile(sc.results_data,'pilot_metrics.csv'),pilot_metrics);
    run_status=ternary(strcmp(mode,'smoke'),'smoke_completed','formal_completed');
    summary=struct('stage_name',sc.stage_name,'mode',mode,'status',run_status,'engineering_candidate_count',numel(engineering),'forward_compatible_candidate_count',nnz(compatible),'profile_scored_candidate_count',numel(scored),'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'selected_method',selected,'scientifically_unique_winner',getf(sel_manifest,'scientifically_unique_winner',false),'experiment_hash',ids.experiment_hash,'source_tree_hash',ids.source_tree_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false,'elapsed_s',toc(t0));
    write_rows(fullfile(sc.results_data,'summary.csv'),summary);save(fullfile(sc.results_data,'summary.mat'),'summary','ids','sc','bench_audit','deploy_audit','eng_audit','cov','corrupt','corruption_manifest','nearest','eqsummary','dev','cal','pilot','devD','calD','pilotD','method_models','selected_model','sel_rows','sel_manifest','pilot_metrics','-v7');
    fprintf('Stage 4A.7.2-R.2.1 %s completed: engineering=%d compatible=%d scored=%d calibration=%d pilot=%d method=%s in %.3f s.\n',mode,numel(engineering),nnz(compatible),numel(scored),numel(cal),numel(pilot),selected,toc(t0));
end

function [c,ok,r]=adapt_all(input_candidates,base)
    ok=false(1,numel(input_candidates));r=cell(1,numel(input_candidates));cells=cell(1,numel(input_candidates));
    for k=1:numel(input_candidates)
        [cells{k},r{k}]=check_forward_model_compatibility(input_candidates(k),base);
        candidate=cells{k};
        ok(k)=logical(candidate.forward_model_compatible);
    end
    if isempty(cells),c=struct([]);return;end
    names={};
    for k=1:numel(cells),names=union(names,fieldnames(cells{k})');end
    for k=1:numel(cells)
        for q=1:numel(names)
            if ~isfield(cells{k},names{q}),cells{k}.(names{q})=[];end
        end
    end
    c=repmat(cells{1},1,numel(cells));
    for k=2:numel(cells),c(k)=cells{k};end
end
function [rows,D]=materialize(split,nper,master,candidates,cache,base,sc)
    rows=repmat(scenario_row(),0,1);D=zeros(0,numel(candidates));
    total=numel(candidates)*nper;done=0;
    for k=1:numel(candidates),for q=1:nper
        sample_id=sprintf('r21_%s_%03d_%03d',split,k,q);seed=stage4a7_2_r2_1_stable_case_seed(master,sample_id);rs=RandStream('mt19937ar','Seed',seed);theta=offgrid_theta(rs);[net,local]=topology_apply_parameters(candidates(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);truth=v{1}(:).';obs=add_noise(truth,sc.noise.snr_db,rs);o=stage4a7_2_r1_profile_distance({obs},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));r=scenario_row();r.sample_id=sample_id;r.physical_scenario_id=sample_id;r.split=split;r.truth_topology_id=getid(candidates(k));r.truth_theta=theta;r.case_seed=seed;r.parameter_vector_hash=stage4a4_scientific_config_hash(theta);r.noiseless_cfr_hash=stage4a4_scientific_config_hash(truth);r.observation_hash=stage4a4_scientific_config_hash(obs);r.noise_snr_db=sc.noise.snr_db;rows(end+1)=r;D(end+1,:)=o.profile_distances; %#ok<AGROW>
        done=done+1;if done==1||mod(done,100)==0||done==total,fprintf('R2.1 %s materialize %d/%d\n',split,done,total);end
    end,end
end
function t=offgrid_theta(rs),t=struct('main_length_scale',.95+.1*rand(rs),'branch_length_scale',.95+.1*rand(rs),'branch_load_scale',.8+.4*rand(rs),'source_impedance_ohm',45+10*rand(rs),'receiver_impedance_ohm',45+10*rand(rs),'regularization',0);end
function y=add_noise(x,snr,rs),sig=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+sig*(randn(rs,size(x))+1i*randn(rs,size(x)));end
function out=apply_split(rows,D,model,method,ids),out=repmat(decision_row(),numel(rows),1);for k=1:numel(rows),a=stage4a7_2_r1_apply_profile_candidate_set(D(k,:),model,method);out(k).sample_id=rows(k).sample_id;out(k).split=rows(k).split;out(k).truth_topology_id=rows(k).truth_topology_id;out(k).accepted_set=strjoin(a.accepted_candidate_set,',');out(k).set_size=a.set_size;out(k).hit=any(strcmp(a.accepted_candidate_set,rows(k).truth_topology_id));out(k).empty=a.empty;out(k).method_id=method;out(k).calibration_hash=a.calibration_hash;out(k).experiment_hash=ids.experiment_hash;out(k).parameter_vector_hash=rows(k).parameter_vector_hash;out(k).noiseless_cfr_hash=rows(k).noiseless_cfr_hash;out(k).observation_hash=rows(k).observation_hash;out(k).case_seed=rows(k).case_seed;end,end
function [nearest,summary]=equivalence_audit(candidates,grid,sc,base)
    % Lightweight diagnostic only; the complete pair audit is performed by
    % stage4a7_2_r2_1_full_equivalence_audit in a separate output table.
    scope='first_9_templates_diagnostic_only';used=min(9,numel(grid));
    nearest=repmat(pair_row(),0,1);
    for a=1:numel(candidates)-1
        best=pair_row();best.candidate_a=getid(candidates(a));best.status='nearest_competitor';best.template_scope=scope;best.template_count_total=numel(grid);best.template_count_used=used;
        for b=a+1:numel(candidates)
            same=Inf;prof=Inf;
            for i=1:used
                h1=cfr(candidates(a),grid(i),sc,base);
                for j=1:used
                    h2=cfr(candidates(b),grid(j),sc,base);prof=min(prof,sqrt(mean(abs(h1-h2).^2)));
                end
                h2=cfr(candidates(b),grid(i),sc,base);same=min(same,sqrt(mean(abs(h1-h2).^2)));
            end
            if prof<best.profile_distance
                best.candidate_b=getid(candidates(b));best.profile_distance=prof;best.same_theta_distance=same;
            end
        end
        nearest(end+1)=best;
    end
    summary=struct('status','completed_nearest_competitors','candidate_pair_count',numel(nearest), ...
        'equivalent_pair_count',nnz([nearest.profile_distance]<=sc.profile.equivalence_tolerance), ...
        'numerical_tolerance',sc.profile.equivalence_tolerance,'measurement_resolution','not_calibrated', ...
        'template_scope',scope,'template_count_total',numel(grid),'template_count_used',used);
end
function h=cfr(c,t,sc,base),[net,local]=topology_apply_parameters(c.network,base,t);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,t,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);h=v{1}(:).';end
function [rows,corrupt,corruption_manifest]=coverage_audit(ref,sc,base)
    rows=repmat(coverage_row(),numel(sc.corruptions),1);corruption_manifest=repmat(corruption_manifest_row(),numel(sc.corruptions),1);truth_key=canonicalize_asset_graph(ref.node_ids,ref.edges,struct()).canonical_graph_key;
    for k=1:numel(sc.corruptions)
        [l,ledger_audit]=stage4a7_2_r2_1_build_benchmark_ledger(ref,sc,sc.corruptions{k},k);[sp,~]=stage4a7_2_r2_1_build_deployment_spec(l,sc);[c,~]=generate_engineering_topology_candidates(sp);
        [adapted,ok,~]=adapt_all(c,base);compatible=adapted(ok);compatible=stage4a7_2_r2_sort_candidates(compatible);
        rows(k).corruption=sc.corruptions{k};rows(k).engineering_candidate_count=numel(c);rows(k).forward_compatible_candidate_count=numel(compatible);rows(k).profile_scored_candidate_count=numel(compatible);
        rows(k).truth_in_engineering_space=any(strcmp({c.canonical_graph_key},truth_key));rows(k).truth_forward_compatible=false;rows(k).truth_in_profile_scored_library=false;rows(k).reference_rank_by_prior=NaN;rows(k).minimum_k_containing_truth=NaN;
        if rows(k).truth_in_engineering_space
            rows(k).truth_forward_compatible=any(strcmp({compatible.canonical_graph_key},truth_key));rows(k).truth_in_profile_scored_library=rows(k).truth_forward_compatible;
            if rows(k).truth_forward_compatible,rows(k).reference_rank_by_prior=find(strcmp({compatible.canonical_graph_key},truth_key),1);rows(k).minimum_k_containing_truth=rows(k).reference_rank_by_prior;end
        end
        rows(k).topk_coverage_loss=~rows(k).truth_in_profile_scored_library;
        rows(k).failure_reason=ternary(~rows(k).truth_in_engineering_space,'prior_exclusion_or_candidate_gap',ternary(~rows(k).truth_forward_compatible,'forward_model_incompatible',''));
        rows(k).status=ternary(rows(k).truth_in_profile_scored_library,'covered','coverage_loss');
        m=corruption_manifest_row();m.corruption_id=sc.corruptions{k};m.selected_edge_id=getf(ledger_audit,'selected_edge_id','');m.from_node=getf(ledger_audit,'selected_from_node','');m.to_node=getf(ledger_audit,'selected_to_node','');m.edge_status=getf(ledger_audit,'selected_edge_status','');m.edge_is_in_reference=getf(ledger_audit,'selected_edge_is_in_reference',false);m.expected_truth_coverage=expected_corruption_coverage(sc.corruptions{k});m.actual_truth_coverage=rows(k).truth_in_engineering_space;m.assertion_status=corruption_assertion_status(sc.corruptions{k},ledger_audit,c);m.failure_reason=rows(k).failure_reason;corruption_manifest(k)=m;
    end
    corrupt=rows;
end
function r=identity_rows(ids),n=fieldnames(ids);r=repmat(struct('identity','','value',''),numel(n),1);for k=1:numel(n),r(k).identity=n{k};r(k).value=ids.(n{k});end,end
function r=scenario_row(),r=struct('sample_id','','physical_scenario_id','','split','','truth_topology_id','','truth_theta',struct(),'case_seed',0,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','noise_snr_db',NaN);end
function r=decision_row(),r=struct('sample_id','','split','','truth_topology_id','','accepted_set','','set_size',0,'hit',false,'empty',false,'method_id','','calibration_hash','','experiment_hash','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','case_seed',0);end
function r=pair_row(),r=struct('candidate_a','','candidate_b','','same_theta_distance',Inf,'profile_distance',Inf,'status','','numerical_tolerance',NaN,'template_scope','','template_count_total',0,'template_count_used',0);end
function r=coverage_row(),r=struct('corruption','','engineering_candidate_count',0,'forward_compatible_candidate_count',0,'profile_scored_candidate_count',0,'truth_in_engineering_space',false,'truth_forward_compatible',false,'truth_in_profile_scored_library',false,'reference_rank_by_prior',NaN,'minimum_k_containing_truth',NaN,'topk_coverage_loss',false,'failure_reason','','status','');end
function r=corruption_manifest_row(),r=struct('corruption_id','','selected_edge_id','','from_node','','to_node','','edge_status','','edge_is_in_reference',false,'expected_truth_coverage','','actual_truth_coverage',false,'assertion_status','','failure_reason','');end
function x=expected_corruption_coverage(name)
    if strcmp(name,'incorrect_required_edge'),x='false_due_to_corrupted_required_prior';
    elseif strcmp(name,'missing_edge'),x='may_be_excluded_by_missing_edge';
    elseif strcmp(name,'mixed_corruption'),x='not_guaranteed_under_mixed_corruption';
    else,x='not_forced';end
end
function x=corruption_assertion_status(name,a,c)
    if strcmp(name,'incorrect_required_edge')
        false_required=~getf(a,'selected_edge_is_in_reference',true)&&strcmp(getf(a,'selected_edge_status',''),'required');
        all_include=~isempty(c)&&all(arrayfun(@(q)any(strcmp({q.edges.id},getf(a,'selected_edge_id',''))),c));
        x=ternary(false_required&&all_include,'passed','failed');
    else
        x='recorded';
    end
end
function r=scenario_manifest_rows(rows)
    r=repmat(struct('sample_id','','physical_scenario_id','','split','','truth_topology_id','','case_seed',0,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','noise_snr_db',NaN),numel(rows),1);
    for k=1:numel(rows),r(k).sample_id=rows(k).sample_id;r(k).physical_scenario_id=rows(k).physical_scenario_id;r(k).split=rows(k).split;r(k).truth_topology_id=rows(k).truth_topology_id;r(k).case_seed=rows(k).case_seed;r(k).parameter_vector_hash=rows(k).parameter_vector_hash;r(k).noiseless_cfr_hash=rows(k).noiseless_cfr_hash;r(k).observation_hash=rows(k).observation_hash;r(k).noise_snr_db=rows(k).noise_snr_db;end
end
function r=independence_rows(rows)
    r=repmat(struct('scope','','split_a','','split_b','','row_count',0,'unique_physical_scenario_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',0,'unique_observation_hash_count',0,'duplicate_physical_id_count',0,'duplicate_parameter_hash_count',0,'duplicate_cfr_hash_count',0,'duplicate_observation_hash_count',0,'cross_split_physical_id_duplicate_count',NaN,'cross_split_parameter_hash_duplicate_count',NaN,'cross_split_cfr_hash_duplicate_count',NaN,'cross_split_observation_hash_duplicate_count',NaN,'status',''),0,1);
    splits={'development','calibration','pilot'};
    for i=1:numel(splits)
        x=rows(strcmp({rows.split},splits{i}));r(end+1)=split_audit_row(x,splits{i},'');
    end
    for i=1:numel(splits)-1
        for j=i+1:numel(splits)
            a=rows(strcmp({rows.split},splits{i}));b=rows(strcmp({rows.split},splits{j}));q=split_audit_row([a b],splits{i},splits{j});
            q.scope='cross_split';q.cross_split_physical_id_duplicate_count=numel(intersect({a.physical_scenario_id},{b.physical_scenario_id}));q.cross_split_parameter_hash_duplicate_count=numel(intersect({a.parameter_vector_hash},{b.parameter_vector_hash}));q.cross_split_cfr_hash_duplicate_count=numel(intersect({a.noiseless_cfr_hash},{b.noiseless_cfr_hash}));q.cross_split_observation_hash_duplicate_count=numel(intersect({a.observation_hash},{b.observation_hash}));q.status=ternary(any([q.cross_split_physical_id_duplicate_count q.cross_split_parameter_hash_duplicate_count q.cross_split_cfr_hash_duplicate_count q.cross_split_observation_hash_duplicate_count]),'duplicate_detected','independent_in_materialized_splits');r(end+1)=q;
        end
    end
end
function r=split_audit_row(x,a,b)
    r=struct('scope',ternary(isempty(b),'split','cross_split'),'split_a',a,'split_b',b,'row_count',numel(x),'unique_physical_scenario_count',numel(unique({x.physical_scenario_id})),'unique_parameter_hash_count',numel(unique({x.parameter_vector_hash})),'unique_cfr_hash_count',numel(unique({x.noiseless_cfr_hash})),'unique_observation_hash_count',numel(unique({x.observation_hash})),'duplicate_physical_id_count',numel(x)-numel(unique({x.physical_scenario_id})),'duplicate_parameter_hash_count',numel(x)-numel(unique({x.parameter_vector_hash})),'duplicate_cfr_hash_count',numel(x)-numel(unique({x.noiseless_cfr_hash})),'duplicate_observation_hash_count',numel(x)-numel(unique({x.observation_hash})),'cross_split_physical_id_duplicate_count',NaN,'cross_split_parameter_hash_duplicate_count',NaN,'cross_split_cfr_hash_duplicate_count',NaN,'cross_split_observation_hash_duplicate_count',NaN,'status',ternary(numel(x)==numel(unique({x.sample_id})),'unique_ids','duplicate_ids'));
end
function r=calibration_rows(models,methods,ids)
    r=repmat(struct('method_id','','candidate_id','','sample_count',0,'minimum_attainable_p',NaN,'status','','parameter_calibration_hash','','experiment_hash',''),0,1);
    for q=1:numel(models)
        m=models{q};for k=1:numel(m.classes),z=struct('method_id',methods{q},'candidate_id',m.classes(k).candidate_id,'sample_count',m.classes(k).sample_count,'minimum_attainable_p',m.classes(k).minimum_attainable_p,'status',m.classes(k).status,'parameter_calibration_hash',m.calibration_hash,'experiment_hash',ids.experiment_hash);r(end+1)=z;end
    end
end
function r=configuration_row(sc,ids,selected,model,manifest,status)
    r=struct('stage_name',sc.stage_name,'mode',sc.mode,'status',status,'selected_method',selected,'scientifically_unique_winner',getf(manifest,'scientifically_unique_winner',false),'source_tree_hash',ids.source_tree_hash,'data_provenance_hash',ids.data_provenance_hash,'candidate_library_hash',ids.candidate_library_hash,'configuration_hash',ids.configuration_hash,'template_cache_hash',ids.template_cache_hash,'experiment_hash',ids.experiment_hash,'runtime_environment_hash',ids.runtime_environment_hash,'parameter_calibration_hash',model.calibration_hash,'parameter_calibration_sample_count',sum([model.classes.sample_count]),'parameter_calibration_status',model.status,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);
end
function x=run_status_if(mode),x=ternary(strcmp(mode,'smoke'),'smoke_completed','formal_completed');end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function write_rows(p,x),if istable(x),writetable(x,p);elseif isstruct(x),writetable(struct2table(x),p);else,fid=fopen(p,'w');fprintf(fid,'empty\n');fclose(fid);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function ix=truth_indices(rows,ids),ix=zeros(numel(rows),1);for k=1:numel(rows),ix(k)=find(strcmp(ids,rows(k).truth_topology_id),1);end,end
function checkpoint(path,data)
    tmp=[path '.tmp'];save(tmp,'-struct','data','-v7');movefile(tmp,path,'f');
end
