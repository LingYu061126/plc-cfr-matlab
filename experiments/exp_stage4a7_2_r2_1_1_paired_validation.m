function summary=exp_stage4a7_2_r2_1_1_paired_validation(root,formal_dir,outdir)
%EXP_STAGE4A7_2_R2_1_1_PAIRED_VALIDATION Paired category validation.
%   For each candidate and replicate, nuisance parameters and a normalized
%   noise realization are held fixed across six target categories.  The
%   target parameter is the only designed category change.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));base=default_config(root);sc=stage4a7_2_r2_1_1_protocol_config(base,'formal');
    if nargin<2||isempty(formal_dir),formal_dir=fullfile(root,'results','data','stage4a7_2_r2_1_1','formal');end
    if nargin<3||isempty(outdir),outdir=fullfile(root,'results','data','stage4a7_2_r2_1_1','paired');end
    ensure_dir(outdir);
    z=load(fullfile(formal_dir,'summary.mat'),'sc','selected_model','ids');q=load(fullfile(formal_dir,'checkpoint_identity.mat'),'cache','scored','ids');
    model=z.selected_model;cache=q.cache;candidates=q.scored;ids=q.ids;
    paired_hash=stage4a4_scientific_config_hash(struct('formal_experiment_hash',ids.experiment_hash,'paired_design',sc.paired,'noise',sc.noise,'stage','Stage 4A.7.2-R.2.1.1-paired'));
    cats=sc.paired.categories;vals=sc.paired.values;reps=sc.paired.replicates;n=numel(candidates)*numel(cats)*reps;
    rows=repmat(row_template(),n,1);D=zeros(n,numel(candidates));t0=tic;ix=0;
    for k=1:numel(candidates)
        for rep=1:reps
            pair_id=sprintf('paired_C%03d_R%02d',k,rep);case_seed=stage4a7_2_r2_1_stable_case_seed(sc.paired.master_seed,pair_id);rs=RandStream('mt19937ar','Seed',case_seed);
            nuisance=offgrid_theta(rs);noise_base=randn(rs,1,numel(sc.frequency_hz))+1i*randn(rs,1,numel(sc.frequency_hz));
            for c=1:numel(cats)
                ix=ix+1;sample_id=sprintf('r211_paired_%s_C%03d_R%02d',cats{c},k,rep);theta=nuisance;theta.main_length_scale=vals(c);
                [net,local]=topology_apply_parameters(candidates(k).network,base,theta);[m,~]=plc_measurement_bundle(sc.measurement_kind,net,theta,local);[v,~]=plc_multiview_response(sc.frequency_hz,net,m,local);truth=v{1}(:).';
                sig=sqrt(mean(abs(truth).^2)/10^(sc.noise.snr_db/10)/2);obs=truth+sig*noise_base;
                o=stage4a7_2_r1_profile_distance({obs},cache,struct('feature',sc.feature,'ofdm_config',base.ofdm));D(ix,:)=o.profile_distances;
                a=stage4a7_2_r1_apply_profile_candidate_set(D(ix,:),model,model.method_id);
                r=rows(ix);r.sample_id=sample_id;r.paired_case_id=pair_id;r.category=cats{c};r.replicate=rep;r.candidate_id=getid(candidates(k));r.case_seed=case_seed;r.nuisance_seed=case_seed;r.noise_base_hash=stage4a4_scientific_config_hash(noise_base);r.truth_theta=theta;r.truth_topology_id=getid(candidates(k));r.accepted_set=strjoin(a.accepted_candidate_set,',');r.set_size=a.set_size;r.empty=a.empty;r.hit=any(strcmp(a.accepted_candidate_set,r.truth_topology_id));r.parameter_domain_truth=ternary(startsWith(cats{c},'parameter_ood'),'out_of_domain','in_domain');r.main_length_scale=theta.main_length_scale;r.parameter_vector_hash=stage4a4_scientific_config_hash(theta);r.noiseless_cfr_hash=stage4a4_scientific_config_hash(truth);r.observation_hash=stage4a4_scientific_config_hash(obs);r.calibration_hash=a.calibration_hash;r.experiment_hash=paired_hash;rows(ix)=r;
            end
        end
        if mod(k,10)==0||k==numel(candidates),fprintf('R2.1.1 paired %d/%d candidates, %d/%d rows.\n',k,numel(candidates),ix,n);end
    end
    assert(ix==n,'Paired row count mismatch.');
    write_rows(fullfile(outdir,'paired_scenario_manifest.csv'),manifest_rows(rows));write_rows(fullfile(outdir,'paired_decisions.csv'),decision_rows(rows));
    write_rows(fullfile(outdir,'paired_metrics.csv'),metrics(rows,sc,paired_hash,model.calibration_hash));write_rows(fullfile(outdir,'paired_balance_audit.csv'),balance(rows));
    write_rows(fullfile(outdir,'independence_audit.csv'),independence(rows));
    cfgrow=struct('stage_name','Stage 4A.7.2-R.2.1.1','status','paired_completed','candidate_count',numel(candidates),'category_count',numel(cats),'replicate_count',reps,'scenario_count',n,'target_parameter',sc.paired.target_parameter,'master_seed',sc.paired.master_seed,'noise_snr_db',sc.noise.snr_db,'selected_method',model.method_id,'source_tree_hash',ids.source_tree_hash,'data_provenance_hash',ids.data_provenance_hash,'candidate_library_hash',ids.candidate_library_hash,'configuration_hash',ids.configuration_hash,'template_cache_hash',ids.template_cache_hash,'formal_experiment_hash',ids.experiment_hash,'experiment_hash',paired_hash,'parameter_calibration_hash',model.calibration_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false);
    write_rows(fullfile(outdir,'configuration_manifest.csv'),cfgrow);runtime=struct('status','paired_completed','scenario_count',n,'candidate_count',numel(candidates),'runtime_s',toc(t0),'worker_count',1,'use_parallel',false,'formal_experiment_hash',ids.experiment_hash,'experiment_hash',paired_hash,'parameter_calibration_hash',model.calibration_hash);write_rows(fullfile(outdir,'runtime_summary.csv'),runtime);
    summary=struct('stage_name','Stage 4A.7.2-R.2.1.1','status','paired_completed','scenario_count',n,'candidate_count',numel(candidates),'category_count',numel(cats),'replicate_count',reps,'selected_method',model.method_id,'formal_experiment_hash',ids.experiment_hash,'experiment_hash',paired_hash,'parameter_calibration_hash',model.calibration_hash,'final_reserved_status',sc.final_reserved.status,'stage4b_started',false,'elapsed_s',runtime.runtime_s);write_rows(fullfile(outdir,'summary.csv'),summary);save(fullfile(outdir,'summary.mat'),'summary','rows','sc','runtime','-v7');
end

function t=offgrid_theta(rs),t=struct('main_length_scale',.95+.1*rand(rs),'branch_length_scale',.95+.1*rand(rs),'branch_load_scale',.8+.4*rand(rs),'source_impedance_ohm',45+10*rand(rs),'receiver_impedance_ohm',45+10*rand(rs),'regularization',0);end
function rows=manifest_rows(s)
rows=repmat(struct('sample_id','','paired_case_id','','category','','replicate',0,'candidate_id','','case_seed',0,'nuisance_seed',0,'noise_base_hash','','truth_topology_id','','main_length_scale',NaN,'parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','experiment_hash','','calibration_hash',''),numel(s),1);
for k=1:numel(s),f=fieldnames(rows);for q=1:numel(f),rows(k).(f{q})=s(k).(f{q});end,end
end
function rows=decision_rows(s)
rows=repmat(struct('sample_id','','paired_case_id','','category','','replicate',0,'candidate_id','','truth_topology_id','','accepted_set','','set_size',0,'hit',false,'empty',false,'experiment_hash','','calibration_hash','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash',''),numel(s),1);
for k=1:numel(s),f=fieldnames(rows);for q=1:numel(f),rows(k).(f{q})=s(k).(f{q});end,end
end
function rows=metrics(s,sc,eh,ch),cats=unique({s.category},'stable');rows=repmat(metric_template(),0,1);for k=1:numel(cats),x=s(strcmp({s.category},cats{k}));n=numel(x);acc=~[x.empty];hit=[x.hit];wrong=acc&~hit;sizes=[x.set_size];rows(end+1)=metric_row(cats{k},'truth_set_coverage',nnz(hit),n,eh,ch);rows(end+1)=metric_row(cats{k},'topology_acceptance_coverage',nnz(acc),n,eh,ch);rows(end+1)=metric_row(cats{k},'topology_selective_risk',nnz(wrong),nnz(acc),eh,ch);rows(end+1)=metric_row(cats{k},'singleton_rate',nnz(sizes==1),n,eh,ch);rows(end+1)=metric_row(cats{k},'empty_set_rate',nnz(~acc),n,eh,ch);r=metric_template();r.category=cats{k};r.metric_id='mean_set_size';r.numerator=sum(sizes);r.denominator=n;r.rate=mean(sizes);r.evaluable_count=n;r.mean_set_size=mean(sizes);r.median_set_size=median(sizes);r.experiment_hash=eh;r.calibration_hash=ch;rows(end+1)=r;end,end
function r=metric_row(c,m,a,b,eh,ch),r=metric_template();r.category=c;r.metric_id=m;r.numerator=a;r.denominator=b;r.rate=ratio(a,b);r.evaluable_count=b;if b>0,[r.ci_low,r.ci_high]=stage4a7_2_wilson_interval(a,b);end;r.experiment_hash=eh;r.calibration_hash=ch;end
function r=metric_template(),r=struct('category','','metric_id','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'evaluable_count',0,'mean_set_size',NaN,'median_set_size',NaN,'experiment_hash','','calibration_hash','');end
function rows=balance(s),cats=unique({s.category},'stable');rows=repmat(struct('category','','candidate_count',0,'replicate_count',0,'row_count',0,'unique_paired_case_count',0,'status',''),numel(cats),1);for k=1:numel(cats),x=s(strcmp({s.category},cats{k}));rows(k).category=cats{k};rows(k).candidate_count=numel(unique({x.candidate_id}));rows(k).replicate_count=numel(unique([x.replicate]));rows(k).row_count=numel(x);rows(k).unique_paired_case_count=numel(unique({x.paired_case_id}));rows(k).status=ternary(rows(k).row_count==rows(k).candidate_count*rows(k).replicate_count,'balanced','invalid');end,end
function r=independence(s),p={s.parameter_vector_hash};c={s.noiseless_cfr_hash};o={s.observation_hash};r=struct('scope','paired','row_count',numel(s),'unique_physical_scenario_count',numel(unique({s.sample_id})),'unique_parameter_hash_count',numel(unique(p)),'unique_cfr_hash_count',numel(unique(c)),'unique_observation_hash_count',numel(unique(o)),'duplicate_parameter_hash_count',numel(s)-numel(unique(p)),'duplicate_cfr_hash_count',numel(s)-numel(unique(c)),'duplicate_observation_hash_count',numel(s)-numel(unique(o)),'status',ternary(numel(unique(p))==numel(s)&&numel(unique(c))==numel(s),'unique_hashes','duplicates_detected'));end
function r=row_template(),r=struct('sample_id','','paired_case_id','','category','','replicate',0,'candidate_id','','case_seed',0,'nuisance_seed',0,'noise_base_hash','','truth_theta',struct(),'truth_topology_id','','accepted_set','','set_size',0,'hit',false,'empty',false,'parameter_domain_truth','','main_length_scale',NaN,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','calibration_hash','','experiment_hash','');end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function x=ratio(a,b),if b<=0,x=NaN;else,x=a/b;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
