function cfg=stage7a12_config(base,mode)
%STAGE7A12_CONFIG Independent LF-CI plus frozen CFR simulation settings.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='smoke';end
    cfg=stage7a11_config(base,mode);
    cfg.stage='Stage 7A.12';cfg.version='lf_ci_candidate_generation_v1';
    cfg.baseline_commit='3f43899141ac0c5d45e736c0141844c7af08c681';
    cfg.r_main_ohm_per_m=1e-3;cfg.r_branch_ohm_per_m=1.5e-3;
    cfg.lf_snapshots=80;cfg.lf_current_std_a=1;
    cfg.lf_voltage_noise_std_v=0.002;cfg.lf_shift_probability=0.15;
    cfg.lf_ridge_lambda=0.05;cfg.lf_top_k=3;
    cfg.lf_candidate_main_scale_bounds=[0.9 1.1];
    cfg.seed_lf_cal=1110000000;cfg.seed_lf_test=1260000000;
    cfg.seed_cfr_E=1130000000;cfg.seed_cfr_A=1140000000;
    cfg.seed_cfr_F=1150000000;cfg.seed_cfr_T=1250000000;
    cfg.n_lf_cal_per_graph=100;cfg.n_cfr_cal_per_graph=100;
    cfg.n_test_per_graph=30;
    if strcmp(mode,'smoke')
        cfg.n_lf_cal_per_graph=10;cfg.n_cfr_cal_per_graph=10;
        cfg.n_test_per_graph=3;
    end
    cfg.dev_ids={'MIRROR_M3','EXT_012','ADD_M1_M3', ...
        'EXT_102','ADD_M1_M2','EXT_111','DOUBLE_M1'};
    cfg.test_ids={'G001','G002','G003','DOUBLE_M2', ...
        'ADD_M2_M3','DOUBLE_M3','EXT_021','EXT_201', ...
        'MID30','MID50','OUT10','OUT70'};
    cfg.initial_ids={'G001','G002','G003'};
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_12',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_12');
    cfg.use_parallel=false;cfg.worker_count=0;
end
