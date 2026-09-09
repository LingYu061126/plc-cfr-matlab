function ids = stage4a7_2_r2_1_build_hashes(root,sc,manifest,candidates,cache)
%STAGE4A7_2_R2_1_BUILD_HASHES Build separated scientific identities.
    ids=struct();ids.source_tree_hash=stage4a7_2_r2_source_hash(root);
    ids.data_provenance_hash=stage4a4_scientific_config_hash(manifest);
    ids.candidate_library_hash=stage4a4_scientific_config_hash(candidate_identity(candidates));
    ids.configuration_hash=stage4a4_scientific_config_hash(config_identity(sc));
    if nargin>=5 && ~isempty(cache)
        ids.template_cache_hash=stage4a4_scientific_config_hash(struct('candidate_library_hash',ids.candidate_library_hash, ...
            'theta_grid',{cache.theta_grid},'frequency_hz',cache.frequency_hz,'measurement_kind',cache.measurement_kind, ...
            'H_hash',template_hashes(cache.H),'source_tree_hash',ids.source_tree_hash,'data_provenance_hash',ids.data_provenance_hash));
    else
        ids.template_cache_hash='';
    end
    ids.experiment_hash=stage4a4_scientific_config_hash(struct('source_tree_hash',ids.source_tree_hash, ...
        'data_provenance_hash',ids.data_provenance_hash,'candidate_library_hash',ids.candidate_library_hash, ...
        'configuration_hash',ids.configuration_hash,'template_cache_hash',ids.template_cache_hash));
    ids.runtime_environment_hash=stage4a4_scientific_config_hash(struct('matlab_version',version, ...
        'computer',computer,'toolbox',license('inuse')));
end
function x=config_identity(sc)
    x=sc;
    for n={'results_data','results_logs','root_dir','cache_dir','cache_file'},if isfield(x,n{1}),x=rmfield(x,n{1});end,end
    if isfield(x,'derived_subnetwork')
        x.derived_subnetwork='data/derived/enwl_uncertain_prior/stage4a7_2_r1_selected_public_subnetwork.csv';
    end
end
function rows=candidate_identity(c)
    rows=repmat(struct('id','','topology_key','','asset_state_key','','prior_cost',NaN,'adapter_hash','','network',struct()),numel(c),1);
    for k=1:numel(c),rows(k).id=getid(c(k));rows(k).topology_key=getf(c(k),'topology_key',getf(c(k),'canonical_graph_key',''));rows(k).asset_state_key=getf(c(k),'asset_state_key','');rows(k).prior_cost=getf(c(k),'prior_cost',NaN);rows(k).adapter_hash=getf(c(k),'adapter_hash','');rows(k).network=getf(c(k),'network',struct());end
end
function rows=template_hashes(H)
    rows=cell(size(H));for k=1:numel(H),rows{k}=stage4a4_scientific_config_hash(H{k});end
end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
