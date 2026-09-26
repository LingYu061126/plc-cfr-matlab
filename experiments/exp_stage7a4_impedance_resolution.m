function result=exp_stage7a4_impedance_resolution(root,mode)
%EXP_STAGE7A4_IMPEDANCE_RESOLUTION Pair-only weak-stub resolution audit.
%   A/F/C/T have disjoint seeds. Scoring sees complex Zin, templates and
%   calibrated models; it never receives the generating label or theta.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_impedance_resolution_config(base,mode);
    if ~exist(cfg.output_dir,'dir'),mkdir(cfg.output_dir);end
    t0=tic;design=repmat(design_row(),0,1);
    samples=repmat(sample_row(),0,1);
    domains={'on_grid','off_grid'};methods={'stage7a4_four_state','pair_likelihood_gap'};
    for li=1:numel(cfg.branch_lengths_m)
        length_m=cfg.branch_lengths_m(li);
        [pair,bank]=weak_pair(base,cfg,length_m);
        gap=stage7a4_information_distance(bank,[1 2],1,1);
        fixed=bank.templates{1,1}(nominal_index(bank),:)- ...
            bank.templates{2,1}(nominal_index(bank),:);
        dr=design_row();dr.branch_length_m=length_m;
        dr.branch_load_ohm=cfg.branch_load_ohm;
        dr.fixed_rms_difference_ohm=gap.fixed_abs_rms_per_view;
        dr.profile_min_difference_ohm=gap.min_joint_distance;
        dr.min_single_frequency_difference_ohm=min(abs(fixed));
        dr.max_single_frequency_difference_ohm=max(abs(fixed));
        dr.candidate_1=pair(1).topology_id;dr.candidate_2=pair(2).topology_id;
        dr.signature_1=bank.candidate_signatures{1};
        dr.signature_2=bank.candidate_signatures{2};
        dr.bank_identity=bank.identity;design(end+1)=dr; %#ok<AGROW>
        for di=1:numel(domains)
            domain=domains{di};
            cleanA=clean_split(pair,base,cfg,li,di,cfg.seed_A,domain);
            cleanF=clean_split(pair,base,cfg,li,di,cfg.seed_F,domain);
            cleanC=clean_split(pair,base,cfg,li,di,cfg.seed_C,domain);
            cleanT=clean_split(pair,base,cfg,li,di,cfg.seed_T,domain);
            for ri=1:numel(cfg.repeat_counts)
                repeats=cfg.repeat_counts(ri);sigma=cfg.single_read_error_rms_ohm/sqrt(repeats);
                ya=add_mean_noise(cleanA,cfg,li,di,ri,cfg.seed_A,sigma);
                yf=add_mean_noise(cleanF,cfg,li,di,ri,cfg.seed_F,sigma);
                yc=add_mean_noise(cleanC,cfg,li,di,ri,cfg.seed_C,sigma);
                yt=add_mean_noise(cleanT,cfg,li,di,ri,cfg.seed_T,sigma);
                da=distance_matrix(ya,bank,sigma);df=distance_matrix(yf,bank,sigma);
                dc=distance_matrix(yc,bank,sigma);
                model=stage7a4_calibrate_decision(da,cleanA.truth,df,bank, ...
                    [1 2],1,sigma,cfg,sprintf('R1_%s_L%g_R%d',domain,length_m,repeats));
                thresholds=pair_thresholds(dc,cleanC.truth,cfg.alpha, ...
                    numel(cfg.frequency_hz));
                for i=1:size(yt,1)
                    z=stage7a4_decide({yt(i,:)},bank,model);
                    s=numel(cfg.frequency_hz)*(z.all_distances(2)^2-z.all_distances(1)^2);
                    r=sample_row();r.domain=domain;r.branch_length_m=length_m;
                    r.fixed_rms_difference_ohm=dr.fixed_rms_difference_ohm;
                    r.repeat_count=repeats;r.effective_error_rms_ohm=sigma;
                    r.truth_id=bank.candidate_ids{cleanT.truth(i)};
                    r.truth_main_scale=cleanT.main_scale(i);
                    r.truth_load_scale=cleanT.load_scale(i);
                    r.test_seed=mean_seed(cfg.seed_T,li,di,ri,cleanT.truth(i), ...
                        cleanT.repetition(i));
                    r.distance_1=z.all_distances(1);r.distance_2=z.all_distances(2);
                    r.likelihood_gap=s;r.bank_identity=bank.identity;
                    r.calibration_identity=model.calibration_identity;
                    r.threshold_1=thresholds.first;r.threshold_2=thresholds.second;
                    r.method=methods{1};r.decision_state=z.decision_state;
                    r.candidate_set_size=z.candidate_set_size;
                    r.best_is_truth=strcmp(z.best_candidate,r.truth_id);
                    r.truth_covered=contains_id(z.candidate_set,r.truth_id);
                    r.correct_unique=strcmp(r.decision_state,'UNIQUE_CONFIDENT')&&r.best_is_truth;
                    r.false_unique=strcmp(r.decision_state,'UNIQUE_CONFIDENT')&&~r.best_is_truth;
                    samples(end+1)=r; %#ok<AGROW>
                    q=r;q.method=methods{2};q.calibration_identity=thresholds.identity;
                    if s>thresholds.first
                        q.decision_state='UNIQUE_CONFIDENT';q.candidate_set_size=1;
                        q.truth_covered=cleanT.truth(i)==1;
                        q.correct_unique=cleanT.truth(i)==1;
                        q.false_unique=cleanT.truth(i)==2;
                    elseif s<thresholds.second
                        q.decision_state='UNIQUE_CONFIDENT';q.candidate_set_size=1;
                        q.truth_covered=cleanT.truth(i)==2;
                        q.correct_unique=cleanT.truth(i)==2;
                        q.false_unique=cleanT.truth(i)==1;
                    else
                        q.decision_state='MULTIPLE_AMBIGUOUS';q.candidate_set_size=2;
                        q.truth_covered=true;q.correct_unique=false;q.false_unique=false;
                    end
                    samples(end+1)=q; %#ok<AGROW>
                end
                fprintf('R.1 %s L=%g m R=%d: %d test samples, %.2f s elapsed.\n', ...
                    domain,length_m,repeats,size(yt,1),toc(t0));
            end
        end
    end
    summary=summarize(samples,cfg,domains,methods);
    frontier=frontier_rows(summary,design,cfg,domains,methods);
    writetable(struct2table(design),fullfile(cfg.output_dir,'resolution_design.csv'));
    writetable(struct2table(samples),fullfile(cfg.output_dir,'resolution_samples.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_dir,'resolution_summary.csv'));
    writetable(struct2table(frontier),fullfile(cfg.output_dir,'resolution_frontier.csv'));
    runtime_s=toc(t0);
    meta=table(string(cfg.verification_baseline_commit),string(mode),string(version), ...
        string(computer('arch')),cfg.worker_count,cfg.n_per_truth, ...
        cfg.single_read_error_rms_ohm,numel(cfg.frequency_hz),runtime_s, ...
        'VariableNames',{'verification_baseline_commit','mode','matlab_version', ...
        'computer_arch','worker_count','samples_per_truth_per_split', ...
        'single_read_error_rms_ohm','frequency_points','runtime_s'});
    writetable(meta,fullfile(cfg.output_dir,'resolution_metadata.csv'));
    save(fullfile(cfg.output_dir,'resolution_config_snapshot.mat'),'cfg','meta','-v7');
    write_source_identity(root,cfg.output_dir,cfg);
    fprintf('Stage 7A.4-R.1 %s completed: %d sample-method rows, %.3f s.\n', ...
        mode,numel(samples),runtime_s);
    result=struct('status','completed','mode',mode,'runtime_s',runtime_s, ...
        'design',design,'summary',summary,'frontier',frontier, ...
        'output_dir',cfg.output_dir);
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
        templates{k,1}=complex(zeros(size(params,1),nf));
        for p=1:size(params,1)
            theta=theta_at(params(p,1),params(p,2));
            z=stage7a4_forward_state(pair(k).network,theta,base, ...
                cfg.frequency_hz,cfg.state);
            templates{k,1}(p,:)=z.Zin;
        end
    end
    ids={pair.topology_id};
    sig=arrayfun(@(x)stage6b_network_signature(x.network),pair,'UniformOutput',false);
    identity=stage4a4_scientific_config_hash(struct('ids',{ids}, ...
        'signatures',{sig},'params',params,'frequency_hz',cfg.frequency_hz, ...
        'state',cfg.state,'view','Zin50'));
    bank=struct('templates',{templates},'params',params, ...
        'candidate_ids',{ids},'candidate_signatures',{sig}, ...
        'view_names',{{'Zin50'}},'frequency_hz',cfg.frequency_hz, ...
        'identity',identity);
end

function idx=nominal_index(bank)
    idx=find(all(abs(bank.params-[1 1 1])<1e-12,2),1);
    assert(~isempty(idx),'stage7a4r1:NominalMissing');
end

function theta=theta_at(main,load)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end

function block=clean_split(pair,base,cfg,li,di,seed_base,domain)
    n=2*cfg.n_per_truth;nf=numel(cfg.frequency_hz);
    block=struct('clean',complex(zeros(n,nf)),'truth',zeros(n,1), ...
        'main_scale',zeros(n,1),'load_scale',zeros(n,1), ...
        'repetition',zeros(n,1));
    k=0;
    for truth=1:2
        for rep=1:cfg.n_per_truth
            k=k+1;seed=physical_seed(seed_base,li,di,truth,rep);
            rs=RandStream('mt19937ar','Seed',seed);
            main=1;load=1;
            if strcmp(domain,'off_grid')
                main=cfg.offgrid_main_bounds(1)+ ...
                    diff(cfg.offgrid_main_bounds)*rand(rs);
                load=cfg.offgrid_load_bounds(1)+ ...
                    diff(cfg.offgrid_load_bounds)*rand(rs);
            end
            z=stage7a4_forward_state(pair(truth).network,theta_at(main,load), ...
                base,cfg.frequency_hz,cfg.state);
            block.clean(k,:)=z.Zin;block.truth(k)=truth;
            block.main_scale(k)=main;block.load_scale(k)=load;
            block.repetition(k)=rep;
        end
    end
end

function y=add_mean_noise(block,cfg,li,di,ri,seed_base,sigma)
    y=block.clean;
    for i=1:size(y,1)
        seed=mean_seed(seed_base,li,di,ri,block.truth(i),block.repetition(i));
        rs=RandStream('mt19937ar','Seed',seed);
        y(i,:)=y(i,:)+sigma/sqrt(2)*(randn(rs,1,size(y,2))+ ...
            1i*randn(rs,1,size(y,2)));
    end
    assert(abs(sigma-cfg.single_read_error_rms_ohm/ ...
        sqrt(cfg.repeat_counts(ri)))<1e-12);
end

function seed=physical_seed(seed_base,li,di,truth,rep)
    seed=seed_base+li*1000000+di*100000+truth*1000+rep;
end

function seed=mean_seed(seed_base,li,di,ri,truth,rep)
    seed=seed_base+li*1000000+di*100000+ri*10000+truth*1000+rep;
end

function d=distance_matrix(y,bank,sigma)
    d=zeros(size(y,1),2);
    for i=1:size(y,1)
        p=stage7a4_profile_views({y(i,:)},bank,[1 2],1,sigma);
        d(i,:)=p.distances;
    end
end

function t=pair_thresholds(d,truth,alpha,nf)
    score=nf*(d(:,2).^2-d(:,1).^2);
    under2=sort(score(truth==2));under1=sort(score(truth==1));
    n2=numel(under2);n1=numel(under1);
    top=min(n2,ceil((n2+1)*(1-alpha)));
    bottom=max(1,floor((n1+1)*alpha));
    first=max(0,under2(top));second=min(0,under1(bottom));
    t=struct('first',first,'second',second, ...
        'identity',stage4a4_scientific_config_hash(struct( ...
        'calibration_scores',score,'truth',truth,'alpha',alpha, ...
        'first',first,'second',second)));
end

function yes=contains_id(set_text,id)
    if isempty(set_text),yes=false;return;end
    yes=any(strcmp(strsplit(set_text,','),id));
end

function rows=summarize(samples,cfg,domains,methods)
    rows=repmat(summary_row(),0,1);
    groups={'ALL','WEAK_M1','WEAK_M3'};
    for di=1:numel(domains)
        for li=1:numel(cfg.branch_lengths_m)
            for ri=1:numel(cfg.repeat_counts)
                for mi=1:numel(methods)
                    for gi=1:numel(groups)
                        mask=strcmp({samples.domain},domains{di})& ...
                            [samples.branch_length_m]==cfg.branch_lengths_m(li)& ...
                            [samples.repeat_count]==cfg.repeat_counts(ri)& ...
                            strcmp({samples.method},methods{mi});
                        if gi>1,mask=mask&strcmp({samples.truth_id},groups{gi});end
                        x=samples(mask);n=numel(x);
                        assert(n>0,'stage7a4r1:EmptySummary');
                        kcorrect=nnz([x.correct_unique]);kwrong=nnz([x.false_unique]);
                        [cl,ch]=stage7a4_wilson(kcorrect,n);
                        [wl,wh]=stage7a4_wilson(kwrong,n);
                        q=summary_row();q.domain=domains{di};
                        q.branch_length_m=cfg.branch_lengths_m(li);
                        q.fixed_rms_difference_ohm=x(1).fixed_rms_difference_ohm;
                        q.repeat_count=cfg.repeat_counts(ri);q.method=methods{mi};
                        q.truth_group=groups{gi};q.n=n;
                        q.correct_unique_k=kcorrect;q.correct_unique_rate=kcorrect/n;
                        q.correct_unique_low95=cl;q.correct_unique_high95=ch;
                        q.false_unique_k=kwrong;q.false_unique_rate=kwrong/n;
                        q.false_unique_low95=wl;q.false_unique_high95=wh;
                        q.truth_covered_k=nnz([x.truth_covered]);
                        q.best_is_truth_k=nnz([x.best_is_truth]);
                        q.mean_candidate_set_size=mean([x.candidate_set_size]);
                        q.unique_k=nnz(strcmp({x.decision_state},'UNIQUE_CONFIDENT'));
                        q.ambiguous_k=nnz(strcmp({x.decision_state},'MULTIPLE_AMBIGUOUS'));
                        q.low_confidence_k=nnz(strcmp({x.decision_state},'LOW_CONFIDENCE'));
                        q.rejected_k=nnz(strcmp({x.decision_state},'REJECTED'));
                        rows(end+1)=q; %#ok<AGROW>
                    end
                end
            end
        end
    end
end

function rows=frontier_rows(summary,design,cfg,domains,methods)
    rows=repmat(frontier_row(),0,1);
    for di=1:numel(domains)
        for ri=1:numel(cfg.repeat_counts)
            for mi=1:numel(methods)
                best=Inf;bestL=NaN;pass_count=0;
                for li=1:numel(cfg.branch_lengths_m)
                    x=summary(strcmp({summary.domain},domains{di})& ...
                        [summary.branch_length_m]==cfg.branch_lengths_m(li)& ...
                        [summary.repeat_count]==cfg.repeat_counts(ri)& ...
                        strcmp({summary.method},methods{mi})& ...
                        ~strcmp({summary.truth_group},'ALL'));
                    assert(numel(x)==2,'stage7a4r1:FrontierGroups');
                    n=[x.n];pass=all([x.correct_unique_k]>=ceil(.9*n))&& ...
                        all([x.false_unique_k]<=floor(.05*n));
                    if pass
                        pass_count=pass_count+1;
                        gap=design(li).fixed_rms_difference_ohm;
                        if gap<best,best=gap;bestL=cfg.branch_lengths_m(li);end
                    end
                end
                q=frontier_row();q.domain=domains{di};
                q.repeat_count=cfg.repeat_counts(ri);q.method=methods{mi};
                q.passing_grid_count=pass_count;
                if isfinite(best),q.smallest_tested_difference_ohm=best;end
                q.branch_length_m=bestL;rows(end+1)=q; %#ok<AGROW>
            end
        end
    end
end

function write_source_identity(root,out,cfg)
    paths={'config/stage7a4_impedance_resolution_config.m', ...
        'docs/stage7a4_impedance_resolution_protocol.md', ...
        'experiments/exp_stage7a4_impedance_resolution.m', ...
        'run_stage7a4_impedance_resolution.m', ...
        'tests/test_stage7a4_impedance_resolution.m'};
    rows=repmat(struct('relative_path','','sha256','', ...
        'size_bytes',0,'verification_baseline_commit',''),numel(paths),1);
    for i=1:numel(paths)
        p=fullfile(root,strrep(paths{i},'/',filesep));d=dir(p);
        assert(numel(d)==1,'stage7a4r1:MissingSource','Missing %s',paths{i});
        rows(i)=struct('relative_path',paths{i}, ...
            'sha256',stage4a7_2_r2_sha256_file(p), ...
            'size_bytes',d.bytes, ...
            'verification_baseline_commit',cfg.verification_baseline_commit);
    end
    writetable(struct2table(rows),fullfile(out,'resolution_source_identity.csv'));
end

function r=design_row()
    r=struct('branch_length_m',NaN,'branch_load_ohm',NaN, ...
        'fixed_rms_difference_ohm',NaN,'profile_min_difference_ohm',NaN, ...
        'min_single_frequency_difference_ohm',NaN, ...
        'max_single_frequency_difference_ohm',NaN, ...
        'candidate_1','','candidate_2','','signature_1','', ...
        'signature_2','','bank_identity','');
end
function r=sample_row()
    r=struct('domain','','branch_length_m',NaN, ...
        'fixed_rms_difference_ohm',NaN,'repeat_count',0, ...
        'effective_error_rms_ohm',NaN,'method','', ...
        'truth_id','','truth_main_scale',NaN,'truth_load_scale',NaN, ...
        'test_seed',0,'distance_1',NaN,'distance_2',NaN, ...
        'likelihood_gap',NaN,'threshold_1',NaN,'threshold_2',NaN, ...
        'decision_state','','candidate_set_size',0,'best_is_truth',false, ...
        'truth_covered',false,'correct_unique',false,'false_unique',false, ...
        'bank_identity','','calibration_identity','');
end
function r=summary_row()
    r=struct('domain','','branch_length_m',NaN, ...
        'fixed_rms_difference_ohm',NaN,'repeat_count',0,'method','', ...
        'truth_group','','n',0,'correct_unique_k',0, ...
        'correct_unique_rate',NaN,'correct_unique_low95',NaN, ...
        'correct_unique_high95',NaN,'false_unique_k',0, ...
        'false_unique_rate',NaN,'false_unique_low95',NaN, ...
        'false_unique_high95',NaN,'truth_covered_k',0, ...
        'best_is_truth_k',0,'mean_candidate_set_size',NaN, ...
        'unique_k',0,'ambiguous_k',0,'low_confidence_k',0,'rejected_k',0);
end
function r=frontier_row()
    r=struct('domain','','repeat_count',0,'method','', ...
        'passing_grid_count',0,'smallest_tested_difference_ohm',NaN, ...
        'branch_length_m',NaN);
end
