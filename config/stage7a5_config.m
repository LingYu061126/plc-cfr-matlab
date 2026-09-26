function cfg=stage7a5_config(base,mode)
%STAGE7A5_CONFIG Frozen Stage 7A.5 synthetic study configuration.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='formal';end
    assert(ismember(mode,{'smoke','formal'}),'stage7a5:Mode');
    legacy=stage7a4_mirror_observation_config(base,'formal');
    cfg=struct();cfg.stage='Stage 7A.5';cfg.version='stage7a5_v1';cfg.mode=mode;
    cfg.verification_baseline_commit='7412aade6c129f982f1ebb766299166ccbae2515';
    cfg.frequency_hz=legacy.frequency_hz;cfg.state_50=legacy.states(3);
    cfg.main_scale_grid=legacy.main_scale_grid;cfg.load_scale_grid=legacy.branch_load_grid;
    cfg.main_scale_bounds=[0.9 1.1];cfg.load_scale_bounds=[0.8 1.2];
    cfg.true_main_bounds=[0.98 1.02];cfg.true_load_bounds=[0.8 1.2];
    cfg.snr_db=20;cfg.zin_error_rms_ohm=1;cfg.alpha=0.05;
    cfg.margin_threshold=3;cfg.frequency_train_indices=find(mod(1:numel(cfg.frequency_hz),3)~=0);
    cfg.frequency_holdout_indices=find(mod(1:numel(cfg.frequency_hz),3)==0);
    cfg.top_k=2;cfg.max_edit_depth=2;cfg.candidate_budgets=[7 10];
    cfg.max_forward_template_evaluations=10*numel(cfg.main_scale_grid)*numel(cfg.load_scale_grid);
    cfg.seed_E=101000000;cfg.seed_A=102000000;cfg.seed_F=103000000;
    cfg.seed_D=104000000;cfg.seed_T=105000000;cfg.seed_control_E=106000000;
    cfg.seed_control_A=107000000;cfg.seed_control_F=108000000;cfg.seed_control_T=109000000;
    cfg.n_E_per_class=20;cfg.n_A_per_class=50;cfg.n_F_per_class=50;
    cfg.n_D_per_topology=20;cfg.n_T_per_topology=30;cfg.n_control_per_topology=30;
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_5',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_5');
    cfg.use_parallel=false;cfg.worker_count=0;
    cfg.target_topology_ids={'MIRROR_M3','ADD_M1_M3','ADD_M2_M3','DOUBLE_M3'};
    cfg.development_topology_ids={'ADD_M1_M2','DOUBLE_M2'};
    cfg.observation_schemes={'H50','Zin50','H50_Zin50'};
    cfg.observation_views={1,2,[1 2]};
    if strcmp(mode,'smoke')
        cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_5','smoke_v5');
        cfg.n_E_per_class=3;cfg.n_A_per_class=4;cfg.n_F_per_class=4;
        cfg.n_D_per_topology=3;cfg.n_T_per_topology=3;cfg.n_control_per_topology=3;
    else
        cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_5','formal_v2');
    end
end
