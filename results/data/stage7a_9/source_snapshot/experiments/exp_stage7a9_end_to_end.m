function exp_stage7a9_end_to_end(root,method,run_identity)
%EXP_STAGE7A9_END_TO_END Serial complete pipeline timing, A=7A8, B=7A9.
%   Includes generation, template construction, independent calibration,
%   all 66 observations, decisions and scientific table serialization.
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    assert(ismember(method,{'A','B'}));
    base=default_config(root);cfg=stage7a9_config(base,'formal');
    folder=fullfile(root,'results','data','stage7a_9','end_to_end',method);
    if nargin>=3
        assert(~isempty(regexp(run_identity,'^[a-zA-Z0-9_]+$','once')));
        folder=fullfile(root,'results','data','stage7a_9','end_to_end',run_identity,method);
    end
    assert(~isfolder(folder),'Output already exists; select a new run identity.');
    mkdir(folder);total=tic;t=tic;
    if strcmp(method,'A'),score=@stage7a8_score_observation;
    else,score=@stage7a9_score_observation;end
    [pool,ix,~,catalog,g]=stage7a7_candidate_space(base,cfg);
    generation_s=toc(t);t=tic;
    bank=stage7a5_template_bank(pool,base,cfg);template_s=toc(t);t=tic;
    E=stage7a5_generate_split(catalog,g.inlib,base,cfg,cfg.seed_E,cfg.n_E_per_class,'E',false);
    A=stage7a5_generate_split(catalog,g.inlib,base,cfg,cfg.seed_A,cfg.n_A_per_class,'A',false);
    F=stage7a5_generate_split(catalog,g.inlib,base,cfg,cfg.seed_F,cfg.n_F_per_class,'F',false);
    sigma=zeros(1,2);
    for i=1:numel(E)
        for v=1:2,sigma(v)=sigma(v)+mean(abs(E(i).observed{v}-E(i).clean{v}).^2);end
    end
    sigma=sqrt(sigma/numel(E));tcfg=cfg;tcfg.true_main_bounds=cfg.test_main_bounds;
    T=[stage7a5_generate_split(catalog,g.inlib,base,tcfg,cfg.seed_T_inlib,6,'T_inlib',false); ...
       stage7a5_generate_split(catalog,g.old_out,base,tcfg,cfg.seed_T_old_out,6,'T_old_out',false); ...
       stage7a5_generate_split(catalog,g.reachable,base,tcfg,cfg.seed_T_reachable,6,'T_reachable',false); ...
       stage7a5_generate_split(catalog,g.grammar_out,base,tcfg,cfg.seed_T_grammar_out,6,'T_grammar_out',false); ...
       stage7a5_generate_split(catalog,g.domain,base,tcfg,cfg.seed_T_domain,6,'T_domain',true)];
    simulation_s=toc(t);t=tic;delta=zeros(numel(A),1);fit=zeros(numel(F),1);
    for i=1:numel(A)
        z=score(A(i).observed,pool,bank,base,cfg,ix,[1 2],sigma,[]);
        j=find(strcmp(z.candidate_ids,A(i).truth_id),1);
        delta(i)=z.distances(j)-min(z.distances);
    end
    for i=1:numel(F)
        z=score(F(i).observed,pool,bank,base,cfg,ix,[1 2],sigma,[]);fit(i)=z.fit_statistic;
    end
    model=stage7a5_calibrate_split(delta,fit,bank,cfg,1:37,[1 2],sigma,'C',37);
    model.condition_identity=stage7a7_condition_identity(cfg,bank,[1 2],sigma,'C37',37);
    archived=load(fullfile(cfg.output_dir,'config_snapshot.mat'),'model');
    assert(strcmp(model.calibration_identity,archived.model.calibration_identity));
    calibration_s=toc(t);t=tic;
    rows=cell(numel(T),9);
    old=readtable(fullfile(cfg.output_dir,'samples.csv'),'Delimiter',',','TextType','string');
    for i=1:numel(T)
        s=T(i);z=score(s.observed,pool,bank,base,cfg,ix,[1 2],sigma,model);
        d=stage7a5_decide(z,model,bank);
        id=sprintf('%s_%s_%03d',s.split,s.truth_id,s.replicate);
        j=find(old.sample_id==string(id)&old.method==string(method));assert(numel(j)==1);
        assert(strcmp(old.state(j),d.decision_state)&&strcmp(old.reason(j),d.decision_reason)&& ...
            strcmp(old.candidate_set(j),strjoin(d.candidate_set,';'))&& ...
            abs(old.distance_1(j)-d.distance_1)<=1e-9+1e-10*abs(d.distance_1));
        rows(i,:)={id,s.parameter_seed,s.noise_seed,d.best_candidate, ...
            strjoin(d.candidate_set,';'),d.decision_state,d.decision_reason, ...
            d.distance_1,d.fit_statistic};
    end
    scoring_s=toc(t);t=tic;
    samples=cell2table(rows,'VariableNames',{'sample_id','parameter_seed','noise_seed', ...
        'best_candidate','candidate_set','state','reason','distance_1','fit_statistic'});
    writetable(samples,fullfile(folder,'samples.csv'));
    save(fullfile(folder,'config_snapshot.mat'),'cfg','model','sigma','-v7');
    write_s=toc(t);total_s=toc(total);
    token=regexp(fileread('/proc/self/status'),'VmHWM:\s*(\d+)\s*kB','tokens','once');
    peak_rss_kb=str2double(token{1});
    metadata=table(string(method),generation_s,template_s,simulation_s,calibration_s, ...
        scoring_s,write_s,total_s,peak_rss_kb,string(version), ...
        'VariableNames',{'method','generation_s','template_s','simulation_s','calibration_s', ...
        'scoring_s','write_s','total_s','process_peak_rss_kb','matlab_version'});
    writetable(metadata,fullfile(folder,'metadata.csv'));
    fprintf('PASS end-to-end %s: 66 archived matches, total %.6f s, scoring %.6f s\n',method,total_s,scoring_s);
end
