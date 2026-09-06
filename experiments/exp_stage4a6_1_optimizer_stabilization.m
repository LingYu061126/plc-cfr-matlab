function out = exp_stage4a6_1_optimizer_stabilization(cfg,sc)
%EXP_STAGE4A6_1_OPTIMIZER_STABILIZATION Stable profile/domain audit.
%   Historical Stage 4A.6 files are read only; all outputs use stage4a6_1.

    ensure_stage_dirs(sc); started=tic; root=cfg.root_dir;
    source_hash=stage4a6_1_source_tree_hash(root);
    bank=generate_stage4a6_1_trial_bank(sc,'all');
    base=generate_radial_topology_candidates(sc.generator);
    theta_grid=topology_parameter_grid(sc.parameter_search);
    [hash,canonical]=stage4a4_scientific_config_hash(struct( ...
        'stage',sc.stage_name,'version',sc.version,'source_tree_hash',source_hash, ...
        'generator',sc.generator,'parameter_search',sc.parameter_search,'grids',sc.grids, ...
        'seeds',struct('development',sc.development_seeds,'final',sc.final_seeds), ...
        'sample_design',sc.sample_design,'etas',sc.extended_domain_eta_candidates, ...
        'optimization',sc.optimization,'profile',sc.profile, ...
        'calibration',sc.parameter_calibration,'parallel',sc.parallel));
    decisions=struct([]); labels=struct([]); profiles=struct([]); identrows=struct([]);
    selections=struct([]); thresholds=struct([]); runtimes=struct([]);
    for gi=1:numel(sc.grids)
        grid=sc.grids(gi); fprintf('Stage 4A.6.1 grid %s (%d points)\n',grid.id,numel(grid.frequency_hz));
        obs=make_observations(bank,grid.frequency_hz,cfg,sc.measurement_kind);
        [cache,audit]=load_a5_cache(cfg,grid,base,theta_grid,hash);
        [sub8,~]=stage4a5_make_subbands(grid.frequency_hz,8,grid.id,hash);
        a5=stage4a5_1_integrity_config(cfg,'formal');
        if isfield(sc,'sample_design') && sc.sample_design.calibration_per_graph < 2
            a5.calibration.minimum_samples=1;
        end
        [mask_design,mask_manifest]=build_frozen_resampling_masks(grid,unique({bank.replicate_id},'stable'),a5,hash); %#ok<ASGLU>
        spec=m3_spec(sc,grid.id); raw=cell(numel(bank),1);
        for i=1:numel(bank)
            md=mask_design(strcmp({mask_design.replicate_id},bank(i).replicate_id));
            raw{i}=score_stage4a5_1_observation(obs{i},cache,sub8,md.masks,struct('candidate_count_before_prior',7));
            raw{i}.sample_id=bank(i).sample_id; raw{i}.replicate_id=bank(i).replicate_id;
        end
        if ~isempty(sc.development_seeds)
            eta_rows=struct([]);
            for eta=sc.extended_domain_eta_candidates
                domain=build_extended_parameter_domain(sc.parameter_search,eta);
                for ri=1:numel(sc.development_seeds)
                    rep=sprintf('dev%02d',ri); cal=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'stage4a6_calibration')); val=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'stage4a6_validation'));
                    tm=calibrate_stage4a5_confirmation([raw{cal}],a5,grid.id,hash,sc.development_seeds(ri)); td=apply_topology(raw,tm,spec,grid.id);
                    ev_cal=run_stage4a6_1_member_batch(cal,td,obs,raw,cache,base,grid,cfg,domain,sc);
                    ev_cal=compact_evidence_cells(ev_cal);
                    ev_val=run_stage4a6_1_member_batch(val,td,obs,raw,cache,base,grid,cfg,domain,sc);
                    ev_val=compact_evidence_cells(ev_val);
                    pm=calibrate_stage4a6_1_parameter_domain(flatten_evidence(ev_cal),sc,eta,hash);
                    for q=1:numel(val)
                        j=apply_stage4a6_1_parameter_decision(td(val(q)),ev_val{q},pm,'A6_1_M3_joint_diagnostic');
                        z=struct('eta',eta,'grid_id',grid.id,'parameter_domain_truth',bank(val(q)).parameter_domain_truth,'parameter_status',j.parameter_domain_status); eta_rows=append(eta_rows,z);
                    end
                end
            end
            selected_eta=select_stage4a6_eta(eta_rows,sc.extended_domain_eta_candidates,0.10); source='development validation only';
        else
            selected_eta=0.5; source='frozen from separate development run';
        end
        selections=append(selections,struct('grid_id',grid.id,'selected_eta',selected_eta,'selection_source',source,'experiment_scientific_hash',hash));
        fprintf('  frozen eta = %.3g\n',selected_eta); domain=build_extended_parameter_domain(sc.parameter_search,selected_eta);
        if strcmp(sc.mode,'development'), continue; end
        for ri=1:numel(sc.final_seeds)
            rep=sprintf('final%02d',ri); cal=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'stage4a6_final_calibration')); test=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'stage4a6_final_test'));
            tm=calibrate_stage4a5_confirmation([raw{cal}],a5,grid.id,hash,sc.final_seeds(ri)); td=apply_topology(raw,tm,spec,grid.id);
            ev_cal=run_stage4a6_1_member_batch(cal,td,obs,raw,cache,base,grid,cfg,domain,sc);
            ev_cal=compact_evidence_cells(ev_cal);
            ev_test=run_stage4a6_1_member_batch(test,td,obs,raw,cache,base,grid,cfg,domain,sc);
            ev_test=compact_evidence_cells(ev_test);
            pm=calibrate_stage4a6_1_parameter_domain(flatten_evidence(ev_cal),sc,selected_eta,hash);
            thresholds=append(thresholds,threshold_row(grid.id,rep,pm,hash));
            for q=1:numel(test)
                ti=test(q); member=ev_test{q};
                for mi=1:numel(sc.diagnostic_methods)
                    j=apply_stage4a6_1_parameter_decision(td(ti),member,pm,sc.diagnostic_methods{mi});
                    j.sample_id=bank(ti).sample_id;j.replicate_id=rep;j.grid_id=grid.id;j.optimization_converged=all([member.optimizer_converged]);j.profile_reliable=all([member.profile_reliable]);j.experiment_scientific_hash=hash;
                    decisions=append(decisions,j); labels=append(labels,label_row(bank(ti),audit,base,grid.id,hash));
                end
                for k=1:numel(member)
                    profiles=append(profiles,profile_row(bank(ti),grid.id,rep,selected_eta,member(k),hash));
                    identrows=append(identrows,ident_row(bank(ti),grid.id,rep,member(k),hash));
                end
            end
        end
        runtimes=append(runtimes,struct('grid_id',grid.id,'sample_count',numel(bank),'candidate_count',numel(base),'parameter_template_count',numel(theta_grid),'elapsed_s',toc(started),'solver',solver_name(),'use_parallel',sc.parallel.use_parallel,'num_workers',sc.parallel.num_workers,'experiment_scientific_hash',hash));
        clear obs raw cache
    end
    metrics=evaluate_stage4a6_1_metrics(decisions,labels);
    write_outputs(sc,bank,decisions,labels,profiles,selections,thresholds,identrows,runtimes,metrics,hash,source_hash,canonical);
    out=struct('runtime_s',toc(started),'metrics',metrics,'selection',selections,'experiment_scientific_hash',hash,'source_tree_hash',source_hash);
end

function obs=make_observations(bank,f,cfg,kind)
    obs=cell(numel(bank),1);for k=1:numel(bank),[n,lc]=topology_apply_parameters(bank(k).truth_network,cfg,bank(k).truth_theta);[m,~]=plc_measurement_bundle(kind,n,bank(k).truth_theta,lc);[obs{k},~]=plc_multiview_response(f,n,m,lc);end
end
function [cache,audit]=load_a5_cache(cfg,grid,base,theta,hash)
    a5=stage4a5_1_integrity_config(cfg,'formal');source=stage4a5_1_source_tree_hash(cfg.root_dir);[expected,~]=stage4a5_1_cache_expected(grid,base,theta,cfg,a5,source);path=fullfile(a5.cache_dir,sprintf('stage4a5_1_%s_P0_no_prior.mat',grid.id));if ~exist(path,'file'),error('stage4a6_1:MissingCache','Stage 4A.5.1 cache is missing.');end;z=load(path,'cache');[ok,reason]=validate_candidate_cache_identity(z.cache,expected);if ~ok,error('stage4a6_1:InvalidCache','Cache identity mismatch: %s',reason);end;cache=z.cache;audit=cache.current_equivalence_audit;cache.experiment_scientific_hash=hash;
end
function s=m3_spec(sc,id),specs=stage4a5_method_specs(sc);names=sc.frozen_methods.(id);s=specs(strcmp({specs.method_id},names{4}));end
function td=apply_topology(raw,model,spec,grid),if isempty(raw),td=struct([]);return;end;z=apply_stage4a5_confirmation(raw{1},model,spec);z.grid_id=grid;z.scenario_id='P0_no_prior';td=repmat(z,numel(raw),1);for i=2:numel(raw),z=apply_stage4a5_confirmation(raw{i},model,spec);z.grid_id=grid;z.scenario_id='P0_no_prior';td(i)=z;end,end
function r=label_row(b,audit,base,grid,h),[cl,n]=class_for_key(audit,base,b.canonical_key);r=struct('sample_id',b.sample_id,'replicate_id',b.replicate_id,'split',b.split,'grid_id',grid,'category',b.category,'outlier_dimension',b.outlier_dimension,'outlier_severity',b.outlier_severity,'parameter_domain_truth',b.parameter_domain_truth,'truth_topology_id',b.truth_topology_id,'canonical_key',b.canonical_key,'truth_is_nonunique',n>1,'truth_equivalence_class',cl,'experiment_scientific_hash',h);end
function [lab,n]=class_for_key(a,b,key),lab='';n=0;g=find(strcmp({b.canonical_key},key),1);for k=1:numel(a.equivalence_classes),if any(a.equivalence_classes{k}.member_indices==g),lab=a.equivalence_classes{k}.label;n=numel(a.equivalence_classes{k}.member_indices);return;end,end,end
function r=profile_row(b,grid,rep,eta,e,h),r=struct('sample_id',b.sample_id,'replicate_id',rep,'grid_id',grid,'topology_id',e.topology_id,'category',b.category,'outlier_dimension',b.outlier_dimension,'outlier_severity',b.outlier_severity,'eta',eta,'active_parameter_names',strjoin(e.active_parameter_names,','),'active_parameter_count',e.active_parameter_count,'in_distance',e.in_distance,'ext_distance',e.ext_distance,'lambda',e.lambda,'relative_improvement',e.relative_improvement,'profile_lambda',e.profile_lambda,'profile_relative_improvement',e.profile_relative_improvement,'extended_outside',e.extended_outside,'profile_outside',e.profile_outside,'boundary_hit',e.boundary_hit,'outward_decrease',e.outward_decrease,'minimum_boundary_distance',e.minimum_boundary_distance,'minimum_sensitivity',e.minimum_sensitivity,'condition_number',e.condition_number,'effective_rank',e.effective_rank,'optimizer_converged',e.optimizer_converged,'multistart_consistent',e.multistart_consistent,'residual_finite',e.residual_finite,'active_parameters_identifiable',e.active_parameters_identifiable,'profile_reliable',e.profile_reliable,'experiment_scientific_hash',h);end
function r=ident_row(b,grid,rep,e,h),r=struct('sample_id',b.sample_id,'replicate_id',rep,'grid_id',grid,'topology_id',e.topology_id,'active_parameter_names',strjoin(e.active_parameter_names,','),'sensitivity_norms',mat2str(e.sensitivity_norms,8),'singular_values',mat2str(e.singular_values,8),'condition_number',e.condition_number,'effective_rank',e.effective_rank,'active_parameters_identifiable',e.active_parameters_identifiable,'experiment_scientific_hash',h);end
function r=threshold_row(grid,rep,m,h),r=struct('grid_id',grid,'replicate_id',rep,'eta',m.eta,'lambda_threshold',m.lambda_threshold,'relative_improvement_threshold',m.relative_improvement_threshold,'sensitivity_floor',m.sensitivity_floor,'calibration_sample_count',m.calibration_sample_count,'total_calibration_sample_count',m.total_calibration_sample_count,'profile_reliable_rate',m.profile_reliable_rate,'calibration_status',m.calibration_status,'calibration_hash',m.calibration_hash,'experiment_scientific_hash',h);end
function s=solver_name(),if exist('lsqnonlin','file')==2,s='lsqnonlin';else,s='fminsearch_logistic_bounded';end,end
function write_outputs(sc,b,d,l,p,s,t,i,r,m,h,sh,canon)
    data=sc.results_data;ensure_dir(data);write(bank_rows(b),fullfile(data,[sc.output_prefix '_trial_bank.csv']));write(d,fullfile(data,[sc.output_prefix '_joint_decisions.csv']));write(l,fullfile(data,[sc.output_prefix '_scoring_labels.csv']));write(p,fullfile(data,[sc.output_prefix '_parameter_profiles.csv']));write(s,fullfile(data,[sc.output_prefix '_method_selection.csv']));write(t,fullfile(data,[sc.output_prefix '_thresholds.csv']));write(i,fullfile(data,[sc.output_prefix '_identifiability.csv']));write(r,fullfile(data,[sc.output_prefix '_runtime.csv']));write(m,fullfile(data,[sc.output_prefix '_metrics.csv']));manifest=struct('experiment_scientific_hash',h,'source_tree_hash',sh,'solver',solver_name(),'canonical_configuration_text',canon,'runtime_environment_hash',stage4a4_scientific_config_hash(struct('matlab',version,'computer',computer)));write(manifest,fullfile(data,[sc.output_prefix '_configuration_manifest.csv']));save(fullfile(data,[sc.output_prefix '_results.mat']),'sc','b','d','l','p','s','t','i','r','m','manifest','-v7.3');
end
function x=bank_rows(b),x=repmat(struct('sample_id','','replicate_id','','split','','category','','truth_topology_id','','canonical_key','','outlier_dimension','','outlier_severity','','parameter_domain_truth','','seed',0),numel(b),1);for k=1:numel(b),x(k)=rmfield(b(k),{'truth_network','truth_theta'});end,end
function write(s,p),if ~isempty(s),writetable(struct2table(s(:)),p);end,end
function ensure_stage_dirs(sc),ensure_dir(sc.results_data);ensure_dir(sc.results_figures);ensure_dir(sc.results_logs);end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function y=append(x,z),if isempty(z),y=x;elseif isempty(x),y=z(:);else,y=[x(:);z(:)];end,end
function out=flatten_evidence(cells)
    out=struct([]);for k=1:numel(cells),if ~isempty(cells{k}),out=append(out,cells{k});end,end
end
function out=compact_evidence_cells(cells)
%COMPACT_EVIDENCE_CELLS Drop large nested solver traces after summarization.
%   Decision and calibration fields are retained; this only controls memory
%   lifetime and does not change the fitted values or reliability flags.
    out=cells;
    drop={'in_optimization','ext_optimization','profile_summary'};
    for k=1:numel(out)
        if isempty(out{k}),continue;end
        names=intersect(drop,fieldnames(out{k}));
        if ~isempty(names),out{k}=rmfield(out{k},names);end
    end
end
