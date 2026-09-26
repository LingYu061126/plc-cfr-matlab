function cfg=stage7a6_config(base,mode,budget)
%STAGE7A6_CONFIG Frozen synthetic extrapolation audit configuration.
%   Frequency is Hz; physical lengths are m; output stays under Stage 7A.6.
    if nargin<1||isempty(base)
        base=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin<2||isempty(mode),mode='formal';end
    if nargin<3||isempty(budget),budget=17;end
    assert(ismember(mode,{'smoke','formal'}),'stage7a6:Mode');
    cfg=stage7a5_config(base,'formal');
    cfg.stage='Stage 7A.6';
    cfg.version='stage7a6_frozen_v1';
    cfg.mode=mode;
    cfg.verification_baseline_commit='7fef66708f486de9bab310abe6034b005b40d4a2';
    cfg.candidate_budgets=[3 5 7 10 17];
    assert(ismember(budget,cfg.candidate_budgets),'stage7a6:Budget');
    cfg.budget=budget;
    cfg.max_forward_template_evaluations=17* ...
        numel(cfg.main_scale_grid)*numel(cfg.load_scale_grid);
    cfg.seed_T_inlib=211000000;
    cfg.seed_T_old_out=221000000;
    cfg.seed_T_reachable=231000000;
    cfg.seed_T_grammar_out=241000000;
    cfg.seed_T_domain=251000000;
    cfg.n_T_inlib_per_topology=20;
    cfg.n_T_old_out_per_topology=10;
    cfg.n_T_reachable_per_topology=10;
    cfg.n_T_grammar_out_per_topology=10;
    cfg.n_T_domain_per_topology=10;
    if strcmp(mode,'smoke')
        cfg.seed_E=cfg.seed_E+500000000;
        cfg.seed_A=cfg.seed_A+500000000;
        cfg.seed_F=cfg.seed_F+500000000;
        cfg.seed_T_inlib=cfg.seed_T_inlib+500000000;
        cfg.seed_T_old_out=cfg.seed_T_old_out+500000000;
        cfg.seed_T_reachable=cfg.seed_T_reachable+500000000;
        cfg.seed_T_grammar_out=cfg.seed_T_grammar_out+500000000;
        cfg.seed_T_domain=cfg.seed_T_domain+500000000;
        cfg.n_E_per_class=3;
        cfg.n_A_per_class=4;
        cfg.n_F_per_class=4;
        cfg.n_T_inlib_per_topology=2;
        cfg.n_T_old_out_per_topology=1;
        cfg.n_T_reachable_per_topology=1;
        cfg.n_T_grammar_out_per_topology=1;
        cfg.n_T_domain_per_topology=1;
    end
    output_mode=mode;
    if strcmp(mode,'smoke'),output_mode='smoke_v3';end
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_6', ...
        output_mode,sprintf('budget_%02d',budget));
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_6');
    cfg.use_parallel=false;
    cfg.worker_count=0;
end
