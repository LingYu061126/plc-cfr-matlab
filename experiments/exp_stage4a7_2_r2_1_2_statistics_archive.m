function summary=exp_stage4a7_2_r2_1_2_statistics_archive(root,output_override,source_override)
%EXP_STAGE4A7_2_R2_1_2_STATISTICS_ARCHIVE Reanalyse v3 with cluster CI.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));base=default_config(root);out=fullfile(root,'results','data','stage4a7_2_r2_1_2');if nargin>=2&&~isempty(output_override),out=output_override;end;ensure_dir(out);t0=tic;
    source_root=fullfile(root,'results','data','stage4a7_2_r2_1_1','final_source_v3');
    if nargin>=3&&~isempty(source_override),source_root=source_override;end
    formal=fullfile(source_root,'formal');paired=fullfile(source_root,'paired');
    must={fullfile(formal,'checkpoint_development.mat'),fullfile(formal,'checkpoint_calibration.mat'),fullfile(formal,'summary.mat'),fullfile(paired,'paired_decisions.csv')};for k=1:numel(must),assert(exist(must{k},'file')==2,'stage4a7_2_r2_1_2:MissingCanonicalInput','Missing canonical input %s.',must{k});end
    d=load(fullfile(formal,'checkpoint_development.mat'));c=load(fullfile(formal,'checkpoint_calibration.mat'));s=load(fullfile(formal,'summary.mat'),'sc','ids');
    % Reload actual scored-library IDs from the truth-free frozen cache.
    q=load(fullfile(formal,'checkpoint_identity.mat'),'scored');ids={q.scored.topology_id};
    [selected,method_rows,models,method_manifest]=stage4a7_2_r2_calibrated_method_selection(d.devD,{d.dev.truth_topology_id},c.calD,{c.cal.truth_topology_id},ids,s.sc,d.ids.experiment_hash); %#ok<ASGLU>
    paired_t=readtable(fullfile(paired,'paired_decisions.csv'));
    boundary=struct('old_category',{'boundary_lower','boundary_upper','parameter_ood_near','parameter_ood_medium','parameter_ood_far'}, ...
        'canonical_category',{'near_lower_boundary_in_domain','near_upper_boundary_in_domain','upper_ood_near','upper_ood_medium','upper_ood_far'}, ...
        'main_length_scale',{0.951,1.049,1.10,1.30,1.60}, ...
        'interpretation',{'strictly in-domain near lower bound','strictly in-domain near upper bound','one-sided upper OOD','one-sided upper OOD','one-sided upper OOD'});
    manifest=canonical_rows(root,source_root,formal,paired,s.ids);write_rows(fullfile(out,'canonical_manifest.csv'),manifest);write_rows(fullfile(out,'source_result_status.csv'),source_status(root,source_root));
    write_rows(fullfile(out,'method_selection_cluster_bootstrap.csv'),method_rows);write_rows(fullfile(out,'method_selection_cluster_comparisons.csv'),method_manifest.bootstrap_comparisons);write_rows(fullfile(out,'bootstrap_row_vs_cluster_audit.csv'),row_vs_cluster_audit(formal,method_manifest.bootstrap_comparisons));write_rows(fullfile(out,'category_semantics.csv'),boundary);
    summary=struct('stage_name','Stage 4A.7.2-R.2.1.2','status','completed','canonical_result_version','final_source_v3','canonical_formal_dir',relative(root,formal),'canonical_paired_dir',relative(root,paired),'selected_for_execution',selected,'deterministic_development_winner',method_manifest.deterministic_development_winner,'statistically_distinguishable_winner',method_manifest.statistically_distinguishable_winner,'scientifically_unique_winner',method_manifest.scientifically_unique_winner,'cluster_bootstrap_unit','candidate_id','paired_row_count',height(paired_t),'runtime_s',toc(t0),'source_formal_experiment_hash',d.ids.experiment_hash,'source_tree_hash',d.ids.source_tree_hash,'stage4b_started',false);
    write_rows(fullfile(out,'summary.csv'),summary);save(fullfile(out,'summary.mat'),'summary','method_rows','method_manifest','boundary','manifest','-v7');
    fprintf('Stage 4A.7.2-R.2.1.2 completed: selected=%s unique=%d in %.3f s.\n',selected,summary.scientifically_unique_winner,summary.runtime_s);
end
function rows=source_status(root,source_root)
    paths={'results/data/stage4a7_2_r2','results/data/stage4a7_2_r2_1','results/data/stage4a7_2_r2_1_1/final_source_v2','results/data/stage4a7_2_r2_1_1/final_source_v3'};
    labels={'R2_historical','R2_1_historical','R2_1_1_v2_historical','R2_1_1_v3_canonical'};
    use={'read_only_not_reused','read_only_not_reused','read_only_not_reused','canonical_reanalysis_source'};
    rows=repmat(struct('relative_path','','result_label','','archive_status','','reanalysis_role','','exists',false),0,1);
    for k=1:numel(paths)
        p=fullfile(root,paths{k});
        if k==4 && nargin>=2 && ~strcmp(source_root,fullfile(root,'results','data','stage4a7_2_r2_1_1','final_source_v3'))
            p='external_frozen_source_v3';exists_flag=exist(source_root,'dir')==7;
        else
            exists_flag=exist(p,'dir')==7;
        end
        rows(end+1)=struct('relative_path',p,'result_label',labels{k},'archive_status','read_only_preserved','reanalysis_role',use{k},'exists',exists_flag); %#ok<AGROW>
    end
end
function rows=row_vs_cluster_audit(formal,cluster_rows)
    old_path=fullfile(formal,'method_selection_bootstrap.csv');
    assert(exist(old_path,'file')==2,'stage4a7_2_r2_1_2:MissingRowBootstrap','Missing historical row-bootstrap audit %s.',old_path);
    old=readtable(old_path);rows=repmat(struct('method_a','','method_b','','metric_id','','historical_resampling_unit','development_row','cluster_resampling_unit','candidate_id_cluster','historical_ci_low',NaN,'historical_ci_high',NaN,'cluster_ci_low',NaN,'cluster_ci_high',NaN,'historical_definition_version','','cluster_definition_version','','comparison_status',''),0,1);
    fields={'coverage','mean_set_size','selective_risk'};
    for k=1:height(old)
        direct=true;ix=find(strcmp({cluster_rows.method_a},old.method_a{k})&strcmp({cluster_rows.method_b},old.method_b{k}),1);
        if isempty(ix),direct=false;ix=find(strcmp({cluster_rows.method_a},old.method_b{k})&strcmp({cluster_rows.method_b},old.method_a{k}),1);end
        if isempty(ix),continue;end
        for j=1:numel(fields)
            f=fields{j};r=rows_template_compare();r.method_a=old.method_a{k};r.method_b=old.method_b{k};r.metric_id=f;r.historical_ci_low=old.([f '_ci_low'])(k);r.historical_ci_high=old.([f '_ci_high'])(k);lo=cluster_rows(ix).([f '_ci_low']);hi=cluster_rows(ix).([f '_ci_high']);if ~direct,tmp=-hi;hi=-lo;lo=tmp;end;r.cluster_ci_low=lo;r.cluster_ci_high=hi;r.historical_definition_version=old.definition_version{k};r.cluster_definition_version=cluster_rows(ix).definition_version;r.comparison_status='same_development_input_different_resampling_unit';rows(end+1)=r; %#ok<AGROW>
        end
    end
end
function r=rows_template_compare(),r=struct('method_a','','method_b','','metric_id','','historical_resampling_unit','development_row','cluster_resampling_unit','candidate_id_cluster','historical_ci_low',NaN,'historical_ci_high',NaN,'cluster_ci_low',NaN,'cluster_ci_high',NaN,'historical_definition_version','','cluster_definition_version','','comparison_status','');end
function rows=canonical_rows(root,source_root,formal,paired,ids)
    items={"formal","paired","equivalence"};paths={formal,paired,fullfile(source_root,'equivalence')};rows=repmat(struct('stage','Stage 4A.7.2-R.2.1.2','canonical_result_version','final_source_v3','artifact_role','','relative_path','','file_size_bytes',0,'sha256','','source_tree_hash','','source_experiment_hash','','used_for_formal_report',true,'notes',''),0,1);
    for k=1:numel(items)
        listing=dir(fullfile(paths{k},'*'));for j=1:numel(listing),if listing(j).isdir,continue;end;p=fullfile(listing(j).folder,listing(j).name);r=rows_template();r.artifact_role=char(items{k});r.relative_path=logical_relative(root,source_root,p);r.file_size_bytes=listing(j).bytes;r.sha256=stage4a7_2_r2_sha256_file(p);r.source_tree_hash=ids.source_tree_hash;r.source_experiment_hash=ids.experiment_hash;r.notes=ternary(endsWith(listing(j).name,'.mat'),'canonical compact checkpoint or summary; historical large artifacts remain read-only','canonical CSV or audit artifact');rows(end+1)=r;end %#ok<AGROW>
    end
end
function r=rows_template(),r=struct('stage','Stage 4A.7.2-R.2.1.2','canonical_result_version','final_source_v3','artifact_role','','relative_path','','file_size_bytes',0,'sha256','','source_tree_hash','','source_experiment_hash','','used_for_formal_report',true,'notes','');end
function p=relative(root,path),prefix=[root filesep];p=strrep(path,prefix,'');end
function p=logical_relative(root,source_root,path)
    default_source=fullfile(root,'results','data','stage4a7_2_r2_1_1','final_source_v3');
    if strcmp(source_root,default_source),p=relative(root,path);return;end
    prefix=[source_root filesep];
    if strncmp(path,prefix,numel(prefix)),p=['external_frozen_source_v3/' strrep(path(numel(prefix)+1:end),filesep,'/')];
    else,p='external_frozen_source_v3';end
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
