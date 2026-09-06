function sc = stage4a5_1_integrity_config(base_cfg, mode)
%STAGE4A5_1_INTEGRITY_CONFIG Frozen identity/cache/resampling audit.
    if nargin<1||isempty(base_cfg),root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);end
    if nargin<2||isempty(mode),mode='formal';end
    sc=stage4a5_multiscale_confirmation_config(base_cfg,mode);
    sc.stage_name='Stage 4A.5.1';
    sc.version='4a5_1_integrity_v1';
    sc.code_version='stage4a5_1_integrity_v1';
    sc.output_prefix='stage4a5_1';
    if strcmpi(mode,'smoke'),sc.output_prefix='stage4a5_1_smoke';end
    sc.cache_dir=fullfile(base_cfg.results_data,'stage4a5_1_cache');
    sc.resampling_base_seed=20261510;
    sc.cache_schema_version='stage4a5_1_cache_identity_v1';
    sc.frozen_methods=struct( ...
        'A_stage4a1_quick61',{{'M0_M0_q900_K5_qs00','M1_M8_q750_K5_qs00','M2_M8_q750_K3_qs00','M3_M4_q750_K3_qs70'}}, ...
        'B_ofdm_active_subcarriers',{{'M0_M0_q900_K5_qs00','M1_M8_q750_K5_qs00','M2_M8_q750_K3_qs00','M3_M4_q750_K3_qs80'}});
end
