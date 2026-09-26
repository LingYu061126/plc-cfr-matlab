function result=exp_stage7a4_continuous_fit(root,mode)
%EXP_STAGE7A4_CONTINUOUS_FIT Paired grid/continuous weak-pair audit.
%   A/F/C/T/D identities are disjoint. Scoring receives neither truth nor
%   generating parameters. No historical result is written or overwritten.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_continuous_fit_config(base,mode);
    if ~exist(cfg.output_dir,'dir'),mkdir(cfg.output_dir);end
    started=tic;rows=repmat(sample_row(),0,1);
    checks=repmat(check_row(),0,1);design=repmat(design_row(),0,1);
    domains={'on_grid','off_grid'};
    for li=1:numel(cfg.branch_lengths_m)
        [pair,bank]=weak_pair(base,cfg,cfg.branch_lengths_m(li));
        nominal=find(all(abs(bank.params-[1 1 1])<1e-12,2),1);
        gap=sqrt(mean(abs(bank.templates{1}(nominal,:)- ...
            bank.templates{2}(nominal,:)).^2));
        drow=design_row();drow.branch_length_m=cfg.branch_lengths_m(li);
        drow.fixed_rms_difference_ohm=gap;drow.bank_identity=bank.identity;
        drow.signature_1=bank.candidate_signatures{1};
        drow.signature_2=bank.candidate_signatures{2};
        design(end+1)=drow; %#ok<AGROW>
        for di=1:numel(domains)
            domain=domains{di};
            a=clean_split(pair,base,cfg,li,di,cfg.seed_A,domain, ...
                cfg.n_calibration_per_truth);
            f=clean_split(pair,base,cfg,li,di,cfg.seed_F,domain, ...
                cfg.n_calibration_per_truth);
            c=clean_split(pair,base,cfg,li,di,cfg.seed_C,domain, ...
                cfg.n_calibration_per_truth);
            t=clean_split(pair,base,cfg,li,di,cfg.seed_T,domain, ...
                cfg.n_test_per_truth);
            d=clean_split(pair,base,cfg,li,di,cfg.seed_D,domain, ...
                cfg.n_diagnostic_per_truth);
            for i=1:numel(d.truth)
                p=stage7a4_continuous_profile_zin(d.clean(i,:),pair,bank, ...
                    base,cfg,1);
                q=check_row();q.domain=domain;
                q.branch_length_m=cfg.branch_lengths_m(li);
                q.truth_id=bank.candidate_ids{d.truth(i)};
                q.truth_main_scale=d.main_scale(i);
                q.truth_load_scale=d.load_scale(i);
                q.diagnostic_seed=physical_seed(cfg.seed_D,li,di, ...
                    d.truth(i),d.repetition(i));
                q.grid_true_distance_ohm=p.grid_distances(d.truth(i));
                q.continuous_true_distance_ohm=p.continuous_distances(d.truth(i));
                q.grid_best_is_truth=argmin(p.grid_distances)==d.truth(i);
                q.continuous_best_is_truth=argmin(p.continuous_distances)==d.truth(i);
                q.continuous_main_scale=p.continuous_params(d.truth(i),1);
                q.continuous_load_scale=p.continuous_params(d.truth(i),2);
                q.optimizer_exitflag=p.exitflag(d.truth(i));
                checks(end+1)=q; %#ok<AGROW>
            end
            for ri=1:numel(cfg.repeat_counts)
                R=cfg.repeat_counts(ri);sigma=1/sqrt(R);
                [ag,ac]=score_split(a,pair,bank,base,cfg,li,di,ri,cfg.seed_A,sigma);
                [fg,fc]=score_split(f,pair,bank,base,cfg,li,di,ri,cfg.seed_F,sigma);
                [cg,cc]=score_split(c,pair,bank,base,cfg,li,di,ri,cfg.seed_C,sigma);
                [tg,tc,fit]=score_split(t,pair,bank,base,cfg,li,di,ri,cfg.seed_T,sigma);
                all_a={ag,ac};all_f={fg,fc};all_c={cg,cc};all_t={tg,tc};
                models=cell(1,2);thresholds=cell(1,2);
                for profile=1:2
                    models{profile}=stage7a4_calibrate_decision( ...
                        all_a{profile},a.truth,all_f{profile},bank, ...
                        [1 2],1,sigma,cfg,sprintf('%s_L%g_R%d_P%d', ...
                        domain,cfg.branch_lengths_m(li),R,profile));
                    thresholds{profile}=pair_thresholds( ...
                        all_c{profile},c.truth,cfg.alpha, ...
                        numel(cfg.frequency_hz));
                end
                for i=1:numel(t.truth)
                    for profile=1:2
                        distances=all_t{profile}(i,:);
                        for decision=1:2
                            q=sample_row();q.domain=domain;
                            q.branch_length_m=cfg.branch_lengths_m(li);
                            q.fixed_rms_difference_ohm=gap;
                            q.repeat_count=R;q.effective_error_rms_ohm=sigma;
                            q.truth_id=bank.candidate_ids{t.truth(i)};
                            q.truth_main_scale=t.main_scale(i);
                            q.truth_load_scale=t.load_scale(i);
                            q.test_seed=mean_seed(cfg.seed_T,li,di,ri, ...
                                t.truth(i),t.repetition(i));
                            q.distance_1=distances(1);q.distance_2=distances(2);
                            q.best_is_truth=argmin(distances)==t.truth(i);
                            q.grid_distance_truth=tg(i,t.truth(i));
                            q.continuous_distance_truth=tc(i,t.truth(i));
                            q.fit_main_scale=fit(i).continuous_params(t.truth(i),1);
                            q.fit_load_scale=fit(i).continuous_params(t.truth(i),2);
                            q.optimizer_exitflag=fit(i).exitflag(t.truth(i));
                            q.optimizer_evaluations=sum(fit(i).evaluations);
                            q.bank_identity=bank.identity;
                            if profile==1,method_prefix='grid';
                            else,method_prefix='continuous';end
                            if decision==1
                                q.method=[method_prefix '_four_state'];
                                q.calibration_identity=models{profile}.calibration_identity;
                                v=decide_four_state(distances,models{profile});
                                q.decision_state=v.state;
                                q.candidate_set_size=nnz(v.keep);
                                q.truth_covered=v.keep(t.truth(i));
                                q.decision_reason=v.reason;
                            else
                                q.method=[method_prefix '_pair_gap'];
                                q.calibration_identity=thresholds{profile}.identity;
                                s=numel(cfg.frequency_hz)*(distances(2)^2- ...
                                    distances(1)^2);
                                v=decide_pair_gap(s,thresholds{profile});
                                q.decision_state=v.state;
                                q.candidate_set_size=nnz(v.keep);
                                q.truth_covered=v.keep(t.truth(i));
                                q.decision_reason=v.reason;
                            end
                            q.correct_unique=strcmp(q.decision_state, ...
                                'UNIQUE_CONFIDENT')&&q.truth_covered;
                            q.false_unique=strcmp(q.decision_state, ...
                                'UNIQUE_CONFIDENT')&&~q.truth_covered;
                            rows(end+1)=q; %#ok<AGROW>
                        end
                    end
                end
                fprintf('R.2 %s L=%g m R=%d: %d paired T samples, %.2f s elapsed.\n', ...
                    domain,cfg.branch_lengths_m(li),R,numel(t.truth),toc(started));
            end
        end
    end
    summary=summarize(rows,cfg,domains);
    frontier=make_frontier(summary,design,cfg,domains);
    writetable(struct2table(design),fullfile(cfg.output_dir,'continuous_design.csv'));
    writetable(struct2table(checks),fullfile(cfg.output_dir,'continuous_clean_diagnostics.csv'));
    writetable(struct2table(rows),fullfile(cfg.output_dir,'continuous_samples.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_dir,'continuous_summary.csv'));
    writetable(struct2table(frontier),fullfile(cfg.output_dir,'continuous_frontier.csv'));
    runtime_s=toc(started);
    metadata=table(string(cfg.verification_baseline_commit),string(mode), ...
        string(version),string(computer('arch')),cfg.worker_count, ...
        cfg.n_calibration_per_truth,cfg.n_test_per_truth, ...
        cfg.single_read_error_rms_ohm,runtime_s, ...
        'VariableNames',{'verification_baseline_commit','mode', ...
        'matlab_version','computer_arch','worker_count', ...
        'calibration_n_per_truth','test_n_per_truth', ...
        'single_read_error_rms_ohm','runtime_s'});
    writetable(metadata,fullfile(cfg.output_dir,'continuous_metadata.csv'));
    save(fullfile(cfg.output_dir,'continuous_config_snapshot.mat'),'cfg', ...
        'metadata','-v7');
    source_identity(root,cfg.output_dir,cfg);
    fprintf('Stage 7A.4-R.2 %s completed: %d sample-method rows, %.3f s.\n', ...
        mode,numel(rows),runtime_s);
    result=struct('status','completed','runtime_s',runtime_s, ...
        'summary',summary,'frontier',frontier,'output_dir',cfg.output_dir);
end

function [pair,bank]=weak_pair(base,cfg,length_m)
    [all4,~,~]=stage7a4_fixed_topologies(base);
    pair=all4([3 4]);pair(1).topology_id='WEAK_M1';
    pair(2).topology_id='WEAK_M3';
    for k=1:2
        pair(k).network.branches.length=length_m;
        pair(k).network.branches.load=cfg.branch_load_ohm;
    end
    [m,l]=ndgrid(cfg.main_scale_grid,cfg.branch_load_grid);
    params=[m(:),l(:),ones(numel(m),1)];
    templates=cell(2,1);nf=numel(cfg.frequency_hz);
    for k=1:2
        templates{k}=complex(zeros(size(params,1),nf));
        for p=1:size(params,1)
            theta=theta_at(params(p,1),params(p,2));
            z=stage7a4_forward_state(pair(k).network,theta,base, ...
                cfg.frequency_hz,cfg.state);
            templates{k}(p,:)=z.Zin;
        end
    end
    ids={pair.topology_id};
    signatures=arrayfun(@(x)stage6b_network_signature(x.network),pair, ...
        'UniformOutput',false);
    identity=stage4a4_scientific_config_hash(struct('ids',{ids}, ...
        'signatures',{signatures},'params',params, ...
        'frequency_hz',cfg.frequency_hz,'state',cfg.state,'view','Zin50'));
    bank=struct('templates',{templates},'params',params, ...
        'candidate_ids',{ids},'candidate_signatures',{signatures}, ...
        'view_names',{{'Zin50'}},'frequency_hz',cfg.frequency_hz, ...
        'identity',identity);
end

function theta=theta_at(main,load)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end

function block=clean_split(pair,base,cfg,li,di,seed_base,domain,n_each)
    n=2*n_each;nf=numel(cfg.frequency_hz);
    block=struct('clean',complex(zeros(n,nf)),'truth',zeros(n,1), ...
        'main_scale',zeros(n,1),'load_scale',zeros(n,1), ...
        'repetition',zeros(n,1));
    i=0;
    for truth=1:2
        for rep=1:n_each
            i=i+1;rs=RandStream('mt19937ar','Seed', ...
                physical_seed(seed_base,li,di,truth,rep));
            main=1;load=1;
            if strcmp(domain,'off_grid')
                main=cfg.offgrid_main_bounds(1)+ ...
                    diff(cfg.offgrid_main_bounds)*rand(rs);
                load=cfg.offgrid_load_bounds(1)+ ...
                    diff(cfg.offgrid_load_bounds)*rand(rs);
            end
            z=stage7a4_forward_state(pair(truth).network, ...
                theta_at(main,load),base,cfg.frequency_hz,cfg.state);
            block.clean(i,:)=z.Zin;block.truth(i)=truth;
            block.main_scale(i)=main;block.load_scale(i)=load;
            block.repetition(i)=rep;
        end
    end
end

function [grid_d,continuous_d,fit]=score_split(block,pair,bank,base, ...
        cfg,li,di,ri,seed_base,sigma)
    n=numel(block.truth);grid_d=zeros(n,2);continuous_d=zeros(n,2);
    fit=repmat(struct('continuous_params',zeros(2,2), ...
        'exitflag',zeros(1,2),'evaluations',zeros(1,2)),n,1);
    for i=1:n
        rs=RandStream('mt19937ar','Seed',mean_seed(seed_base,li,di,ri, ...
            block.truth(i),block.repetition(i)));
        y=block.clean(i,:)+sigma/sqrt(2)* ...
            (randn(rs,1,size(block.clean,2))+ ...
            1i*randn(rs,1,size(block.clean,2)));
        v=stage7a4_continuous_profile_zin(y,pair,bank,base,cfg,sigma);
        grid_d(i,:)=v.grid_distances;
        continuous_d(i,:)=v.continuous_distances;
        fit(i).continuous_params=v.continuous_params;
        fit(i).exitflag=v.exitflag;
        fit(i).evaluations=v.evaluations;
    end
end

function seed=physical_seed(seed_base,li,di,truth,rep)
    seed=seed_base+li*1000000+di*100000+truth*1000+rep;
end
function seed=mean_seed(seed_base,li,di,ri,truth,rep)
    seed=seed_base+li*1000000+di*100000+ri*10000+truth*1000+rep;
end
function k=argmin(values)
    [~,k]=min(values);
end

function t=pair_thresholds(d,truth,alpha,nf)
    s=nf*(d(:,2).^2-d(:,1).^2);
    second=sort(s(truth==2));first=sort(s(truth==1));
    n2=numel(second);n1=numel(first);
    upper=min(n2,ceil((n2+1)*(1-alpha)));
    lower=max(1,floor((n1+1)*alpha));
    t=struct('first',max(0,second(upper)), ...
        'second',min(0,first(lower)), ...
        'identity',stage4a4_scientific_config_hash(struct( ...
        'scores',s,'truth',truth,'alpha',alpha)));
end

function v=decide_pair_gap(s,t)
    if s>t.first
        v=struct('state','UNIQUE_CONFIDENT','keep',[true false], ...
            'reason','pair_score_above_first_gate');
    elseif s<t.second
        v=struct('state','UNIQUE_CONFIDENT','keep',[false true], ...
            'reason','pair_score_below_second_gate');
    else
        v=struct('state','MULTIPLE_AMBIGUOUS','keep',[true true], ...
            'reason','pair_score_between_gates');
    end
end

function v=decide_four_state(d,model)
    keep=d<=model.class_threshold;
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
    v=struct('state',state,'keep',keep,'reason',reason);
end

function out=summarize(rows,cfg,domains)
    methods={'grid_four_state','continuous_four_state', ...
        'grid_pair_gap','continuous_pair_gap'};
    groups={'ALL','WEAK_M1','WEAK_M3'};
    out=repmat(summary_row(),0,1);
    for li=1:numel(cfg.branch_lengths_m)
        for di=1:numel(domains)
            for ri=1:numel(cfg.repeat_counts)
                for mi=1:numel(methods)
                    for gi=1:numel(groups)
                        mask=[rows.branch_length_m]==cfg.branch_lengths_m(li)& ...
                            strcmp({rows.domain},domains{di})& ...
                            [rows.repeat_count]==cfg.repeat_counts(ri)& ...
                            strcmp({rows.method},methods{mi});
                        if gi>1,mask=mask&strcmp({rows.truth_id},groups{gi});end
                        x=rows(mask);n=numel(x);assert(n>0);
                        kc=nnz([x.correct_unique]);kf=nnz([x.false_unique]);
                        [cl,ch]=stage7a4_wilson(kc,n);
                        [fl,fh]=stage7a4_wilson(kf,n);
                        q=summary_row();q.branch_length_m=cfg.branch_lengths_m(li);
                        q.fixed_rms_difference_ohm=x(1).fixed_rms_difference_ohm;
                        q.domain=domains{di};q.repeat_count=cfg.repeat_counts(ri);
                        q.method=methods{mi};q.truth_group=groups{gi};q.n=n;
                        q.correct_unique_k=kc;q.correct_unique_low95=cl;
                        q.correct_unique_high95=ch;q.false_unique_k=kf;
                        q.false_unique_low95=fl;q.false_unique_high95=fh;
                        q.best_is_truth_k=nnz([x.best_is_truth]);
                        q.truth_covered_k=nnz([x.truth_covered]);
                        q.unique_k=nnz(strcmp({x.decision_state},'UNIQUE_CONFIDENT'));
                        q.ambiguous_k=nnz(strcmp({x.decision_state},'MULTIPLE_AMBIGUOUS'));
                        q.low_confidence_k=nnz(strcmp({x.decision_state},'LOW_CONFIDENCE'));
                        q.rejected_k=nnz(strcmp({x.decision_state},'REJECTED'));
                        q.mean_true_distance_grid=mean([x.grid_distance_truth]);
                        q.mean_true_distance_continuous= ...
                            mean([x.continuous_distance_truth]);
                        q.optimizer_failure_k=nnz([x.optimizer_exitflag]<=0);
                        out(end+1)=q; %#ok<AGROW>
                    end
                end
            end
        end
    end
end

function out=make_frontier(summary,design,cfg,domains)
    methods={'grid_four_state','continuous_four_state', ...
        'grid_pair_gap','continuous_pair_gap'};
    out=repmat(frontier_row(),0,1);
    for di=1:numel(domains)
        for ri=1:numel(cfg.repeat_counts)
            for mi=1:numel(methods)
                q=frontier_row();q.domain=domains{di};
                q.repeat_count=cfg.repeat_counts(ri);q.method=methods{mi};
                for li=1:numel(cfg.branch_lengths_m)
                    x=summary(strcmp({summary.domain},domains{di})& ...
                        [summary.repeat_count]==cfg.repeat_counts(ri)& ...
                        strcmp({summary.method},methods{mi})& ...
                        [summary.branch_length_m]==cfg.branch_lengths_m(li)& ...
                        ~strcmp({summary.truth_group},'ALL'));
                    assert(numel(x)==2);
                    n=[x.n];pass=all([x.correct_unique_k]>=ceil(.9*n))&& ...
                        all([x.false_unique_k]<=floor(.05*n));
                    if pass
                        q.passing_grid_count=q.passing_grid_count+1;
                        gap=design(li).fixed_rms_difference_ohm;
                        if isnan(q.smallest_tested_difference_ohm)|| ...
                                gap<q.smallest_tested_difference_ohm
                            q.smallest_tested_difference_ohm=gap;
                            q.branch_length_m=cfg.branch_lengths_m(li);
                        end
                    end
                end
                out(end+1)=q; %#ok<AGROW>
            end
        end
    end
end

function source_identity(root,out,cfg)
    paths={'config/stage7a4_continuous_fit_config.m', ...
        'docs/stage7a4_continuous_fit_protocol.md', ...
        'experiments/exp_stage7a4_continuous_fit.m', ...
        'src/stage7a4_continuous_profile_zin.m', ...
        'run_stage7a4_continuous_fit.m', ...
        'tests/test_stage7a4_continuous_fit.m'};
    x=repmat(struct('relative_path','','sha256','', ...
        'size_bytes',0,'verification_baseline_commit',''),numel(paths),1);
    for i=1:numel(paths)
        p=fullfile(root,strrep(paths{i},'/',filesep));d=dir(p);
        assert(numel(d)==1,'stage7a4r2:MissingSource','Missing %s',paths{i});
        x(i)=struct('relative_path',paths{i}, ...
            'sha256',stage4a7_2_r2_sha256_file(p), ...
            'size_bytes',d.bytes, ...
            'verification_baseline_commit',cfg.verification_baseline_commit);
    end
    writetable(struct2table(x),fullfile(out,'continuous_source_identity.csv'));
end

function r=sample_row()
    r=struct('domain','','branch_length_m',NaN, ...
        'fixed_rms_difference_ohm',NaN,'repeat_count',0, ...
        'effective_error_rms_ohm',NaN,'method','','truth_id','', ...
        'truth_main_scale',NaN,'truth_load_scale',NaN,'test_seed',0, ...
        'distance_1',NaN,'distance_2',NaN,'best_is_truth',false, ...
        'grid_distance_truth',NaN,'continuous_distance_truth',NaN, ...
        'fit_main_scale',NaN,'fit_load_scale',NaN, ...
        'optimizer_exitflag',0,'optimizer_evaluations',0, ...
        'decision_state','','decision_reason','', ...
        'candidate_set_size',0,'truth_covered',false, ...
        'correct_unique',false,'false_unique',false, ...
        'bank_identity','','calibration_identity','');
end
function r=check_row()
    r=struct('domain','','branch_length_m',NaN,'truth_id','', ...
        'truth_main_scale',NaN,'truth_load_scale',NaN, ...
        'diagnostic_seed',0,'grid_true_distance_ohm',NaN, ...
        'continuous_true_distance_ohm',NaN, ...
        'grid_best_is_truth',false,'continuous_best_is_truth',false, ...
        'continuous_main_scale',NaN,'continuous_load_scale',NaN, ...
        'optimizer_exitflag',0);
end
function r=design_row()
    r=struct('branch_length_m',NaN, ...
        'fixed_rms_difference_ohm',NaN,'bank_identity','', ...
        'signature_1','','signature_2','');
end
function r=summary_row()
    r=struct('branch_length_m',NaN, ...
        'fixed_rms_difference_ohm',NaN,'domain','', ...
        'repeat_count',0,'method','','truth_group','', ...
        'n',0,'correct_unique_k',0,'correct_unique_low95',NaN, ...
        'correct_unique_high95',NaN,'false_unique_k',0, ...
        'false_unique_low95',NaN,'false_unique_high95',NaN, ...
        'best_is_truth_k',0,'truth_covered_k',0, ...
        'unique_k',0,'ambiguous_k',0,'low_confidence_k',0, ...
        'rejected_k',0,'mean_true_distance_grid',NaN, ...
        'mean_true_distance_continuous',NaN,'optimizer_failure_k',0);
end
function r=frontier_row()
    r=struct('domain','','repeat_count',0,'method','', ...
        'passing_grid_count',0, ...
        'smallest_tested_difference_ohm',NaN, ...
        'branch_length_m',NaN);
end
