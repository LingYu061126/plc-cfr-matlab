function out=exp_stage7a4_15m_continuous(root,mode)
%EXP_STAGE7A4_15M_CONTINUOUS Paired grid/continuous mirror and library test.
%   All truth/true parameters remain in this experiment; scoring takes only
%   observed spectra, candidate bank, fixed physical states and calibration.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_15m_continuous_config(base,mode);
    if ~exist(cfg.output_dir,'dir'),mkdir(cfg.output_dir);end
    started=tic;[all4,pair,original]=stage7a4_fixed_topologies(base);
    bank=stage7a4_template_bank(all4,base,cfg);
    schemes=scheme_list();trigger_pair=node_trigger(bank,pair,cfg.near_equal_tolerance);
    trigger_original=node_trigger(bank,original,cfg.near_equal_tolerance);
    fprintf('MATLAB %s %s; bank=%s, cache=%d bytes, C trigger pair/original=%d/%d\n', ...
        version,computer('arch'),bank.identity,bank.logical_cache_bytes, ...
        trigger_pair,trigger_original);
    rows=repmat(sample_row(),0,1);calrows=repmat(cal_row(),0,1);
    audit=repmat(audit_row(),0,1);condition_number=0;
    for ri=1:numel(cfg.parameter_regimes)
        regime=cfg.parameter_regimes{ri};
        for si=1:numel(cfg.snr_values)
            condition_number=condition_number+1;snr=cfg.snr_values(si);
            e=make_split(all4,base,cfg,cfg.seed_E,condition_number, ...
                cfg.n_E_per_topology,snr,regime,'nominal');
            a=make_split(all4,base,cfg,cfg.seed_A,condition_number, ...
                cfg.n_A_per_topology,snr,regime,'nominal');
            f=make_split(all4,base,cfg,cfg.seed_F,condition_number, ...
                cfg.n_F_per_topology,snr,regime,'nominal');
            t=make_split(all4,base,cfg,cfg.seed_T,condition_number, ...
                cfg.n_T_per_topology,snr,regime,'nominal');
            sigma=stage7a4_calibrate_view_scales(e,cfg);
            sa=score_batch(a,all4,bank,base,cfg,schemes,sigma);
            sf=score_batch(f,all4,bank,base,cfg,schemes,sigma);
            [st,fit_t]=score_batch(t,all4,bank,base,cfg,schemes,sigma);
            [models,cr]=calibrate(sa,a,sf,f,schemes,bank, ...
                sigma,cfg,regime,snr,pair,original,trigger_pair,trigger_original);
            calrows=[calrows;cr(:)]; %#ok<AGROW>
            rows=[rows;make_rows(st,fit_t,t,models,schemes,bank,regime,snr, ...
                pair,original,trigger_pair,trigger_original,'nominal')]; %#ok<AGROW>
            if strcmp(regime,'off_off') && snr==20
                variants={'zin_rms_0p3','zin_rms_3', ...
                    'zin_correlated_1','zin_fixed_bias_1'};
                for vi=1:numel(variants)
                    stress=make_split(all4,base,cfg,cfg.seed_T+20000000, ...
                        condition_number*10+vi,cfg.n_T_per_topology, ...
                        snr,regime,variants{vi});
                    [ss,fit_s]=score_batch(stress,all4,bank,base,cfg,schemes,sigma, ...
                        [2 3 5 6]);
                    rows=[rows;make_rows(ss,fit_s,stress,models,schemes,bank, ...
                        regime,snr,pair,original,trigger_pair, ...
                        trigger_original,variants{vi})]; %#ok<AGROW>
                end
            end
            fprintf('%s %g dB: E/A/F/T %d/%d/%d/%d; elapsed %.2f s\n', ...
                regime,snr,numel(e),numel(a),numel(f),numel(t),toc(started));
        end
    end
    % D is disjoint from E/A/F/T and never changes the frozen scorer.
    d=make_split(all4,base,cfg,cfg.seed_D,1, ...
        cfg.n_D_per_topology,20,'off_off','nominal');
    sigma=ones(1,numel(cfg.view_names));
    for i=1:numel(d)
        for j=1:numel(schemes)
            views=schemes(j).views;
            for v=views
                if startsWith(cfg.view_names{v},'Zin'),sigma(v)=cfg.zin_error_rms_ohm;
                else,sigma(v)=sqrt(mean(abs(d(i).clean{v}).^2))/10;end
            end
            p1=stage7a4_15m_profile(d(i).observed,all4,bank,base,cfg, ...
                1:4,views,sigma,1);
            p3=stage7a4_15m_profile(d(i).observed,all4,bank,base,cfg, ...
                1:4,views,sigma,3);
            q=audit_row();q.seed=d(i).noise_seed;q.truth_id=all4(d(i).truth).topology_id;
            q.scheme=schemes(j).name;q.single_best=argmin(p1.continuous_distances);
            q.multistart_best=argmin(p3.continuous_distances);
            q.max_distance_improvement=max(p1.continuous_distances- ...
                p3.continuous_distances);q.ranking_changed=q.single_best~=q.multistart_best;
            audit(end+1)=q; %#ok<AGROW>
        end
    end
    summary=summarize(rows);
    writetable(struct2table(rows),fullfile(cfg.output_dir,'samples.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_dir,'summary.csv'));
    writetable(struct2table(calrows),fullfile(cfg.output_dir,'calibration.csv'));
    writetable(struct2table(audit),fullfile(cfg.output_dir,'multistart_audit.csv'));
    runtime_s=toc(started);
    meta=table(string(cfg.verification_baseline_commit),string(bank.identity), ...
        string(version),string(computer('arch')),runtime_s, ...
        bank.logical_cache_bytes,bank.forward_calls,0,trigger_pair,trigger_original, ...
        'VariableNames',{'baseline_commit','bank_identity','matlab_version', ...
        'computer_arch','runtime_s','cache_bytes','grid_forward_calls', ...
        'parallel_workers','C_trigger_pair','C_trigger_original'});
    writetable(meta,fullfile(cfg.output_dir,'metadata.csv'));
    save(fullfile(cfg.output_dir,'config_snapshot.mat'),'cfg','meta','-v7');
    artifact_inventory(cfg.output_dir,root);
    source_inventory(cfg.output_dir,root);
    fprintf('Stage 7A.4 15m %s complete: %d rows, %.2f s\n', ...
        mode,numel(rows),runtime_s);
    out=struct('summary',summary,'runtime_s',runtime_s, ...
        'output_dir',cfg.output_dir,'audit',audit);
end

function s=scheme_list()
    names={'H50','Zin50','H50_Zin50','H25','Zin25','H25_Zin25', ...
        'M2_node','M2_direct_joint'};
    views={5,6,[5 6],3,4,[3 4],14,[13 14]};
    s=repmat(struct('name','','views',[]),1,numel(names));
    for j=1:numel(s),s(j).name=names{j};s(j).views=views{j};end
end

function tf=node_trigger(bank,indices,tol)
    tf=false;h=bank.templates;
    for i=1:numel(indices)
        for j=i+1:numel(indices)
            x=h{indices(i),13};y=h{indices(j),13};
            rel=max(abs(x-y),[],'all')/max(sqrt(mean(abs(x).^2,'all')),eps);
            if rel<=tol,tf=true;return;end
        end
    end
end

function samples=make_split(all4,base,cfg,seedbase,condition,n,snr,regime,variant)
    proto=struct('truth',0,'parameter_seed',0,'noise_seed',0, ...
        'true_main',NaN,'true_load',NaN,'clean',{cell(1,numel(cfg.view_names))}, ...
        'observed',{cell(1,numel(cfg.view_names))});
    samples=repmat(proto,4*n,1);ix=0;
    for truth=1:4
        for rep=1:n
            ix=ix+1;seed=seedbase+condition*1000000+truth*1000+rep;
            rs=RandStream('mt19937ar','Seed',seed);
            main=1;load=1;
            if startsWith(regime,'off'),main=0.98+0.04*rand(rs);end
            if endsWith(regime,'off'),load=0.8+0.4*rand(rs);end
            theta=struct('main_length_scale',main,'branch_length_scale',1, ...
                'branch_load_scale',load,'first_segment_scale',1, ...
                'source_impedance_ohm',50,'receiver_impedance_ohm',50);
            ns=seed+100000000;
            [clean,observed]=stage7a4_measure_views(all4(truth).network, ...
                theta,base,cfg,ns,snr);
            if ~strcmp(variant,'nominal')
                zin=[4 6];r2=RandStream('mt19937ar','Seed',ns+200000000);
                for v=zin
                    switch variant
                        case 'zin_rms_0p3',err=0.3/sqrt(2)* ...
                                (randn(r2,size(clean{v}))+1i*randn(r2,size(clean{v})));
                        case 'zin_rms_3',err=3/sqrt(2)* ...
                                (randn(r2,size(clean{v}))+1i*randn(r2,size(clean{v})));
                        case 'zin_correlated_1'
                            white=(randn(r2,size(clean{v}))+1i*randn(r2,size(clean{v})))/sqrt(2);
                            smooth=conv(white,ones(1,7)/7,'same');
                            err=smooth/max(sqrt(mean(abs(smooth).^2)),eps);
                        case 'zin_fixed_bias_1',err=ones(size(clean{v}))*exp(1i*pi/4);
                        otherwise,error('stage7a4_15m:UnknownStress');
                    end
                    observed{v}=clean{v}+err;
                end
            end
            samples(ix)=struct('truth',truth,'parameter_seed',seed, ...
                'noise_seed',ns,'true_main',main,'true_load',load, ...
                'clean',{clean},'observed',{observed});
        end
    end
end

function [scores,fits]=score_batch(samples,all4,bank,base,cfg,schemes,sigma,active)
    if nargin<8,active=1:numel(schemes);end
    scores=nan(numel(samples),4,numel(schemes),2);
    fits=struct('main',nan(numel(samples),4,numel(schemes),2), ...
        'load',nan(numel(samples),4,numel(schemes),2), ...
        'evaluations',zeros(numel(samples),4,numel(schemes)));
    for i=1:numel(samples)
        for j=active
            p=stage7a4_15m_profile(samples(i).observed,all4,bank,base, ...
                cfg,1:4,schemes(j).views,sigma,1);
            scores(i,:,j,1)=p.grid_distances;
            scores(i,:,j,2)=p.continuous_distances;
            fits.main(i,:,j,1)=p.grid_params(:,1).';
            fits.main(i,:,j,2)=p.continuous_params(:,1).';
            fits.load(i,:,j,1)=p.grid_params(:,2).';
            fits.load(i,:,j,2)=p.continuous_params(:,2).';
            fits.evaluations(i,:,j)=p.evaluations;
        end
    end
end

function [models,rows]=calibrate(sa,a,sf,f,schemes,bank,sigma,cfg,regime, ...
        snr,pair,original,tp,to)
    rows=repmat(cal_row(),0,1);models=cell(9,2,2);
    libraries={pair,original};library_names={'pair','original_three'};
    for lib=1:2
        ix=libraries{lib};at=ismember([a.truth],ix);ft=ismember([f.truth],ix);
        atruth=arrayfun(@(x)find(ix==x,1),[a(at).truth]).';
        for method=1:2
            active=bank;if method==2,active.identity=[bank.identity '_continuous_v1'];end
            for scheme=1:9
                source=scheme;if scheme==9
                    trigger=tp;if lib==2,trigger=to;end
                    if trigger,source=7;else,source=8;end
                end
                views=schemes(source).views;
                ad=reshape(sa(at,ix,source,method),nnz(at),numel(ix));
                fd=reshape(sf(ft,ix,source,method),nnz(ft),numel(ix));
                label_name=schemes(source).name;
                if scheme==9,label_name='M2_node_dominance';end
                label=sprintf('%s_%gdB_%s_%s_%d',regime,snr, ...
                    library_names{lib},label_name,method);
                model=stage7a4_calibrate_decision(ad,atruth,fd,active,ix, ...
                    views,sigma,cfg,label);
                models{scheme,lib,method}=model;
                q=cal_row();q.regime=regime;q.snr_db=snr;
                q.scheme=label_name;
                q.profile=profile_name(method);q.library=library_names{lib};
                q.E_seed=cfg.seed_E;q.A_seed=cfg.seed_A;q.F_seed=cfg.seed_F;
                q.class_thresholds=mat2str(model.class_threshold,16);
                q.fit_threshold=model.fit_threshold;
                q.calibration_identity=model.calibration_identity;
                q.bank_identity=active.identity;q.actual_views=mat2str(views);
                rows(end+1)=q; %#ok<AGROW>
            end
        end
    end
end

function rows=make_rows(scores,fits,samples,models,schemes,bank,regime,snr, ...
        pair,original,tp,to,variant)
    all_schemes=1:9;
    if ~strcmp(variant,'nominal'),all_schemes=[2 3 5 6];end
    rows=repmat(sample_row(),numel(samples)*2*2*numel(all_schemes),1);cursor=0;
    libraries={pair,original};library_names={'pair','original_three'};
    for i=1:numel(samples)
        for lib=1:2
            ix=libraries{lib};trigger=tp;if lib==2,trigger=to;end
            if lib==1 && ~ismember(samples(i).truth,pair),continue;end
            for method=1:2
                for scheme=all_schemes
                    source=scheme;
                    if scheme==9
                        if trigger,source=7;else,source=8;end
                    end
                    d=reshape(scores(i,ix,source,method),1,[]);
                    model=models{scheme,lib,method};z=decide_distances(d,model);
                    cursor=cursor+1;q=sample_row();q.regime=regime;q.snr_db=snr;
                    q.variant=variant;q.scheme=schemes(source).name;
                    if scheme==9,q.scheme='M2_node_dominance';end
                    q.profile=profile_name(method);q.library=library_names{lib};
                    q.truth_id=bank.candidate_ids{samples(i).truth};
                    q.truth_in_library=ismember(samples(i).truth,ix);
                    q.parameter_seed=samples(i).parameter_seed;
                    q.noise_seed=samples(i).noise_seed;
                    q.true_main=samples(i).true_main;q.true_load=samples(i).true_load;
                    q.distance_1=d(1);q.distance_2=d(2);
                    if numel(d)>2,q.distance_3=d(3);end
                    q.best_candidate=z.best_candidate;q.candidate_set=z.candidate_set;
                    best_global=ix(find(strcmp(bank.candidate_ids(ix), ...
                        z.best_candidate),1));
                    q.fit_main=fits.main(i,best_global,source,method);
                    q.fit_load=fits.load(i,best_global,source,method);
                    q.optimizer_evaluations=sum(fits.evaluations(i,ix,source));
                    q.set_size=z.candidate_set_size;q.state=z.decision_state;
                    q.reason=z.decision_reason;q.fit_threshold=model.fit_threshold;
                    q.class_thresholds=mat2str(model.class_threshold,16);
                    q.calibration_identity=model.calibration_identity;
                    if q.truth_in_library
                        q.truth_covered=any(strcmp(strsplit(z.candidate_set,','),q.truth_id));
                        q.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                            strcmp(z.best_candidate,q.truth_id);
                        q.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                            ~strcmp(z.best_candidate,q.truth_id);
                    else
                        q.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT');
                    end
                    rows(cursor)=q;
                end
            end
        end
    end
    rows=rows(1:cursor);
end

function z=decide_distances(d,model)
    keep=d<=model.class_threshold;ids=model.candidate_ids;
    [sorted,order]=sort(d);margin=sorted(2)-sorted(1);
    if sorted(1)>model.fit_threshold
        state='REJECTED';reason='fit_quality_gate';
    elseif ~any(keep)
        state='REJECTED';reason='empty_candidate_set';
    elseif nnz(keep)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif ~keep(order(1))||margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    z=struct('best_candidate',ids{order(1)},'candidate_set', ...
        strjoin(ids(keep),','),'candidate_set_size',nnz(keep), ...
        'decision_state',state,'decision_reason',reason);
end

function summary=summarize(rows)
    summary=repmat(summary_row(),0,1);
    keys=cell(numel(rows),1);
    for i=1:numel(rows)
        x=rows(i);keys{i}=sprintf('%s|%g|%s|%s|%s|%s|%s', ...
            x.regime,x.snr_db,x.variant,x.scheme,x.profile,x.library,x.truth_id);
    end
    [unique_keys,~,group]=unique(keys,'stable');
    for g=1:numel(unique_keys)
        r=rows(group==g);x=r(1);n=numel(r);q=summary_row();
        q.regime=x.regime;q.snr_db=x.snr_db;q.variant=x.variant;
        q.scheme=x.scheme;q.profile=x.profile;q.library=x.library;
        q.truth_id=x.truth_id;q.n=n;q.truth_in_library=x.truth_in_library;
        q.correct_unique_k=nnz([r.correct_unique]);
        q.false_unique_k=nnz([r.false_unique]);
        q.truth_covered_k=nnz([r.truth_covered]);
        q.nonempty_k=nnz([r.set_size]>0);
        q.ambiguous_k=nnz(strcmp({r.state},'MULTIPLE_AMBIGUOUS'));
        q.low_confidence_k=nnz(strcmp({r.state},'LOW_CONFIDENCE'));
        q.rejected_k=nnz(strcmp({r.state},'REJECTED'));
        q.mean_set_size=mean([r.set_size]);
        [q.correct_unique_ci_low,q.correct_unique_ci_high]= ...
            stage7a4_wilson(q.correct_unique_k,n);
        [q.false_unique_ci_low,q.false_unique_ci_high]= ...
            stage7a4_wilson(q.false_unique_k,n);
        q.calibration_identity=x.calibration_identity;
        summary(end+1)=q; %#ok<AGROW>
    end
end

function name=profile_name(method)
    if method==1,name='grid45';else,name='continuous';end
end
function i=argmin(x),[~,i]=min(x);end

function q=sample_row()
    q=struct('regime','','snr_db',NaN,'variant','','scheme','', ...
        'profile','','library','','truth_id','','truth_in_library',false, ...
        'parameter_seed',0,'noise_seed',0,'true_main',NaN,'true_load',NaN, ...
        'fit_main',NaN,'fit_load',NaN,'optimizer_evaluations',0, ...
        'distance_1',NaN,'distance_2',NaN,'distance_3',NaN, ...
        'best_candidate','','candidate_set','','set_size',0,'state','', ...
        'reason','','fit_threshold',NaN,'class_thresholds','', ...
        'truth_covered',false,'correct_unique',false,'false_unique',false, ...
        'calibration_identity','');
end
function q=cal_row()
    q=struct('regime','','snr_db',NaN,'scheme','','profile','', ...
        'library','','E_seed',0,'A_seed',0,'F_seed',0, ...
        'class_thresholds','','fit_threshold',NaN, ...
        'calibration_identity','','bank_identity','','actual_views','');
end
function q=audit_row()
    q=struct('seed',0,'truth_id','','scheme','','single_best',0, ...
        'multistart_best',0,'max_distance_improvement',NaN,'ranking_changed',false);
end
function q=summary_row()
    q=struct('regime','','snr_db',NaN,'variant','','scheme','', ...
        'profile','','library','','truth_id','','n',0, ...
        'truth_in_library',false,'correct_unique_k',0,'false_unique_k',0, ...
        'truth_covered_k',0,'nonempty_k',0,'ambiguous_k',0, ...
        'low_confidence_k',0,'rejected_k',0,'mean_set_size',NaN, ...
        'correct_unique_ci_low',NaN,'correct_unique_ci_high',NaN, ...
        'false_unique_ci_low',NaN,'false_unique_ci_high',NaN, ...
        'calibration_identity','');
end
function artifact_inventory(folder,root)
    names={'samples.csv','summary.csv','calibration.csv', ...
        'multistart_audit.csv','metadata.csv','config_snapshot.mat'};
    rows=table('Size',[numel(names) 3], ...
        'VariableTypes',{'string','string','double'}, ...
        'VariableNames',{'relative_path','sha256','size_bytes'});
    for i=1:numel(names)
        p=fullfile(folder,names{i});info=dir(p);
        rows.relative_path(i)=string(strrep(p,[root filesep],''));
        rows.sha256(i)=string(stage4a7_2_r2_sha256_file(p));
        rows.size_bytes(i)=info.bytes;
    end
    writetable(rows,fullfile(folder,'artifact_manifest.csv'));
end
function source_inventory(folder,root)
    names={'config/stage7a4_15m_continuous_config.m', ...
        'src/stage7a4_15m_profile.m', ...
        'experiments/exp_stage7a4_15m_continuous.m', ...
        'run_stage7a4_15m_continuous.m', ...
        'tests/test_stage7a4_15m_continuous.m', ...
        'docs/stage7a4_15m_continuous_protocol.md'};
    rows=table('Size',[numel(names) 3], ...
        'VariableTypes',{'string','string','double'}, ...
        'VariableNames',{'relative_path','sha256','size_bytes'});
    for i=1:numel(names)
        p=fullfile(root,strrep(names{i},'/',filesep));info=dir(p);
        rows.relative_path(i)=string(names{i});
        rows.sha256(i)=string(stage4a7_2_r2_sha256_file(p));
        rows.size_bytes(i)=info.bytes;
    end
    writetable(rows,fullfile(folder,'source_inventory.csv'));
end
