function rows = benchmark_stage4a6_1_workers(root,worker_list)
%BENCHMARK_STAGE4A6_1_WORKERS Compare serial/outer-case worker counts.
%   Uses a fixed small final-only case bank and disables profile curves so
%   the benchmark measures the shared fitting batch rather than I/O.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(worker_list),worker_list=[1 4 6 8];end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    cfg=default_config(root);sc=stage4a6_1_optimizer_config(cfg,'smoke');sc.mode='formal_a';sc.output_prefix='stage4a6_1_worker_benchmark';sc.development_seeds=[];sc.final_seeds=20261901;sc.calibration.minimum_samples=1;sc.profile.enabled=false;sc.optimization.multi_start_count=2;sc.optimization.max_iterations=60;sc.optimization.max_function_evaluations=180;
    bank=generate_stage4a6_1_trial_bank(sc,'final');base=generate_radial_topology_candidates(sc.generator);tg=topology_parameter_grid(sc.parameter_search);grid=sc.grids(1);a5=stage4a5_1_integrity_config(cfg,'formal');a5.calibration.minimum_samples=1;hash=stage4a6_1_source_tree_hash(root);obs=make_obs(bank,grid.frequency_hz,cfg,sc.measurement_kind);[cache,~]=load_cache(cfg,grid,base,tg);[sub8,~]=stage4a5_make_subbands(grid.frequency_hz,8,grid.id,hash);[masks,~]=build_frozen_resampling_masks(grid,unique({bank.replicate_id},'stable'),a5,hash);raw=cell(numel(bank),1);for i=1:numel(bank),md=masks(strcmp({masks.replicate_id},bank(i).replicate_id));raw{i}=score_stage4a5_1_observation(obs{i},cache,sub8,md.masks,struct('candidate_count_before_prior',7));end;specs=stage4a5_method_specs(sc);method_names=sc.frozen_methods.(grid.id);spec=specs(strcmp({specs.method_id},method_names{4}));tm=calibrate_stage4a5_confirmation([raw{1:7}],a5,grid.id,hash,20261901);td=apply_stage4a5_confirmation(raw{1},tm,spec);for i=2:numel(raw),td(i)=apply_stage4a5_confirmation(raw{i},tm,spec);end;domain=build_extended_parameter_domain(sc.parameter_search,.5);idx=8:numel(bank);rows=repmat(row(),0,1);reference=[];
    for w=worker_list
        s=struct();s.parallel=sc.parallel;s.parallel.use_parallel=w>1;s.parallel.num_workers=w;s.profile=sc.profile;s.optimization=sc.optimization;t=tic;e=run_stage4a6_1_member_batch(idx,td,obs,raw,cache,base,grid,cfg,domain,s);elapsed=toc(t);sig=signature(e);if isempty(reference),reference=sig;end;rows(end+1)=struct('workers',w,'runtime_s',elapsed,'speedup',NaN,'correctness',strcmp(sig,reference),'profile_enabled',false,'sample_count',numel(idx),'solver',solver_name(),'peak_ram','not_measured','swap','not_measured'); %#ok<AGROW>
        pool=gcp('nocreate');if ~isempty(pool),delete(pool);end
    end
    base_time=rows(1).runtime_s;for k=1:numel(rows),rows(k).speedup=base_time/rows(k).runtime_s;end
    writetable(struct2table(rows),fullfile(cfg.results_data,'stage4a6_1_worker_benchmark.csv'));
end
function y=make_obs(b,f,cfg,kind),y=cell(numel(b),1);for k=1:numel(b),[n,lc]=topology_apply_parameters(b(k).truth_network,cfg,b(k).truth_theta);[m,~]=plc_measurement_bundle(kind,n,b(k).truth_theta,lc);[y{k},~]=plc_multiview_response(f,n,m,lc);end,end
function [c,a]=load_cache(cfg,g,b,t),a5=stage4a5_1_integrity_config(cfg,'formal');sh=stage4a5_1_source_tree_hash(cfg.root_dir);[exp,~]=stage4a5_1_cache_expected(g,b,t,cfg,a5,sh);z=load(fullfile(a5.cache_dir,sprintf('stage4a5_1_%s_P0_no_prior.mat',g.id)),'cache');[ok,why]=validate_candidate_cache_identity(z.cache,exp);if ~ok,error('stage4a6_1:BenchmarkCache','%s',why);end;c=z.cache;a=c.current_equivalence_audit;end
function s=signature(e),s=stage4a4_scientific_config_hash(cellfun(@(x)struct('n',numel(x),'d',[x.in_distance]),e,'UniformOutput',false));end
function s=solver_name(),if exist('lsqnonlin','file')==2,s='lsqnonlin';else,s='fminsearch_logistic_bounded';end,end
function r=row(),r=struct('workers',0,'runtime_s',NaN,'speedup',NaN,'correctness',false,'profile_enabled',false,'sample_count',0,'solver','','peak_ram','','swap','');end
