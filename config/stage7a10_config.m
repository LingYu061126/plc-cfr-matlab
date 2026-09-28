function cfg=stage7a10_config(base,mode)
%STAGE7A10_CONFIG Independent synthetic multiview CFR study configuration.
%   Frequency is Hz; line length m; impedances ohm. No parallel pool.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='smoke';end
    assert(ismember(mode,{'smoke','formal'}),'stage7a10:Mode');
    cfg=stage7a4_mirror_observation_config(base,'formal');
    cfg.stage='Stage 7A.10';cfg.mode=mode;cfg.version='stage7a10_protocol_v1';
    cfg.verification_baseline_commit='1c7ae4a40f641d37c44a35b3d64278af19fcc98f';
    cfg.seed_D=810000000;cfg.seed_E=820000000;cfg.seed_A0=825000000;
    cfg.seed_A1=830000000;cfg.seed_F=840000000;cfg.seed_T=850000000;
    cfg.seed_stress=860000000;
    cfg.n_E_per_topology=100;cfg.n_A0_per_topology=100;
    cfg.n_A1_per_topology=100;cfg.n_F_per_topology=100;
    cfg.n_T_per_topology=30;cfg.n_stress_per_topology=15;
    cfg.extra_view_threshold=3;
    cfg.extra_view_indices=[3 7 12 14 16]; % H25, H100, loaded M1/M2/M3 node CFR
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_10',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_10');
    cfg.use_parallel=false;cfg.worker_count=0;
    if strcmp(mode,'smoke')
        cfg.n_E_per_topology=5;cfg.n_A0_per_topology=8;
        cfg.n_A1_per_topology=8;cfg.n_F_per_topology=8;
        cfg.n_T_per_topology=3;cfg.n_stress_per_topology=2;
    end
end
