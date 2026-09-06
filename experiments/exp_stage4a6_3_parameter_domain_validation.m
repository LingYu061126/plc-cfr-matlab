function out = exp_stage4a6_3_parameter_domain_validation(root, mode)
%EXP_STAGE4A6_3_PARAMETER_DOMAIN_VALIDATION A-grid pilot/calibration/final.
%   The pilot is intentionally the first executable mode.  It creates a
%   separate run directory whose name includes the scientific hash, so a
%   later incompatible run cannot overwrite prior shards.
    if nargin < 1 || isempty(root), root=fileparts(fileparts(mfilename('fullpath'))); end
    if nargin < 2 || isempty(mode), mode='pilot'; end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root); sc=stage4a6_3_parameter_domain_config(cfg,mode);
    candidates=generate_radial_topology_candidates(sc.generator);
    domain=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    source_hash=stage4a6_3_source_tree_hash(root);
    payload=scientific_payload(sc,domain,candidates,source_hash);
    [science_hash,canonical]=stage4a4_scientific_config_hash(payload);
    bank_mode=mode;
    if strcmp(mode,'audit'), bank_mode='all'; end
    bank=generate_stage4a6_3_trial_bank(sc,bank_mode,candidates);
    audit=audit_stage4a6_3_trial_bank(bank,candidates,sc);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);
    write_rows(bank_rows(bank),fullfile(sc.results_data,[sc.output_prefix '_trial_bank.csv']));
    write_rows(audit,fullfile(sc.results_data,[sc.output_prefix '_trial_bank_audit.csv']));
    write_rows(struct('stage',sc.stage_name,'version',sc.version,'mode',mode, ...
        'grid_id',sc.grid_id,'frequency_count',numel(sc.grids(1).frequency_hz), ...
        'scientific_hash',science_hash,'source_tree_hash',source_hash, ...
        'canonical_configuration_text',canonical), ...
        fullfile(sc.results_data,[sc.output_prefix '_configuration_manifest.csv']));
    if strcmp(mode,'audit')
        out=struct('mode',mode,'bank',bank,'audit',audit,'scientific_hash',science_hash,'source_tree_hash',source_hash);return;
    end
    grid=sc.grids(1); f=grid.frequency_hz(:).';
    nominal_views=build_nominal_views(candidates,cfg,f);
    run_id=[lower(mode) '_' science_hash(1:16)];
    opts=sc.optimization;opts.profile=sc.profile;opts.minimum_sensitivity_floor=sc.identifiability.minimum_sensitivity_floor;
    [manifest,contexts,tds,summary,runtime,shard_rows]=execute_cases(root,sc,bank,candidates,cfg,domain,science_hash,source_hash,run_id,f,nominal_views,opts);
    write_rows(shard_rows,fullfile(sc.results_data,[sc.output_prefix '_shard_manifest.csv']));
    write_rows(runtime,fullfile(sc.results_data,[sc.output_prefix '_runtime_summary.csv']));
    if strcmp(mode,'calibration')
        evidence=load_completed_evidence(manifest,root);
        eligible=calibration_evidence_only(evidence,manifest,bank,tds);
        model=calibrate_stage4a6_2_parameter_thresholds(eligible,sc,sc.extended_domain_eta,science_hash);
        write_rows(threshold_rows(model,science_hash,source_hash),fullfile(sc.results_data,[sc.output_prefix '_thresholds.csv']));
        save(fullfile(sc.results_data,'stage4a6_3_calibration_model.mat'),'model','sc','science_hash','source_hash','eligible','-v7.3');
        save(fullfile(sc.results_data,[sc.output_prefix '_results.mat']),'sc','bank','audit','manifest','summary','runtime','model','science_hash','source_hash','-v7.3');
        out=struct('mode',mode,'bank',bank,'audit',audit,'summary',summary,'runtime',runtime,'model',model, ...
            'eligible_calibration_count',numel(eligible),'scientific_hash',science_hash,'source_tree_hash',source_hash,'run_id',run_id);return;
    end
    if strcmp(mode,'final')
        if any(~strcmp({shard_rows.final_status},'completed'))
            save(fullfile(sc.results_data,[sc.output_prefix '_partial_results.mat']),'sc','bank','audit','manifest','summary','runtime','shard_rows','science_hash','source_hash','-v7.3');
            out=struct('mode',mode,'bank',bank,'audit',audit,'summary',summary,'runtime',runtime,'shard_rows',shard_rows, ...
                'status','pending_shards','scientific_hash',science_hash,'source_tree_hash',source_hash,'run_id',run_id);return;
        end
        model_path=fullfile(sc.results_data,'stage4a6_3_calibration_model.mat');
        if ~exist(model_path,'file'),error('stage4a6_3:MissingCalibration','Calibration model is missing; final is locked.');end
        z=load(model_path,'model');model=z.model;
        [decisions,labels]=score_final_shards(manifest,root,bank,tds,model,sc);
        metrics=evaluate_stage4a6_3_metrics(decisions,labels);
        write_rows(decisions,fullfile(sc.results_data,[sc.output_prefix '_decisions.csv']));
        write_rows(labels,fullfile(sc.results_data,[sc.output_prefix '_scoring_labels.csv']));
        write_rows(metrics,fullfile(sc.results_data,[sc.output_prefix '_metrics.csv']));
        save(fullfile(sc.results_data,[sc.output_prefix '_results.mat']),'sc','bank','audit','manifest','summary','runtime','model','decisions','labels','metrics','science_hash','source_hash','-v7.3');
        out=struct('mode',mode,'bank',bank,'audit',audit,'summary',summary,'runtime',runtime,'model',model, ...
            'decisions',decisions,'labels',labels,'metrics',metrics,'scientific_hash',science_hash,'source_tree_hash',source_hash,'run_id',run_id);return;
    end
    save(fullfile(sc.results_data,[sc.output_prefix '_results.mat']),'sc','bank','audit','manifest','summary','runtime','science_hash','source_hash','-v7.3');
    logpath=fullfile(sc.results_logs,[sc.output_prefix '_pilot.log']);
    write_text(logpath,sprintf('Stage 4A.6.3 pilot\nmode=%s\nMATLAB=%s\nscientific_hash=%s\nsource_tree_hash=%s\ncases=%d attempted=%d completed=%d failed=%d resumed=%d runtime_s=%.6f\n',mode,version,science_hash,source_hash,numel(bank),summary.attempted,summary.completed,summary.failed,summary.resumed,runtime.total_compute_runtime_s));
    out=struct('mode',mode,'bank',bank,'audit',audit,'summary',summary,'runtime',runtime, ...
        'scientific_hash',science_hash,'source_tree_hash',source_hash,'run_id',run_id);
end

function p=scientific_payload(sc,d,c,source_hash)
    p=struct('stage',sc.stage_name,'version',sc.version,'grid_id',sc.grid_id, ...
        'frequency_hz',sc.grids(1).frequency_hz,'generator',sc.generator, ...
        'parameter_search',sc.parameter_search,'extended_domain_eta',sc.extended_domain_eta, ...
        'profile',sc.profile,'optimization',sc.optimization,'trial_design',sc.trial_design, ...
        'seeds',sc.seeds,'topology_ids',{c.topology_id},'canonical_keys',{c.canonical_key}, ...
        'domain',d,'source_tree_hash',source_hash,'source_tag',sc.source_tag);
end
function [v,details]=make_observation(b,cfg,f)
    [n,lc]=topology_apply_parameters(b.truth_network,cfg,b.truth_theta);
    [m,~]=plc_measurement_bundle('siso_forward',n,b.truth_theta,lc);
    [v,details]=plc_multiview_response(f,n,m,lc);
end
function views=build_nominal_views(candidates,cfg,f)
    views=cell(numel(candidates),1);t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',50,'receiver_impedance_ohm',50,'regularization',NaN);
    for k=1:numel(candidates)
        [n,lc]=topology_apply_parameters(candidates(k).network,cfg,t);[m,~]=plc_measurement_bundle('siso_forward',n,t,lc);[views{k},~]=plc_multiview_response(f,n,m,lc);
    end
end
function td=match_nominal(obs,views,candidates,tie)
    d=Inf(1,numel(candidates));for k=1:numel(candidates),d(k)=view_distance(obs,views{k});end
    best=min(d);idx=find(d<=best+tie);ids={candidates(idx).topology_id};
    if numel(ids)>1,dec='equivalence_class';else,dec='unique_topology';end
    td=struct('decision',dec,'best_topology_id',ids{1},'accepted_topology_set',strjoin(ids,','), ...
        'best_distance',best,'candidate_distances',d);
end
function d=view_distance(a,b),e=0;n=0;for k=1:numel(a),z=a{k}(:)-b{k}(:);e=e+sum(abs(z).^2);n=n+numel(z);end;d=sqrt(e/max(n,1));end
function [manifest,contexts,tds,summary,runtime,shard_rows]=execute_cases(root,sc,bank,candidates,cfg,domain,science_hash,source_hash,run_id,f,nominal_views,opts)
    contexts=cell(numel(bank),1);tds=repmat(struct('decision','','best_topology_id','','accepted_topology_set','','best_distance',NaN,'candidate_distances',[]),numel(bank),1);
    manifest=repmat(case_template(),numel(bank),1);relroot=fullfile('results','data','stage4a6_3','runs',run_id);
    for k=1:numel(bank)
        [obs,~]=make_observation(bank(k),cfg,f);td=match_nominal(obs,nominal_views,candidates,sc.distance.tie_tolerance);tds(k)=td;
        best_idx=find(strcmp({candidates.topology_id},td.best_topology_id),1);
        contexts{k}=struct('root_dir',root,'scientific_hash',science_hash,'source_tree_hash',source_hash, ...
            'observed_views',{obs},'frequency_hz',f,'candidate',candidates(best_idx),'cfg',cfg, ...
            'domain',domain,'initial_thetas',[],'options',opts,'topology_decision',td);
        manifest(k)=make_case_manifest(bank(k),fullfile(relroot,'shards',[bank(k).sample_id '.mat']));
    end
    pending_idx=pending_case_indices(manifest,root,science_hash,source_hash,sc.execution.batch_size);
    run_manifest=manifest(pending_idx);run_contexts=contexts(pending_idx);
    t0=tic;summary=run_stage4a6_2_batch(run_manifest,struct('root_dir',root,'scientific_hash',science_hash,'source_tree_hash',source_hash,'case_contexts',{run_contexts}),sc.execution);elapsed=toc(t0);
    previous=read_previous_runtime(fullfile(sc.results_data,[sc.output_prefix '_runtime_summary.csv']),run_id);
    if summary.attempted>0 || isempty(previous),initial_runtime=elapsed;resume_runtime=0;total_runtime=elapsed;else,initial_runtime=previous.initial_compute_runtime_s;resume_runtime=elapsed;total_runtime=previous.total_compute_runtime_s+elapsed;end
    runtime=struct('run_id',run_id,'mode',sc.mode,'initial_compute_runtime_s',initial_runtime,'resume_check_runtime_s',resume_runtime,'total_compute_runtime_s',total_runtime,'case_count',numel(bank),'attempted',summary.attempted,'completed',summary.completed,'resumed',summary.resumed,'failed',summary.failed,'pending',summary.pending,'retry_count',summary.retry_count,'hash_mismatch',summary.hash_mismatch,'solver',solver_name(sc),'workers',sc.execution.num_workers,'scientific_hash',science_hash,'source_tree_hash',source_hash);
    shard_rows=reconcile_shards(manifest,summary,root,science_hash,source_hash);
end
function evidence=load_completed_evidence(manifest,root)
    evidence=repmat(struct('case_index',0,'profile_summary',struct()),0,1);
    for k=1:numel(manifest)
        p=fullfile(root,manifest(k).expected_output_path);if ~exist(p,'file'),continue;end
        z=load(p,'shard');if strcmp(z.shard.status,'completed')&&~isempty(z.shard.profile_summary),evidence(end+1)=struct('case_index',k,'profile_summary',z.shard.profile_summary);end %#ok<AGROW>
    end
end
function idx=pending_case_indices(manifest,root,h,sh,batch_size)
    pending=[];for k=1:numel(manifest),p=fullfile(root,manifest(k).expected_output_path);done=false;if exist(p,'file'),try,z=load(p,'shard');expected=struct('case_id',manifest(k).case_id,'scientific_hash',h,'source_tree_hash',sh,'parameter_name',manifest(k).parameter_name);[ok,~]=validate_stage4a6_2_shard(z.shard,expected,'allow_failed',true);done=ok&&strcmp(z.shard.status,'completed');catch,end,end;if ~done,pending(end+1)=k;end,end %#ok<AGROW>
    if nargin<5||isempty(batch_size)||batch_size<=0,idx=pending;else,idx=pending(1:min(batch_size,numel(pending)));end
end
function eligible=calibration_evidence_only(evidence,manifest,bank,tds)
    if isempty(evidence),eligible=struct([]);return;end
    eligible=repmat(evidence(1).profile_summary,0,1);
    for q=1:numel(evidence)
        k=evidence(q).case_index;
        if ~strcmp(bank(k).parameter_domain_truth,'in_domain'),continue;end
        ids=strsplit(tds(k).accepted_topology_set,',');if ~any(strcmp(ids,bank(k).truth_topology_id)),continue;end
        eligible(end+1)=evidence(q).profile_summary; %#ok<AGROW>
    end
end
function rows=threshold_rows(model,h,sh)
    if isempty(model.parameter_thresholds),rows=struct('parameter_name','','reliable_sample_count',0,'status',model.calibration_status,'absolute_improvement_threshold',NaN,'relative_improvement_threshold',NaN,'sensitivity_floor',NaN,'total_calibration_evidence_count',model.total_calibration_evidence_count,'reliable_calibration_evidence_count',model.reliable_calibration_evidence_count,'experiment_scientific_hash',h,'source_tree_hash',sh);return;end
    rows=repmat(struct('parameter_name','','reliable_sample_count',0,'status','','absolute_improvement_threshold',NaN,'relative_improvement_threshold',NaN,'sensitivity_floor',NaN,'total_calibration_evidence_count',0,'reliable_calibration_evidence_count',0,'experiment_scientific_hash','','source_tree_hash',''),numel(model.parameter_thresholds),1);
    for k=1:numel(rows),rows(k).parameter_name=model.parameter_thresholds(k).parameter_name;rows(k).reliable_sample_count=model.parameter_thresholds(k).reliable_sample_count;rows(k).status=model.parameter_thresholds(k).status;rows(k).absolute_improvement_threshold=model.parameter_thresholds(k).absolute_improvement_threshold;rows(k).relative_improvement_threshold=model.parameter_thresholds(k).relative_improvement_threshold;rows(k).sensitivity_floor=model.parameter_thresholds(k).sensitivity_floor;rows(k).total_calibration_evidence_count=model.total_calibration_evidence_count;rows(k).reliable_calibration_evidence_count=model.reliable_calibration_evidence_count;rows(k).experiment_scientific_hash=h;rows(k).source_tree_hash=sh;end
end
function [decisions,labels]=score_final_shards(manifest,root,bank,tds,model,sc)
    decisions=repmat(decision_row_template(),0,1);labels=repmat(label_row_template(),0,1);
    for k=1:numel(manifest)
        p=fullfile(root,manifest(k).expected_output_path);if ~exist(p,'file'),continue;end;z=load(p,'shard');if ~strcmp(z.shard.status,'completed'),continue;end
        for m=1:numel(sc.diagnostic_methods)
            j=apply_stage4a6_2_parameter_decision(tds(k),z.shard.profile_summary,model,sc.diagnostic_methods{m});r=decision_row_template();r.sample_id=bank(k).sample_id;r.method_id=sc.diagnostic_methods{m};r.topology_status=j.topology_status;r.topology_set=j.topology_set;r.parameter_domain_status=j.parameter_domain_status;r.profile_reliable=j.profile_reliable;r.member_count=j.member_count;r.truth_free_best_distance=tds(k).best_distance;r.scientific_hash=model.calibration_hash;decisions(end+1)=r; %#ok<AGROW>
        end
        l=label_row_template();l.sample_id=bank(k).sample_id;l.category=bank(k).category;l.outlier_dimension=bank(k).outlier_dimension;l.outlier_severity=bank(k).outlier_severity;l.outlier_direction=bank(k).outlier_direction;l.truth_topology_id=bank(k).truth_topology_id;l.truth_parameter_domain=bank(k).parameter_domain_truth;labels(end+1)=l; %#ok<AGROW>
    end
end
function r=decision_row_template(),r=struct('sample_id','','method_id','','topology_status','','topology_set','','parameter_domain_status','','profile_reliable',false,'member_count',0,'truth_free_best_distance',NaN,'scientific_hash','');end
function r=label_row_template(),r=struct('sample_id','','category','','outlier_dimension','','outlier_severity','','outlier_direction','','truth_topology_id','','truth_parameter_domain','');end
function r=case_template(),r=struct('case_id','','expected_output_path','','parameter_name','','case_seed',0,'attempt_count',0,'retry_count',0);end
function r=make_case_manifest(b,path),r=case_template();r.case_id=b.sample_id;r.expected_output_path=path;r.parameter_name='all_active';r.case_seed=b.seed;end
function r=reconcile_shards(m,s,root,h,sh)
    r=repmat(struct('case_id','','expected_output_path','','attempt_count',0,'retry_count',0,'final_status','','runtime_s',NaN,'error_identifier','','error_message','','checksum_valid',false,'scientific_hash','','source_tree_hash',''),numel(m),1);
    for k=1:numel(m)
        r(k).case_id=m(k).case_id;r(k).expected_output_path=m(k).expected_output_path;
        p=fullfile(root,m(k).expected_output_path);if exist(p,'file')
            x=load(p,'shard');z=x.shard;r(k).attempt_count=z.attempt_count;r(k).retry_count=getfield_default(z,'retry_count',max(z.attempt_count-1,0));r(k).final_status=z.status;r(k).runtime_s=z.runtime_s;r(k).error_identifier=z.error_identifier;r(k).error_message=z.error_message;r(k).scientific_hash=z.scientific_hash;r(k).source_tree_hash=z.source_tree_hash;r(k).checksum_valid=true;
        else,r(k).final_status='pending';r(k).scientific_hash=h;r(k).source_tree_hash=sh;end
    end
end
function s=solver_name(sc),if isfield(sc.optimization,'solver'),s=char(sc.optimization.solver);else,s='auto';end,end
function rows=bank_rows(b)
    rows=repmat(struct('sample_id','','split','','replicate_id','','seed',0,'truth_topology_id','','canonical_key','','active_parameter_names','','active_parameter_count',0,'has_branch',false,'category','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_domain_truth','','grid_id','','frequency_count',0,'source_tag',''),numel(b),1);
    for k=1:numel(b),f=fieldnames(rows);for j=1:numel(f),if isfield(b(k),f{j}),rows(k).(f{j})=b(k).(f{j});end,end,end
end
function write_rows(x,p),ensure_dir(fileparts(p));if ~isempty(x),writetable(struct2table(x(:)),p);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_text(p,t),ensure_dir(fileparts(p));fid=fopen(p,'w');fprintf(fid,'%s',t);fclose(fid);end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
function r=read_previous_runtime(p,run_id)
    r=[];if ~exist(p,'file'),return;end
    try
        t=readtable(p,'TextType','string');j=find(string(t.run_id)==string(run_id),1);
        if ~isempty(j),r=table2struct(t(j,:));end
    catch
        r=[];
    end
end
