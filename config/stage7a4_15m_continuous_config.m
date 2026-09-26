function cfg=stage7a4_15m_continuous_config(base,mode)
%STAGE7A4_15M_CONTINUOUS_CONFIG Independent synthetic mirror audit.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='formal';end
    assert(ismember(mode,{'smoke','formal'}));
    old=stage7a4_mirror_observation_config(base,'formal');
    cfg=old;cfg.stage='Stage 7A.4 15m continuous';
    cfg.version='stage7a4_15m_continuous_v1';cfg.mode=mode;
    cfg.verification_baseline_commit='c01e11fa52429e9d78479cf1fbffef3e6e00dee3';
    cfg.seed_E=910000000;cfg.seed_A=920000000;
    cfg.seed_F=930000000;cfg.seed_T=940000000;
    cfg.seed_D=950000000;
    cfg.main_scale_bounds=[0.9 1.1];cfg.load_scale_bounds=[0.8 1.2];
    cfg.optimizer_tol_x=1e-6;cfg.optimizer_max_fun_evals=35;
    cfg.n_E_per_topology=10;cfg.n_A_per_topology=20;
    cfg.n_F_per_topology=20;cfg.n_T_per_topology=30;
    cfg.n_D_per_topology=2;
    cfg.snr_values=[20 10];
    cfg.parameter_regimes={'on_on','off_on','on_off','off_off'};
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_4_15m_continuous',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_4_15m_continuous');
    if strcmp(mode,'smoke')
        cfg.n_E_per_topology=3;cfg.n_A_per_topology=4;
        cfg.n_F_per_topology=4;cfg.n_T_per_topology=4;
        cfg.n_D_per_topology=1;
        cfg.parameter_regimes={'on_on','off_off'};
    end
end
