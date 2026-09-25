function result=exp_stage7a2_set_coverage(root,mode)
%EXP_STAGE7A2_SET_COVERAGE Independent A/B/R/T calibration and paired evaluation.
%   Outputs are confined to results/data/stage7a_2/<mode> and Stage 7A.2 figures.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a2_set_coverage_config(base,mode);sc=cfg.stage7a;
    if exist(cfg.output_root,'dir')~=7,mkdir(cfg.output_root);end
    if exist(cfg.figure_root,'dir')~=7,mkdir(cfg.figure_root);end
    whole=tic;sample_cells={};distance_cells={};curve_cells={};identity_cells={};risk_cells={};
    seed_cells={};
    for q=1:3
        grammar=sc.stage6b.scale.grammars(q);library_name=['scale_' grammar.scale_id];
        lib=stage6b_build_candidate_library('radial_grammar',grammar,base,struct());
        cache=stage7a_build_profile_cache(lib,base,sc);m=numel(lib);ids=cache.candidate_ids;
        cache_info=whos('cache');
        library_hash=stage4a4_scientific_config_hash(struct('ids',{ids}, ...
            'signatures',{cache.candidate_signatures}));
        search_hash=stage4a4_scientific_config_hash(struct('search',sc.search, ...
            'admissible',{cache.admissible}));
        identity=stage4a4_scientific_config_hash(struct('library',library_hash, ...
            'search',search_hash,'frequency_hz',sc.frequency_hz,'score','stage7a_profile_distance_v1'));
        tcal=tic;
        development=make_block(lib,lib,cache,base,cfg,q,cfg.seed_development, ...
            'balanced',cfg.development_per_class,cfg.snr_db,'in_domain');
        a=make_block(lib,lib,cache,base,cfg,q,cfg.seed_set, ...
            'balanced',cfg.set_per_class,cfg.snr_db,'in_domain');
        b=make_block(lib,lib,cache,base,cfg,q,cfg.seed_evidence, ...
            'balanced',cfg.evidence_per_class,cfg.snr_db,'in_domain');
        r=make_block(lib,lib,cache,base,cfg,q,cfg.seed_risk, ...
            'random',cfg.risk_per_class*m,cfg.snr_db,'in_domain');
        seed_cells{end+1}=seed_rows(development,library_name,'D_development'); %#ok<AGROW>
        seed_cells{end+1}=seed_rows(a,library_name,'A_set_calibration'); %#ok<AGROW>
        seed_cells{end+1}=seed_rows(b,library_name,'B_evidence_calibration'); %#ok<AGROW>
        seed_cells{end+1}=seed_rows(r,library_name,'R_risk_audit'); %#ok<AGROW>
        domain_threshold=fixed_quantile(min(a.d,[],2)./a.energy,sc.domain_quantile);
        models=cell(1,2);names={'M2_class_conditional','M3_pooled_empirical'};
        kinds={'class_conditional','pooled_empirical'};
        for h=1:2
            sm=stage7a2_calibrate_set(a.d,a.truth_index,ids,cfg.alpha,kinds{h},identity);
            sizes=zeros(size(b.d,1),1);
            for v=1:numel(sizes)
                z=stage7a2_apply_set(b.d(v,:),sm);sizes(v)=z.set_size;
            end
            eopts=sc.evidence_calibration;eopts.candidate_ids=ids;
            try
                evidence=calibrate_stage5b1_decision_metrics(b.d,b.truth_index,sizes,eopts);
                evidence_status='calibrated';
            catch ME
                if ~strcmp(ME.identifier,'stage5b1:InsufficientReferenceCalibration'),rethrow(ME);end
                evidence=conservative_evidence();evidence_status='insufficient_independent_reference';
            end
            models{h}=struct('candidate_ids',{ids},'frequency_hz',sc.frequency_hz, ...
                'identity',identity,'set_model',sm,'evidence_model',evidence, ...
                'domain_threshold',domain_threshold,'risk_gate',struct('certified',true));
            n_selected=0;n_wrong=0;
            for v=1:size(r.d,1)
                z=stage7a2_score_distances(r.y(v,:),r.d(v,:),models{h});
                if strcmp(z.decision_state,'UNIQUE_CONFIDENT')
                    n_selected=n_selected+1;n_wrong=n_wrong+(z.best_index~=r.truth_index(v));
                end
            end
            upper=stage7a2_binomial_upper(n_wrong,n_selected,cfg.risk_delta);
            certified=upper<=cfg.risk_target;
            risk_cells{end+1}=struct('library',library_name,'method',names{h}, ...
                'risk_seed_base',cfg.seed_risk,'risk_count',size(r.d,1), ...
                'unique_selected',n_selected,'wrong_unique',n_wrong, ...
                'selective_risk_upper_95',upper,'risk_target',cfg.risk_target, ...
                'certified',certified,'evidence_status',evidence_status); %#ok<AGROW>
            models{h}.risk_gate.certified=certified;
            models{h}.risk_gate.upper=upper;
            models{h}.risk_gate.unique_selected=n_selected;
            models{h}.risk_gate.wrong_unique=n_wrong;
            identity_cells{end+1}=struct('library',library_name,'method',names{h}, ...
                'candidate_count',m,'candidate_order',strjoin(ids,','), ...
                'library_hash',library_hash,'search_hash',search_hash, ...
                'calibration_identity',identity,'set_hash',sm.calibration_hash, ...
                'evidence_hash',evidence.calibration_hash, ...
                'development_seed_base',cfg.seed_development, ...
                'set_seed_base',cfg.seed_set,'evidence_seed_base',cfg.seed_evidence, ...
                'risk_seed_base',cfg.seed_risk,'test_seed_base',cfg.seed_test, ...
                'development_seed_hash',stage4a4_scientific_config_hash(development.seed), ...
                'set_seed_hash',stage4a4_scientific_config_hash(a.seed), ...
                'evidence_seed_hash',stage4a4_scientific_config_hash(b.seed), ...
                'risk_seed_hash',stage4a4_scientific_config_hash(r.seed), ...
                'development_rows',size(development.d,1),'set_rows',size(a.d,1), ...
                'evidence_rows',size(b.d,1),'risk_rows',size(r.d,1), ...
                'evidence_reference_count',evidence.reference_sample_count, ...
                'evidence_status',evidence_status,'domain_threshold',domain_threshold, ...
                'risk_certified',certified,'risk_upper_95',upper, ...
                'cache_model_bytes',cache_info.bytes,'cache_build_time_s',cache.build_time_s); %#ok<AGROW>
        end
        calibration_time=toc(tcal);
        % Historical baselines are recalibrated on their prescribed, disjoint seeds.
        [original,original_t]=stage7a_calibrate_candidate_library(lib,base,sc,library_name,q*100000);
        condition=struct('name','matched20_n100','snr_db',20, ...
            'main_bounds',cfg.main_bounds,'load_bounds',cfg.load_bounds,'per_candidate',100);
        [split,split_t]=stage7a1_calibrate_split_library(lib,base,sc,cache,condition, ...
            library_name,202671100+2000000+q*100000,302671100+2000000+q*100000);
        extra=library_out_truth(grammar,lib,base);
        t=make_block(lib,lib,cache,base,cfg,q,cfg.seed_test, ...
            'balanced',cfg.test_per_class,cfg.snr_db,'in_domain');
        o=make_block(lib,extra,cache,base,cfg,q,cfg.seed_library_out, ...
            'single',cfg.stress_count,cfg.snr_db,'library_out');
        p=make_block(lib,lib,cache,base,cfg,q,cfg.seed_parameter_out, ...
            'cyclic',cfg.stress_count,cfg.snr_db,'parameter_out');
        s=make_block(lib,lib,cache,base,cfg,q,cfg.seed_snr_shift, ...
            'cyclic',cfg.stress_count,cfg.shift_snr_db,'snr_shift_10db');
        datasets={t,o,p,s};
        for di=1:numel(datasets)
            block=datasets{di};
            split_names={'T_final_in_domain','T_library_out','T_parameter_out','T_snr_shift'};
            seed_cells{end+1}=seed_rows(block,library_name,split_names{di}); %#ok<AGROW>
            for v=1:size(block.d,1)
                distance_cells{end+1}=candidate_rows(block,v,ids,cache.candidate_signatures,library_name); %#ok<AGROW>
                for h=1:6
                    started=tic;
                    switch h
                        case 1
                            z=stage7a1_audit_decision(block.y(v,:),original,block.d(v,:), ...
                                block.truth_signature{v});method='M0_stage7a_original';
                        case 2
                            z=stage7a1_audit_decision(block.y(v,:),split,block.d(v,:), ...
                                block.truth_signature{v});method='M1_stage7a1_split';
                        case 3
                            z=stage7a2_score_distances(block.y(v,:),block.d(v,:), ...
                                ungated(models{1}));method='M2_class_conditional';
                        case 4
                            z=stage7a2_score_distances(block.y(v,:),block.d(v,:), ...
                                ungated(models{2}));method='M3_pooled_empirical';
                        case 5
                            z=stage7a2_score_distances(block.y(v,:),block.d(v,:),models{1});
                            method='M2R_class_risk_gated';
                        otherwise
                            z=stage7a2_score_distances(block.y(v,:),block.d(v,:),models{2});
                            method='M3R_pooled_risk_gated';
                    end
                    sample_cells{end+1}=sample_row(block,v,z,method,library_name,m, ...
                        identity,toc(started)); %#ok<AGROW>
                end
            end
        end
        for h=1:2
            for alpha=cfg.curve_alpha
                sm=stage7a2_calibrate_set(a.d,a.truth_index,ids,alpha,kinds{h},identity);
                sizes=zeros(size(t.d,1),1);covered=false(size(sizes));
                for v=1:numel(sizes)
                    z=stage7a2_apply_set(t.d(v,:),sm);sizes(v)=z.set_size;
                    covered(v)=z.keep(t.truth_index(v));
                end
                curve_cells{end+1}=struct('library',library_name,'method',names{h}, ...
                    'alpha',alpha,'n',numel(sizes),'covered',nnz(covered), ...
                    'coverage',mean(covered),'mean_set_size',mean(sizes), ...
                    'median_set_size',median(sizes),'empty',nnz(sizes==0), ...
                    'singleton',nnz(sizes==1),'multiple',nnz(sizes>1), ...
                    'set_hash',sm.calibration_hash,'test_seed_base',cfg.seed_test); %#ok<AGROW>
            end
        end
        fprintf('Stage 7A.2 %s: %d candidates; cache %.3f s, new calibration %.3f s, old %.3f s, split %.3f s.\n', ...
            library_name,m,cache.build_time_s,calibration_time,original_t.calibration_time_s, ...
            split_t.set_time_s+split_t.evidence_time_s);
    end
    samples=vertcat(sample_cells{:});distances=vertcat(distance_cells{:});
    curves=vertcat(curve_cells{:});identities=vertcat(identity_cells{:});risks=vertcat(risk_cells{:});
    seeds=vertcat(seed_cells{:});
    summary=summarize(samples);
    writetable(struct2table(samples),fullfile(cfg.output_root,'stage7a2_samples.csv'));
    writetable(struct2table(distances),fullfile(cfg.output_root,'stage7a2_candidate_distances.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_root,'stage7a2_group_summary.csv'));
    writetable(struct2table(curves),fullfile(cfg.output_root,'stage7a2_coverage_size_curve.csv'));
    writetable(struct2table(risks),fullfile(cfg.output_root,'stage7a2_risk_certification.csv'));
    writetable(struct2table(identities),fullfile(cfg.output_root,'stage7a2_calibration_identity.csv'));
    writetable(struct2table(seeds),fullfile(cfg.output_root,'stage7a2_split_seeds.csv'));
    snapshot=cfg;snapshot.output_root=['results/data/stage7a_2/' mode];
    snapshot.figure_root='results/figures/stage7a_2';snapshot.log_root='results/logs/stage7a_2';
    snapshot.stage7a.output_root='results/data/stage7a';snapshot.stage7a.log_root='results/logs/stage7a';
    snapshot.stage7a.stage6b.output_root='results/data/stage6b';
    snapshot.stage7a.stage6b.figure_root='results/figures/stage6b';
    snapshot.stage7a.stage6b.identifiability.stage5b1_model_file= ...
        'results/data/stage5b1/formal/stage5b1_results.mat';
    save(fullfile(cfg.output_root,'stage7a2_config_snapshot.mat'),'snapshot','-v7');
    meta=table(string({'source_commit';'mode';'matlab_version';'computer_arch'; ...
        'use_parallel';'worker_count';'protocol_hash';'sample_rows';'runtime_s'; ...
        'verification_time_utc'}), ...
        string({cfg.source_commit;mode;version;computer('arch');'0';'0'; ...
        stage4a4_scientific_config_hash(snapshot);num2str(numel(samples)); ...
        num2str(toc(whole),17);char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd HH:mm:ss'))}),'VariableNames',{'key','value'});
    writetable(meta,fullfile(cfg.output_root,'stage7a2_metadata.csv'));
    make_figures(curves,summary,cfg,mode);
    result=struct('mode',mode,'status','completed','sample_rows',numel(samples), ...
        'distance_rows',numel(distances),'elapsed_s',toc(whole));
    fprintf('Stage 7A.2 %s: %d sample-method rows, %d candidate-distance rows, %.3f s.\n', ...
        mode,result.sample_rows,result.distance_rows,result.elapsed_s);
end

function rows=seed_rows(block,library_name,split_name)
    n=numel(block.seed);
    rows=repmat(struct('library',library_name,'split',split_name, ...
        'scenario',block.scenario,'seed',0,'truth_candidate_index',NaN, ...
        'truth_signature',''),n,1);
    for k=1:n
        rows(k).seed=block.seed(k);rows(k).truth_candidate_index=block.truth_index(k);
        rows(k).truth_signature=block.truth_signature{k};
    end
end

function out=ungated(model)
    out=model;out.risk_gate.certified=true;
end
function e=conservative_evidence()
    e=struct('beta',1,'margin_threshold',Inf, ...
        'top1_confidence_threshold',Inf,'normalized_entropy_threshold',-Inf, ...
        'reference_sample_count',0,'calibration_hash','insufficient_reference');
end
function x=fixed_quantile(v,q)
    v=sort(v(:));x=v(max(1,min(numel(v),ceil(q*numel(v)))));
end
function extra=library_out_truth(grammar,lib,base)
    g=grammar;g.allowed_branch_main_nodes=[1 2 3];g.max_side_branches_per_node=3;
    g.max_branches=5;g.max_nodes=10;g.max_candidates=128;
    extended=stage6b_build_candidate_library('radial_grammar',g,base,struct());
    known=arrayfun(@(z)stage6b_network_signature(z.network),lib,'UniformOutput',false);
    ix=find(~ismember(arrayfun(@(z)stage6b_network_signature(z.network), ...
        extended,'UniformOutput',false),known),1);
    assert(~isempty(ix),'stage7a2:MissingLibraryOut','No library-out topology found.');
    extra=extended(ix);
end
function block=make_block(lib,truth_pool,cache,base,cfg,q,seed_base,kind,count,snr,scenario)
    m=numel(lib);n=count;
    if strcmp(kind,'balanced'),n=count*numel(truth_pool);end
    block=struct('y',complex(zeros(n,numel(cache.frequency_hz))), ...
        'd',zeros(n,m),'energy',zeros(n,1),'truth_index',NaN(n,1), ...
        'truth_signature',{cell(n,1)},'seed',zeros(n,1),'main_scale',zeros(n,1), ...
        'scenario',scenario,'candidate_count',m);
    for v=1:n
        switch kind
            case 'balanced'
                j=ceil(v/count);rr=mod(v-1,count)+1;seed=seed_base+q*100000+j*1000+rr;
            otherwise
                seed=seed_base+q*100000+v;
                if strcmp(kind,'single'),j=1;
                elseif strcmp(kind,'cyclic'),j=mod(v-1,numel(truth_pool))+1;
                else,j=0;end
        end
        rs=RandStream('mt19937ar','Seed',seed);
        if strcmp(kind,'random'),j=randi(rs,numel(truth_pool));end
        truth=truth_pool(j).network;sig=stage6b_network_signature(truth);
        ix=find(strcmp(cache.candidate_signatures,sig),1);
        if ~isempty(ix),block.truth_index(v)=ix;end
        if strcmp(scenario,'parameter_out')
            if mod(v,2)==1,bounds=cfg.parameter_out_low;else,bounds=cfg.parameter_out_high;end
        else,bounds=cfg.main_bounds;end
        main=bounds(1)+diff(bounds)*rand(rs);
        theta=struct('main_length_scale',main,'branch_length_scale',cfg.stage7a.search.branch_length_scale, ...
            'branch_load_scale',1,'source_impedance_ohm',cfg.stage7a.search.source_impedance_ohm, ...
            'receiver_impedance_ohm',cfg.stage7a.search.receiver_impedance_ohm,'regularization',0);
        clean=stage6b_forward_cfr(truth,theta,base,cfg.stage7a.frequency_hz, ...
            cfg.stage7a.measurement_kind);
        sigma=sqrt(mean(abs(clean).^2)/10^(snr/10)/2);
        y=clean+sigma*(randn(rs,size(clean))+1i*randn(rs,size(clean)));
        profile=stage7a_profile_distance(y,cache,cfg.stage7a.search);
        block.y(v,:)=y;block.d(v,:)=profile.profile_distances;
        block.energy(v)=max(sqrt(mean(abs(y).^2)),eps);
        block.truth_signature{v}=sig;block.seed(v)=seed;block.main_scale(v)=main;
    end
end
function rows=candidate_rows(block,v,ids,signatures,library_name)
    m=numel(ids);rows=repmat(struct('library',library_name,'scenario',block.scenario, ...
        'sample_seed',block.seed(v),'candidate_id','','candidate_signature','', ...
        'profile_distance',NaN,'rank',0,'is_truth',false),m,1);
    [~,order]=sortrows([block.d(v,:).' (1:m).'],[1 2]);rank=zeros(1,m);
    for k=1:m,rank(order(k))=k;end
    for k=1:m
        rows(k).candidate_id=ids{k};rows(k).candidate_signature=signatures{k};
        rows(k).profile_distance=block.d(v,k);rows(k).rank=rank(k);
        rows(k).is_truth=block.truth_index(v)==k;
    end
end
function row=sample_row(block,v,z,method,library_name,m,identity,elapsed)
    if isfield(z,'candidate_set_size'),set_size=z.candidate_set_size;else,set_size=NaN;end
    truth_in_library=isfinite(block.truth_index(v));truth_in_set=false;
    if truth_in_library
        if isfield(z,'candidate_keep'),truth_in_set=z.candidate_keep(block.truth_index(v));
        else
            sets=strsplit(z.candidate_set,',');truth_in_set=any(strcmp(sets,z.best_candidate))&& ...
                z.best_index==block.truth_index(v);
            % Baseline audit already computes exact membership.
            if isfield(z,'truth_in_candidate_set'),truth_in_set=z.truth_in_candidate_set;end
        end
    end
    best_truth=truth_in_library&&z.best_index==block.truth_index(v);
    unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT');
    row=struct('library',library_name,'candidate_count',m,'scenario',block.scenario, ...
        'method',method,'sample_seed',block.seed(v),'truth_signature', ...
        block.truth_signature{v},'truth_candidate_index',block.truth_index(v), ...
        'truth_in_library',truth_in_library,'true_main_scale_audit_only',block.main_scale(v), ...
        'best_index',z.best_index,'best_candidate',z.best_candidate, ...
        'best_is_truth',best_truth,'candidate_set',z.candidate_set, ...
        'candidate_set_size',set_size,'truth_in_candidate_set',truth_in_set, ...
        'decision_state',z.decision_state,'decision_reason',z.decision_reason, ...
        'correct_unique',unique&&best_truth,'false_unique',unique&&~best_truth, ...
        'domain_relative_distance',z.domain_relative_distance, ...
        'domain_threshold',z.domain_threshold,'domain_accepted', ...
        get_domain(z),'d1',get_d1(z),'margin',get_margin(z), ...
        'top1_confidence',z.top1_confidence, ...
        'normalized_entropy',z.normalized_entropy, ...
        'calibration_identity',identity,'decision_time_s',elapsed);
end
function x=get_domain(z)
    if isfield(z,'domain_accepted'),x=z.domain_accepted;else,x=z.domain_pass;end
end
function x=get_d1(z)
    if isfield(z,'distance'),x=z.distance;else,x=z.d1;end
end
function x=get_margin(z)
    if isfield(z,'margin'),x=z.margin;else,x=z.top1_top2_margin;end
end
function summary=summarize(rows)
    keys=unique(strcat(string({rows.library}),"|",string({rows.scenario}),"|", ...
        string({rows.method})),'stable');summary=cell(numel(keys),1);nrows=0;
    for h=1:numel(keys)
        parts=split(keys(h),'|');ix=strcmp({rows.library},char(parts(1)))& ...
            strcmp({rows.scenario},char(parts(2)))&strcmp({rows.method},char(parts(3)));
        group=rows(ix);nrows=nrows+1;summary{nrows}=one_summary(group,'all');
        if strcmp(char(parts(2)),'in_domain')
            classes=unique([group.truth_candidate_index]);
            for j=classes
                subset=group([group.truth_candidate_index]==j);
                nrows=nrows+1;summary{nrows}=one_summary(subset,sprintf('class_%03d',j));
            end
        end
    end
    summary=vertcat(summary{1:nrows});
end
function row=one_summary(g,stratum)
    n=numel(g);sizes=[g.candidate_set_size];states={g.decision_state};
    u=nnz(strcmp(states,'UNIQUE_CONFIDENT'));wrong=nnz([g.false_unique]);
    coverage=nnz([g.truth_in_candidate_set]);inlib=nnz([g.truth_in_library]);
    top1=nnz([g.best_is_truth]);correct=nnz([g.correct_unique]);
    [cl,ch]=wilson(coverage,inlib);[wl,wh]=wilson(wrong,n);[ul,uh]=wilson(u,n);
    [sl,sh]=wilson(wrong,u);
    row=struct('library',g(1).library,'scenario',g(1).scenario, ...
        'method',g(1).method,'stratum',stratum,'n',n,'truth_in_library_n',inlib, ...
        'top1_correct_k',top1,'truth_set_covered_k',coverage, ...
        'set_coverage',safe_div(coverage,inlib),'set_coverage_low95',cl, ...
        'set_coverage_high95',ch,'mean_set_size',mean(sizes), ...
        'median_set_size',median(sizes),'empty_k',nnz(sizes==0), ...
        'singleton_k',nnz(sizes==1),'multiple_k',nnz(sizes>1), ...
        'unique_k',u,'unique_rate',u/n,'unique_rate_low95',ul, ...
        'unique_rate_high95',uh,'correct_unique_k',correct, ...
        'wrong_unique_k',wrong,'false_unique_rate',wrong/n, ...
        'false_unique_low95',wl,'false_unique_high95',wh, ...
        'unique_accuracy',safe_div(correct,u),'selective_error',safe_div(wrong,u), ...
        'selective_error_low95',sl,'selective_error_high95',sh, ...
        'rejected_k',nnz(strcmp(states,'REJECTED')), ...
        'low_confidence_k',nnz(strcmp(states,'LOW_CONFIDENCE')), ...
        'ambiguous_k',nnz(strcmp(states,'MULTIPLE_AMBIGUOUS')), ...
        'domain_rejected_k',nnz(~[g.domain_accepted]), ...
        'mean_decision_time_s',mean([g.decision_time_s]));
end
function value=safe_div(k,n)
    if n==0,value=NaN;else,value=k/n;end
end
function [low,high]=wilson(k,n)
    if n==0,low=NaN;high=NaN;return;end
    z=1.959963984540054;p=k/n;den=1+z^2/n;
    c=(p+z^2/(2*n))/den;r=z*sqrt(p*(1-p)/n+z^2/(4*n^2))/den;
    low=max(0,c-r);high=min(1,c+r);
end
function make_figures(curves,summary,cfg,mode)
    f=figure('Visible','off');hold on;
    libraries={'scale_small','scale_medium','scale_large'};
    labels={'3 candidates','7 candidates','23 candidates'};
    colors=[0 .447 .741;.85 .325 .098];markers={'o','s','^'};
    methods={'M2_class_conditional','M3_pooled_empirical'};
    for h=1:2
        for q=1:3
            ix=strcmp({curves.method},methods{h})&strcmp({curves.library},libraries{q});
            rows=curves(ix);[~,order]=sort([rows.alpha]);rows=rows(order);
            plot([rows.mean_set_size],[rows.coverage],'-','Color',colors(h,:), ...
                'Marker',markers{q},'MarkerFaceColor',colors(h,:), ...
                'DisplayName',sprintf('%s - %s',labels{q}, ...
                ternary(h==1,'class-conditional','pooled empirical')));
        end
    end
    xlabel('Mean candidate set size');ylabel('Truth-set coverage');
    title(['Stage 7A.2 ' mode ' coverage–set size; test seed 550000000']);
    legend('Location','southwest','Interpreter','none');grid on;
    exportgraphics(f,fullfile(cfg.figure_root,['stage7a2_coverage_size_' mode '.png']));close(f);
    ix=strcmp({summary.scenario},'in_domain')&strcmp({summary.stratum},'all');g=summary(ix);
    f=figure('Visible','off');hold on;
    for q=1:3
        ix=strcmp({g.library},libraries{q});
        scatter([g(ix).unique_rate],[g(ix).selective_error],45,'filled', ...
            'DisplayName',labels{q});
    end
    xlabel('Unique output rate');ylabel('Wrong unique / unique outputs');
    title(['Stage 7A.2 ' mode ' selective risk; test seed 550000000']);
    legend('Location','northeast');grid on;
    exportgraphics(f,fullfile(cfg.figure_root,['stage7a2_risk_unique_' mode '.png']));close(f);
end
function out=ternary(tf,a,b)
    if tf,out=a;else,out=b;end
end
