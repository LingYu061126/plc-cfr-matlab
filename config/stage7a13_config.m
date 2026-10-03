function cfg=stage7a13_config(base,mode)
%STAGE7A13_CONFIG Structure-disjoint H50 calibration and paired CI study.
%   Frequency Hz, length m, impedance ohm; serial, no parallel workers.
    if nargin<1||isempty(base)
        base=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin<2||isempty(mode),mode='smoke';end
    assert(ismember(mode,{'smoke','formal'}),'stage7a13:Mode');
    cfg=stage7a12_config(base,mode);
    cfg.stage='Stage 7A.13';
    cfg.version='stratified_h50_confirmation_v1';
    cfg.baseline_commit='43b18eba60f1ceedc1f43b883bab46656c4e5e52';
    cfg.seed_cfr_E=1310000000;cfg.seed_cfr_A=1320000000;
    cfg.seed_cfr_F=1330000000;cfg.seed_cfr_T=1350000000;
    cfg.seed_lf_test=1360000000;cfg.seed_noinfo=1370000000;
    cfg.lf_tolerance_ohm=0.0417550662111521;
    cfg.calibration_graph_ids={'J30_000','J50_000', ...
        'J30_010','J50_100','J30_011','J50_101'};
    cfg.test_ids={'G001','G002','G003','DOUBLE_M2', ...
        'ADD_M2_M3','DOUBLE_M3','EXT_021','EXT_201', ...
        'OUT10','OUT70','J30_002','J50_200'};
    cfg.new_family_ids={'J30_002','J50_200'};
    cfg.min_stratum_samples=150;
    cfg.min_stratum_structures=2;
    cfg.n_cfr_cal_per_graph=100;
    cfg.n_test_per_graph=30;
    if strcmp(mode,'smoke')
        cfg.n_cfr_cal_per_graph=10;
        cfg.n_test_per_graph=3;
    end
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_13',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_13');
    cfg.use_parallel=false;cfg.worker_count=0;
end
