function output = exp12_stage4a1_candidate_library_audit(cfg, sc)
%EXP12_STAGE4A1_CANDIDATE_LIBRARY_AUDIT Small deterministic model audit.
%   Outputs manifests only.  Results apply solely to the declared candidate
%   grammar, nominal parameter grid, SISO port configuration and TL model.
    if nargin<1||isempty(cfg), root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);end
    if nargin<2||isempty(sc),sc=stage4a1_config(cfg);end
    ensure_result_dirs(cfg); rng(sc.random_seed,'twister'); started=tic;
    candidates=generate_radial_topology_candidates(sc.generator);
    grid=topology_parameter_grid(sc.parameter_search);
    library=build_composite_topology_library(sc.frequency_hz,candidates,grid, ...
        sc.measurement_kind,cfg,sc.max_composite_templates);
    audit=audit_candidate_observability(candidates,library,cfg,sc.tie_tolerance);
    elapsed=toc(started); prefix=sc.output_prefix;
    writetable(struct2table(candidate_rows(candidates)),fullfile(cfg.results_data,[prefix '_candidate_manifest.csv']));
    writetable(struct2table(template_rows(library)),fullfile(cfg.results_data,[prefix '_composite_template_manifest.csv']));
    writetable(struct2table(class_rows(audit)),fullfile(cfg.results_data,[prefix '_observability_equivalence_classes.csv']));
    writetable(struct2table(edge_rows(candidates)),fullfile(cfg.results_data,[prefix '_candidate_edges.csv']));
    summary=struct('stage_name',sc.stage_name,'version',sc.version,'result_scope', ...
        'model-internal audit under declared grammar, nominal parameters, port, termination and forward model', ...
        'candidate_count',numel(candidates),'structural_count_after_dedup',audit.structural_count_after_dedup, ...
        'parameter_template_count',numel(grid),'composite_template_count',numel(library), ...
        'measurement_kind',sc.measurement_kind,'tie_tolerance',sc.tie_tolerance, ...
        'frequency_count',numel(sc.frequency_hz),'runtime_s',elapsed,'config_hash',audit.config_hash);
    writetable(struct2table(summary),fullfile(cfg.results_data,[prefix '_candidate_generation_summary.csv']));
    save(fullfile(cfg.results_data,[prefix '_audit.mat']),'sc','candidates','grid','library','audit','summary','-v7.3');
    fprintf('EXP12 Stage 4A.1: candidates=%d parameters=%d templates=%d classes=%d elapsed=%.3f s\n', ...
        numel(candidates),numel(grid),numel(library),numel(audit.equivalence_classes),elapsed);
    output=struct('candidates',candidates,'grid',grid,'library',library,'audit',audit,'summary',summary);
end

function rows=candidate_rows(c)
    rows=repmat(struct('topology_id','','canonical_key','','node_count',0,'edge_count',0,'branch_count',0,'source_node','','receiver_node',''),1,numel(c));
    for k=1:numel(c),rows(k)=struct('topology_id',c(k).topology_id,'canonical_key',c(k).canonical_key, ...
        'node_count',c(k).node_count,'edge_count',c(k).edge_count,'branch_count',numel(c(k).branch_edges), ...
        'source_node',c(k).source_node,'receiver_node',c(k).receiver_node);end
end
function rows=template_rows(x)
    rows=repmat(struct('template_id','','topology_id','','canonical_key','','parameter_grid_index',0,'is_nominal_template',false,'regularization',NaN,'measurement_kind','','frequency_count',0),1,numel(x));
    for k=1:numel(x),rows(k)=struct('template_id',x(k).template_id,'topology_id',x(k).topology_id, ...
        'canonical_key',x(k).canonical_key,'parameter_grid_index',x(k).parameter_grid_index, ...
        'is_nominal_template',x(k).is_nominal_template,'regularization',x(k).regularization, ...
        'measurement_kind',x(k).measurement_kind,'frequency_count',x(k).observation_summary.frequency_count);end
end
function rows=class_rows(a)
    rows=repmat(struct('class_label','','member_topology_ids','','member_count',0,'tie_tolerance',NaN,'config_hash',''),1,numel(a.equivalence_classes));
    for k=1:numel(a.equivalence_classes),x=a.equivalence_classes{k};rows(k)=struct('class_label',x.label, ...
        'member_topology_ids',strjoin(x.member_topology_ids,','),'member_count',numel(x.member_indices), ...
        'tie_tolerance',a.tie_tolerance,'config_hash',a.config_hash);end
end
function rows=edge_rows(c)
    rows=repmat(struct('topology_id','','edge_id','','from','','to','','kind','','length_m',NaN,'cable_type',0,'load_ohm',NaN),0,1);
    for k=1:numel(c),for q=1:numel(c(k).edges),e=c(k).edges(q);rows(end+1)=struct('topology_id',c(k).topology_id,'edge_id',e.id,'from',e.from,'to',e.to,'kind',e.kind,'length_m',e.length_m,'cable_type',e.cable_type,'load_ohm',e.load);end,end %#ok<AGROW>
end
