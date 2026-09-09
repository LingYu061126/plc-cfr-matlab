function summary=exp_stage4a7_3_domain_rejection_and_nonunique_validation(root,mode)
%EXP_STAGE4A7_3_DOMAIN_REJECTION_AND_NONUNIQUE_VALIDATION Frozen-domain test.
%   Candidate confirmation is imported as a frozen, truth-free model from
%   R2.1.1.  This experiment calibrates only a separate parameter-domain
%   rejection statistic on independent in-domain scenarios.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config')); base=default_config(root);sc=stage4a7_3_domain_validation_config(base,mode);
    out=fullfile(sc.output_root,mode);ensure_dir(out);ensure_dir(sc.results_logs);t0=tic;
    required={fullfile(sc.source_formal_dir,'summary.mat'),fullfile(sc.source_formal_dir,'checkpoint_identity.mat')};
    for k=1:numel(required),assert(exist(required{k},'file')==2,'stage4a7_3:MissingFrozenInput','Missing frozen input %s.',required{k});end
    z=load(fullfile(sc.source_formal_dir,'summary.mat'),'selected_model','ids');q=load(fullfile(sc.source_formal_dir,'checkpoint_identity.mat'),'cache','scored','ids');
    frozen_model=z.selected_model;cache=q.cache;candidates=q.scored;ids=q.ids;
    assert(numel(cache.candidates)==numel(candidates),'stage4a7_3:CacheCandidateMismatch','Frozen cache and candidates disagree.');
    experiment_hash=stage4a4_scientific_config_hash(struct('stage',sc.stage_name,'config',config_identity(sc),'frozen_experiment_hash',ids.experiment_hash,'frozen_parameter_calibration_hash',frozen_model.calibration_hash));
    % Development compares two predeclared, monotone profile-domain scores.
    dev=materialize_domain('development',sc.scenario_design.development_per_candidate,sc.seeds.development, ...
        {'in_domain','medium_lower_ood','medium_upper_ood'},candidates,cache,base,sc,frozen_model);
    cal=materialize_domain('calibration',sc.scenario_design.calibration_per_candidate,sc.seeds.calibration, ...
        {'in_domain'},candidates,cache,base,sc,frozen_model);
    method_rows=select_domain_method(dev,cal,sc); selected=method_rows(find([method_rows.selected_for_execution],1)).method_id;
    domain_model=stage4a7_3_calibrate_domain_model(score_vector(cal,selected),selected,struct('minimum_count',20,'quantile',sc.parameter_domain.calibration_quantile,'near_boundary_quantile',sc.parameter_domain.near_boundary_quantile));
    cats={'in_domain','exact_lower_boundary','exact_upper_boundary','near_lower_ood','near_upper_ood','medium_lower_ood','medium_upper_ood','far_lower_ood','far_upper_ood'};
    pilot=materialize_domain('pilot',sc.scenario_design.pilot_replicates,sc.seeds.pilot,cats,candidates,cache,base,sc,frozen_model);
    pilot=apply_domain(pilot,domain_model,selected);
    metrics=domain_metrics(pilot,sc,experiment_hash,domain_model.calibration_hash);
    [non_rows,non_metrics,non_audit]=nonunique_control(base,sc,experiment_hash);
    write_rows(fullfile(out,'frozen_config.csv'),config_row(sc,ids,frozen_model,experiment_hash,domain_model));
    % Pilot rows carry post-decision fields; normalize each split before
    % concatenation so the manifest remains an identity-only ledger.
    write_rows(fullfile(out,'scenario_manifest.csv'),[manifest_rows(dev); manifest_rows(cal); manifest_rows(pilot)]);
    write_rows(fullfile(out,'development_method_selection.csv'),method_rows);
    write_rows(fullfile(out,'parameter_domain_calibration.csv'),calibration_rows(cal,domain_model,experiment_hash));
    write_rows(fullfile(out,'paired_domain_validation.csv'),decision_rows(pilot));
    write_rows(fullfile(out,'domain_validation_metrics.csv'),metrics);
    write_rows(fullfile(out,'lower_upper_ood_summary.csv'),metrics(contains({metrics.category},'lower')|contains({metrics.category},'upper')));
    write_rows(fullfile(out,'nonunique_benchmark_ledger.csv'),non_rows);
    write_rows(fullfile(out,'nonunique_equivalence_audit.csv'),non_audit);
    write_rows(fullfile(out,'false_unique_summary.csv'),non_metrics);
    runtime=struct('stage_name',sc.stage_name,'mode',mode,'status',[mode '_completed'],'candidate_count',numel(candidates),'development_count',numel(dev),'calibration_count',numel(cal),'pilot_count',numel(pilot),'nonunique_row_count',numel(non_rows),'worker_count',1,'use_parallel',false,'runtime_s',toc(t0),'experiment_hash',experiment_hash,'frozen_candidate_experiment_hash',ids.experiment_hash,'domain_calibration_hash',domain_model.calibration_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);
    write_rows(fullfile(out,'runtime_summary.csv'),runtime);summary=runtime;write_rows(fullfile(out,'summary.csv'),summary);
    save(fullfile(out,'stage4a7_3_summary.mat'),'summary','sc','domain_model','method_rows','metrics','non_metrics','non_audit','-v7');
    fprintf('Stage 4A.7.3 %s completed: candidates=%d pilot=%d nonunique=%d in %.3f s.\n',mode,numel(candidates),numel(pilot),numel(non_rows),summary.runtime_s);
end

function rows=materialize_domain(split,reps,master,categories,candidates,cache,base,sc,topology_model)
    n=numel(categories)*numel(candidates)*reps;rows=repmat(domain_row(),n,1);ix=0;
    for k=1:numel(candidates),for r=1:reps
        pair_id=sprintf('%s_C%03d_R%02d',split,k,r);seed=stage4a7_2_r2_1_stable_case_seed(master,pair_id);rs=RandStream('mt19937ar','Seed',seed);
        nuisance=theta_in_domain(rs);noise_base=randn(rs,1,numel(cache.frequency_hz))+1i*randn(rs,1,numel(cache.frequency_hz));
        for c=1:numel(categories)
            ix=ix+1;theta=nuisance;theta.main_length_scale=category_value(categories{c},rs,sc.parameter_domain);
            [net,local]=topology_apply_parameters(candidates(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(cache.frequency_hz,net,m,local);truth=v{1}(:).';obs=add_noise_base(truth,sc.noise.snr_db,noise_base);
            p=stage4a7_2_r1_profile_distance({obs},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));a=stage4a7_2_r1_apply_profile_candidate_set(p.profile_distances,topology_model,topology_model.method_id);
            x=domain_row();x.sample_id=sprintf('r73_%s_%s_C%03d_R%02d',split,categories{c},k,r);x.paired_case_id=pair_id;x.split=split;x.category=categories{c};x.candidate_id=getid(candidates(k));x.truth_topology_id=x.candidate_id;x.case_seed=seed;x.main_length_scale=theta.main_length_scale;x.parameter_domain_truth=domain_truth(categories{c});x.dmin=min(p.profile_distances);x.drelative=x.dmin/max(sqrt(mean(abs(obs).^2)),eps);x.topology_set=strjoin(a.accepted_candidate_set,',');x.topology_set_size=a.set_size;x.topology_empty=a.empty;x.topology_hit=any(strcmp(a.accepted_candidate_set,x.truth_topology_id));x.parameter_vector_hash=stage4a4_scientific_config_hash(theta);x.noiseless_cfr_hash=stage4a4_scientific_config_hash(truth);x.observation_hash=stage4a4_scientific_config_hash(obs);x.frozen_topology_calibration_hash=topology_model.calibration_hash;rows(ix)=x;
        end
    end,end
end
function theta=theta_in_domain(rs),theta=struct('main_length_scale',.95+.10*rand(rs),'branch_length_scale',.95+.10*rand(rs),'branch_load_scale',.8+.4*rand(rs),'source_impedance_ohm',45+10*rand(rs),'receiver_impedance_ohm',45+10*rand(rs),'regularization',0);end
function v=category_value(category,rs,p)
    switch category
        case 'in_domain',v=p.lower+(p.upper-p.lower)*rand(rs);
        case 'exact_lower_boundary',v=p.lower;
        case 'exact_upper_boundary',v=p.upper;
        case 'near_lower_ood',v=p.near_lower;
        case 'near_upper_ood',v=p.near_upper;
        case 'medium_lower_ood',v=p.medium_lower;
        case 'medium_upper_ood',v=p.medium_upper;
        case 'far_lower_ood',v=p.far_lower;
        case 'far_upper_ood',v=p.far_upper;
        otherwise,error('stage4a7_3:UnknownCategory','Unknown category %s.',category);
    end
end
function x=domain_truth(c),if contains(c,'ood'),x='out_of_parameter_domain';else,x='in_parameter_domain';end,end
function y=add_noise_base(x,snr,z),if isinf(snr),y=x;else,s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*z;end,end
function v=score_vector(rows,method),if strcmp(method,'profile_min_distance'),v=[rows.dmin];else,v=[rows.drelative];end,end
function rows=select_domain_method(dev,cal,sc)
    methods=sc.parameter_domain.methods;rows=repmat(method_row(),numel(methods),1);
    for k=1:numel(methods)
        m=stage4a7_3_calibrate_domain_model(score_vector(cal,methods{k}),methods{k},struct('minimum_count',20,'quantile',sc.parameter_domain.calibration_quantile,'near_boundary_quantile',sc.parameter_domain.near_boundary_quantile));
        z=apply_domain(dev,m,methods{k});in=strcmp({z.parameter_domain_truth},'in_parameter_domain');ood=~in;mf=ood & cellfun(@(s)contains(s,'medium')||contains(s,'far'),{z.category});
        rows(k).method_id=methods{k};rows(k).in_domain_acceptance=mean([z(in).domain_accepted]);rows(k).medium_far_ood_false_acceptance=mean([z(mf).domain_accepted]);rows(k).threshold=m.threshold;rows(k).near_boundary_threshold=m.near_boundary_threshold;rows(k).gate_pass=rows(k).in_domain_acceptance>=sc.parameter_domain.in_domain_acceptance_floor;rows(k).domain_calibration_hash=m.calibration_hash;
    end
    pass=find([rows.gate_pass]);if isempty(pass),best=1;status='no_method_meets_gate';else,best=pass(1);for k=pass(2:end),if rows(k).medium_far_ood_false_acceptance<rows(best).medium_far_ood_false_acceptance-1e-12,best=k;end,end;status='deterministic_execution_fallback_no_statistical_comparison';end
    tied=find(abs([rows.medium_far_ood_false_acceptance]-rows(best).medium_far_ood_false_acceptance)<=1e-12 & [rows.gate_pass]==rows(best).gate_pass);
    % The domain-score development comparison is deterministic only in this
    % stage.  It selects a reproducible execution score but deliberately
    % makes no unsupported statistical-uniqueness claim.
    for k=1:numel(rows),rows(k).selected_for_execution=k==best;rows(k).scientifically_unique_winner=false;rows(k).selection_status=status;rows(k).tied_methods=strjoin({rows(tied).method_id},',');end
end
function rows=apply_domain(rows,model,method),for k=1:numel(rows),rows(k).domain_method=method;z=stage4a7_3_apply_domain_model(ternary(strcmp(method,'profile_min_distance'),rows(k).dmin,rows(k).drelative),model);rows(k).parameter_domain_status=z.parameter_domain_status;rows(k).domain_accepted=z.domain_accepted;rows(k).domain_score=z.score;rows(k).domain_threshold=z.threshold;rows(k).domain_calibration_hash=z.domain_calibration_hash;end,end
function metrics=domain_metrics(rows,sc,eh,ch)
    cats=unique({rows.category},'stable');metrics=repmat(metric_row(),0,1);for k=1:numel(cats),x=rows(strcmp({rows.category},cats{k}));cid={x.candidate_id};
        metrics(end+1)=rate_metric(cats{k},'topology_truth_coverage',[x.topology_hit],cid,20263170+k,eh,ch); %#ok<AGROW>
        metrics(end+1)=rate_metric(cats{k},'domain_acceptance',[x.domain_accepted],cid,20263200+k,eh,ch); %#ok<AGROW>
        metrics(end+1)=rate_metric(cats{k},'domain_rejection',~[x.domain_accepted],cid,20263230+k,eh,ch); %#ok<AGROW>
        metrics(end+1)=rate_metric(cats{k},'singleton_rate',[x.topology_set_size]==1,cid,20263260+k,eh,ch); %#ok<AGROW>
        metrics(end+1)=rate_metric(cats{k},'empty_set_rate',[x.topology_empty],cid,20263290+k,eh,ch); %#ok<AGROW>
        if strcmp(x(1).parameter_domain_truth,'out_of_parameter_domain'),metrics(end+1)=rate_metric(cats{k},'parameter_ood_false_acceptance',[x.domain_accepted],cid,20263320+k,eh,ch);else,metrics(end+1)=rate_metric(cats{k},'in_domain_parameter_acceptance',[x.domain_accepted],cid,20263320+k,eh,ch);end %#ok<AGROW>
        q=metric_row();q.category=cats{k};q.metric_id='mean_candidate_set_size';q.numerator=sum([x.topology_set_size]);q.denominator=numel(x);q.rate=mean([x.topology_set_size]);q.cluster_count=numel(unique(cid));q.experiment_hash=eh;q.domain_calibration_hash=ch;metrics(end+1)=q; %#ok<AGROW>
    end
end
function q=rate_metric(category,name,success,cid,seed,eh,ch)
    r=stage4a7_3_cluster_rate(success,cid,struct('replicates',1000,'seed',seed,'alpha',.05));q=metric_row();q.category=category;q.metric_id=name;q.numerator=r.numerator;q.denominator=r.denominator;q.rate=r.rate;q.ci_low=r.ci_low;q.ci_high=r.ci_high;q.cluster_count=r.cluster_count;q.experiment_hash=eh;q.domain_calibration_hash=ch;
end
function [rows,metrics,audit]=nonunique_control(base,sc,eh)
    all=topology_candidates(base);ix=ismember({all.id},sc.nonunique.candidate_ids);cand=all(ix);assert(numel(cand)==2,'stage4a7_3:MissingNonuniqueControl','T3/T5 control candidates are required.');grid=topology_parameter_grid(base.stage2_2.search);grid=grid([grid.source_impedance_ohm]==[grid.receiver_impedance_ohm]);f=sc.frequency_hz;cache=control_cache(cand,grid,base,f);
    % T3/T5 is a parameter-specific mirror control: matched end impedances
    % are part of the frozen observation configuration, not a global claim.
    d=max(abs(cache.H{1}(:)-cache.H{2}(:)));rel=d/max(max(abs(cache.H{1}(:))),eps);audit=struct('control_id','T3_T5_siso_mirror','candidate_a','T3','candidate_b','T5','template_count',numel(grid),'equivalence_type','parameter_specific_matched_end_impedance','maximum_absolute_cfr_difference',d,'relative_cfr_difference',rel,'numerical_tolerance',sc.nonunique.numerical_tolerance,'equivalence_status',ternary(d<=sc.nonunique.numerical_tolerance,'parameter_specific_equivalence_verified','not_equivalent'));
    assert(d<=sc.nonunique.numerical_tolerance,'stage4a7_3:NonuniqueControlInvalid','T3/T5 control did not meet numerical equivalence tolerance.');
    calD=[];calI=[];for k=1:numel(cand),for r=1:sc.nonunique.calibration_per_candidate,id=sprintf('r73_non_cal_%d_%d',k,r);rs=RandStream('mt19937ar','Seed',stage4a7_2_r2_1_stable_case_seed(sc.seeds.nonunique_calibration,id));th=theta_in_domain(rs);th.receiver_impedance_ohm=th.source_impedance_ohm;y=control_cfr(cand(k),th,base,f);p=stage4a7_2_r1_profile_distance({y},cache,struct('feature','complex_raw'));calD(end+1,:)=p.profile_distances;calI(end+1,1)=k;end,end %#ok<AGROW>
    model=stage4a7_2_r1_calibrate_profile_method(calD,calI,cache.candidate_ids,'absolute',sc.alpha,struct('minimum_per_candidate',sc.nonunique.calibration_per_candidate,'resolution',eps,'compatibility_hash',eh));
    n=numel(sc.nonunique.noise_levels_db)*sc.nonunique.test_per_noise;rows=repmat(non_row(),n,1);z=0;
    for q=1:numel(sc.nonunique.noise_levels_db),snr=sc.nonunique.noise_levels_db(q);for r=1:sc.nonunique.test_per_noise,z=z+1;id=sprintf('r73_non_%g_%02d',snr,r);rs=RandStream('mt19937ar','Seed',stage4a7_2_r2_1_stable_case_seed(sc.seeds.nonunique_test,id));th=theta_in_domain(rs);th.receiver_impedance_ohm=th.source_impedance_ohm;th.main_length_scale=1+sc.nonunique.parameter_perturbation_fraction*(2*rand(rs)-1);y=control_cfr(cand(1),th,base,f);obs=add_noise_base(y,snr,randn(rs,size(y))+1i*randn(rs,size(y)));p=stage4a7_2_r1_profile_distance({obs},cache,struct('feature','complex_raw'));a=stage4a7_2_r1_apply_profile_candidate_set(p.profile_distances,model,'absolute');accepted_ids=cellstr(a.accepted_candidate_set);rr=non_row();rr.sample_id=id;rr.noise_snr_db=snr;rr.truth_equivalence_set='T3,T5';rr.truth_equivalence_size=2;rr.accepted_set=strjoin(accepted_ids,',');rr.set_size=numel(accepted_ids);rr.contains_any=double(any(ismember(accepted_ids,{'T3','T5'})));rr.contains_complete=double(numel(intersect({'T3','T5'},accepted_ids))==2);rr.false_unique=double((rr.set_size==1)&&(rr.contains_complete==0));rr.parameter_vector_hash=stage4a4_scientific_config_hash(th);rr.noiseless_cfr_hash=stage4a4_scientific_config_hash(y);rr.observation_hash=stage4a4_scientific_config_hash(obs);rr.calibration_hash=model.calibration_hash;rows(z)=rr;end,end
    levels=unique([rows.noise_snr_db],'stable');metrics=repmat(non_metric(),0,1);for q=1:numel(levels),x=rows([rows.noise_snr_db]==levels(q));r=stage4a7_3_cluster_rate([x.false_unique],{x.sample_id},struct('replicates',1000,'seed',20263200+q));m=non_metric();m.noise_snr_db=levels(q);m.false_unique_numerator=r.numerator;m.false_unique_denominator=r.denominator;m.false_unique_rate=r.rate;m.ci_low=r.ci_low;m.ci_high=r.ci_high;m.complete_equivalence_coverage=mean([x.contains_complete]);m.singleton_rate=mean([x.set_size]==1);m.empty_set_rate=mean([x.set_size]==0);m.calibration_hash=model.calibration_hash;metrics(end+1)=m;end
end
function cache=control_cache(cand,grid,base,f),H=cell(1,numel(cand));for k=1:numel(cand),H{k}=zeros(numel(grid),numel(f));for q=1:numel(grid),H{k}(q,:)=control_cfr(cand(k),grid(q),base,f);end,end;ids=arrayfun(@(c)c.id,cand,'UniformOutput',false);cache=struct('frequency_hz',f,'candidate_ids',{ids},'candidates',cand,'theta_grid',grid,'H',{H},'measurement_kind','siso_forward');end
function h=control_cfr(c,theta,base,f),[net,local]=topology_apply_parameters(c.network,base,theta);z=cascade_network_stable(f,net,local);h=z.H_port(:).';end
function r=domain_row(),r=struct('sample_id','','paired_case_id','','split','','category','','candidate_id','','truth_topology_id','','case_seed',0,'main_length_scale',NaN,'parameter_domain_truth','','dmin',NaN,'drelative',NaN,'topology_set','','topology_set_size',0,'topology_empty',false,'topology_hit',false,'domain_method','','domain_score',NaN,'domain_threshold',NaN,'parameter_domain_status','','domain_accepted',false,'domain_calibration_hash','','frozen_topology_calibration_hash','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','');end
function r=method_row(),r=struct('method_id','','in_domain_acceptance',NaN,'medium_far_ood_false_acceptance',NaN,'threshold',NaN,'near_boundary_threshold',NaN,'gate_pass',false,'selected_for_execution',false,'scientifically_unique_winner',false,'selection_status','','tied_methods','','domain_calibration_hash','');end
function r=metric_row(),r=struct('category','','metric_id','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'cluster_count',0,'experiment_hash','','domain_calibration_hash','');end
function r=non_row(),r=struct('sample_id','','noise_snr_db',NaN,'truth_equivalence_set','','truth_equivalence_size',0,'accepted_set','','set_size',0,'contains_any',false,'contains_complete',false,'false_unique',false,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','calibration_hash','');end
function r=non_metric(),r=struct('noise_snr_db',NaN,'false_unique_numerator',0,'false_unique_denominator',0,'false_unique_rate',NaN,'ci_low',NaN,'ci_high',NaN,'complete_equivalence_coverage',NaN,'singleton_rate',NaN,'empty_set_rate',NaN,'calibration_hash','');end
function r=manifest_rows(rows)
    % Build a canonical manifest struct.  `rmfield` retains the historical
    % field order of each split, which prevents concatenation after Pilot
    % rows acquire decision fields.
    r=repmat(manifest_row(),numel(rows),1);f=fieldnames(r);
    for k=1:numel(rows),for j=1:numel(f),r(k).(f{j})=rows(k).(f{j});end,end
end
function r=manifest_row(),r=struct('sample_id','','paired_case_id','','split','','category','','candidate_id','','truth_topology_id','','case_seed',0,'main_length_scale',NaN,'parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','');end
function r=decision_rows(rows),f={'sample_id','paired_case_id','split','category','candidate_id','truth_topology_id','main_length_scale','parameter_domain_truth','topology_set','topology_set_size','topology_empty','topology_hit','domain_method','domain_score','domain_threshold','parameter_domain_status','domain_accepted','domain_calibration_hash','frozen_topology_calibration_hash','parameter_vector_hash','noiseless_cfr_hash','observation_hash'};r=rows;drop=setdiff(fieldnames(r),f);r=rmfield(r,drop);end
function r=calibration_rows(rows,model,eh),r=struct('method_id',model.method_id,'sample_count',numel(rows),'threshold',model.threshold,'near_boundary_threshold',model.near_boundary_threshold,'quantile',model.quantile,'domain_calibration_hash',model.calibration_hash,'experiment_hash',eh,'status',model.status);end
function r=config_row(sc,ids,top,eh,domain),r=struct('stage_name',sc.stage_name,'mode',sc.mode,'frozen_topology_experiment_hash',ids.experiment_hash,'frozen_topology_calibration_hash',top.calibration_hash,'domain_calibration_hash',domain.calibration_hash,'experiment_hash',eh,'source_formal_dir',strrep(sc.source_formal_dir,[fileparts(fileparts(fileparts(sc.source_formal_dir))) filesep],''),'noise_snr_db',sc.noise.snr_db,'worker_count',1,'use_parallel',false,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);end
function x=config_identity(sc),x=sc;for n={'output_root','results_logs','source_formal_dir'},if isfield(x,n{1}),x=rmfield(x,n{1});end,end,end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
