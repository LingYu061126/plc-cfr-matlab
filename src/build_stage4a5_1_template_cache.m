function cache = build_stage4a5_1_template_cache(grid,candidates,theta_grid,cfg,metadata)
%BUILD_STAGE4A5_1_TEMPLATE_CACHE Build cache with complete identity metadata.
    cache=build_stage4a3_1_template_cache(grid,candidates,theta_grid,cfg,metadata);
    cache.stage_name='Stage 4A.5.1';
    cache.cache_schema_version=metadata.cache_schema_version;
    cache.cache_configuration_hash=metadata.cache_configuration_hash;
    cache.forward_model_source_hash=metadata.forward_model_source_hash;
    cache.parameter_grid=theta_grid;
    cache.source_impedance_ohm=cfg.Zs;
    cache.receiver_impedance_ohm=cfg.Zr;
    cache.experiment_scientific_hash=metadata.experiment_scientific_hash;
    cache.source_tree_hash=metadata.source_tree_hash;
end
