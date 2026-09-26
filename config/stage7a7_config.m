function cfg=stage7a7_config(base,mode,condition)
%STAGE7A7_CONFIG Frozen synthetic CFR/Zin robustness and junction edit study.
%   Frequency is Hz, lengths m, Zin complex-error RMS ohm. No parallel pool.
    if nargin<1||isempty(base)
        base=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin<2||isempty(mode),mode='formal';end
    if nargin<3||isempty(condition),condition='nominal';end
    assert(ismember(mode,{'smoke','formal'}),'stage7a7:Mode');
    valid={'nominal','zin3','zin6','missing_half','parameter_shift'};
    assert(ismember(condition,valid),'stage7a7:Condition');
    cfg=stage7a6_config(base,'formal',17);
    cfg.stage='Stage 7A.7';cfg.version='stage7a7_protocol_v1';
    cfg.mode=mode;cfg.condition=condition;
    cfg.verification_baseline_commit='c011521314f95b013d88a2f0beeda9df63dd1cac';
    cfg.candidate_budgets=[5 12 37];
    cfg.max_forward_template_evaluations=37* ...
        numel(cfg.main_scale_grid)*numel(cfg.load_scale_grid);
    cfg.insert_edges=[2 3];cfg.insert_fraction=0.5;
    cfg.minimum_main_segment_m=10;cfg.total_main_length_m=80;
    cfg.maximum_main_nodes=6;cfg.maximum_total_nodes=9;
    cfg.maximum_branches=3;cfg.maximum_branches_per_node=2;
    cfg.seed_E=601000000;cfg.seed_A=611000000;cfg.seed_F=621000000;
    cfg.seed_T_inlib=801000000;cfg.seed_T_old_out=811000000;
    cfg.seed_T_reachable=821000000;cfg.seed_T_grammar_out=831000000;
    cfg.seed_T_domain=841000000;
    cfg.n_E_per_class=8;cfg.n_A_per_class=20;cfg.n_F_per_class=20;
    cfg.n_T_inlib_per_topology=6;cfg.n_T_old_out_per_topology=6;
    cfg.n_T_reachable_per_topology=6;cfg.n_T_grammar_out_per_topology=6;
    cfg.n_T_domain_per_topology=6;
    cfg.zin_error_rms_ohm=1;
    if strcmp(condition,'zin3'),cfg.zin_error_rms_ohm=3;end
    if strcmp(condition,'zin6'),cfg.zin_error_rms_ohm=6;end
    if strcmp(condition,'missing_half')
        cfg.frequency_train_indices=intersect(cfg.frequency_train_indices, ...
            1:2:numel(cfg.frequency_hz));
        cfg.frequency_holdout_indices=intersect(cfg.frequency_holdout_indices, ...
            1:2:numel(cfg.frequency_hz));
    end
    cfg.test_main_bounds=cfg.true_main_bounds;
    if strcmp(condition,'parameter_shift'),cfg.test_main_bounds=[0.90 1.10];end
    if strcmp(mode,'smoke')
        shift=400000000;
        names={'seed_E','seed_A','seed_F','seed_T_inlib','seed_T_old_out', ...
            'seed_T_reachable','seed_T_grammar_out','seed_T_domain'};
        for k=1:numel(names),cfg.(names{k})=cfg.(names{k})+shift;end
        cfg.n_E_per_class=2;cfg.n_A_per_class=3;cfg.n_F_per_class=3;
        cfg.n_T_inlib_per_topology=1;cfg.n_T_old_out_per_topology=1;
        cfg.n_T_reachable_per_topology=1;cfg.n_T_grammar_out_per_topology=1;
        cfg.n_T_domain_per_topology=1;
    end
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_7', ...
        mode,condition);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_7');
    cfg.use_parallel=false;cfg.worker_count=0;
end
