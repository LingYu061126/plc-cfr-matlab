function cfg=stage7a11_config(base,mode)
%STAGE7A11_CONFIG Frozen serial synthetic CFR experiment configuration.
%   Frequency Hz, line length m, impedances ohm. No parallel pool.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='smoke';end
    cfg=stage7a10_config(base,mode);
    cfg.stage='Stage 7A.11';cfg.version='joint_h50_conditioned_grid_v1';
    cfg.verification_baseline_commit='c2f4571b407993a349cd8869f85632f46ac8afe1';
    cfg.seed_E=1010000000;cfg.seed_A0=1020000000;
    cfg.seed_A1=1030000000;cfg.seed_F=1040000000;
    cfg.seed_fixed_T=1050000000;cfg.seed_new_T=1060000000;
    cfg.n_E_per_topology=100;cfg.n_A0_per_topology=100;
    cfg.n_A1_per_topology=100;cfg.n_F_per_topology=100;
    cfg.n_T_per_topology=30;
    if strcmp(mode,'smoke')
        cfg.n_E_per_topology=8;cfg.n_A0_per_topology=8;
        cfg.n_A1_per_topology=8;cfg.n_F_per_topology=8;
        cfg.n_T_per_topology=3;
    end
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_11',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_11');
    cfg.use_parallel=false;cfg.worker_count=0;
end
