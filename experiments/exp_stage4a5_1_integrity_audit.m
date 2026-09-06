function out = exp_stage4a5_1_integrity_audit(cfg,sc)
%EXP_STAGE4A5_1_INTEGRITY_AUDIT Recompute A5 evidence with corrected identity.
    if nargin<1||isempty(cfg),root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);end
    if nargin<2||isempty(sc),sc=stage4a5_1_integrity_config(cfg,'formal');end
    ensure_result_dirs(cfg);if ~exist(sc.cache_dir,'dir'),mkdir(sc.cache_dir);end
    started=tic;root=cfg.root_dir;source_hash=stage4a5_1_source_tree_hash(root);
    bank=generate_stage4a5_1_trial_bank(sc,'all');base=generate_radial_topology_candidates(sc.generator);theta=topology_parameter_grid(sc.parameter_search);
    sci=scientific_payload(cfg,sc,base,theta,source_hash);[experiment_hash,canonical_text]=stage4a4_scientific_config_hash(sci);
    methods=stage4a5_method_specs(sc);all_dec=struct([]);all_lab=struct([]);all_thr=struct([]);all_rt=struct([]);all_mask=struct([]);cache_rows=struct([]);
    for gi=1:numel(sc.grids)
        grid=sc.grids(gi);f=grid.frequency_hz(:).';fprintf('Stage 4A.5.1 grid %s (%d points)\n',grid.id,numel(f));
        [sub8,~]=stage4a5_make_subbands(f,8,grid.id,experiment_hash);
        reps=unique({bank.replicate_id},'stable');[mask_design,mask_manifest]=build_frozen_resampling_masks(grid,reps,sc,experiment_hash);all_mask=append(all_mask,mask_manifest);
        observations=make_observations(bank,f,cfg,sc.measurement_kind);
        [expected,cache_hash]=stage4a5_1_cache_expected(grid,base,theta,cfg,sc,source_hash);
        cache_file=fullfile(sc.cache_dir,sprintf('%s_%s_P0_no_prior.mat',sc.output_prefix,grid.id));
        [cache,cache_source,validation_reason]=load_or_build(cache_file,expected,grid,base,theta,cfg,sc,source_hash,experiment_hash,cache_hash);
        audit=cache.current_equivalence_audit;
        hashes=struct('experiment_scientific_hash',experiment_hash,'source_tree_hash',source_hash);
        labels=build_truth_labels_by_canonical_key(bank,base,audit,audit,base,sc.parameter_search,grid.id,'P0_no_prior',hashes);
        raw=cell(numel(bank),1);
        for i=1:numel(bank)
            md=mask_design(strcmp({mask_design.replicate_id},bank(i).replicate_id));
            opt=struct('candidate_count_before_prior',numel(base));
            raw{i}=score_stage4a5_1_observation(observations{i},cache,sub8,md.masks,opt);
            raw{i}.sample_id=bank(i).sample_id;raw{i}.replicate_id=bank(i).replicate_id;raw{i}.split=bank(i).split;
        end
        selected=frozen_specs(methods,sc,grid.id);
        for ri=1:numel(sc.final_seeds)
            rep=sprintf('final%02d',ri);cal=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'final_replication_calibration'));
            tst=find(strcmp({bank.replicate_id},rep)&strcmp({bank.split},'final_replication_test'));
            model=calibrate_stage4a5_confirmation([raw{cal}],sc,grid.id,experiment_hash,sc.final_seeds(ri));
            for mi=1:numel(selected)
                for q=1:numel(tst)
                    d=apply_stage4a5_confirmation(raw{tst(q)},model,selected(mi));d.grid_id=grid.id;d.scenario_id='P0_no_prior';
                    if isempty(all_dec),all_dec=d;else,all_dec(end+1)=d;end %#ok<AGROW>
                    if isempty(all_lab),all_lab=labels(tst(q));else,all_lab(end+1)=labels(tst(q));end %#ok<AGROW>
                end
            end
            tr=struct('grid_id',grid.id,'replicate_id',rep,'calibration_seed',sc.final_seeds(ri), ...
                'calibration_sample_count',numel(cal),'residual_threshold',model.thresholds.residual_threshold, ...
                'margin_threshold',model.thresholds.margin_threshold,'calibration_hash',model.configuration_hash, ...
                'experiment_scientific_hash',experiment_hash);all_thr=append(all_thr,tr);
        end
        cr=struct('grid_id',grid.id,'scenario_id','P0_no_prior','cache_file',cache_file,'cache_source',cache_source, ...
            'validation_reason',validation_reason,'cache_configuration_hash',cache_hash,'template_count',cache.composite_template_count, ...
            'frequency_count',numel(f),'estimated_memory_bytes',cache.estimated_memory_bytes,'build_time_s',cache.build_time_s, ...
            'forward_model_source_hash',source_hash);cache_rows=append(cache_rows,cr);
        rr=struct('grid_id',grid.id,'scenario_id','P0_no_prior','sample_count',numel(bank), ...
            'candidate_count_before_prior',numel(base),'candidate_count_after_prior',numel(base), ...
            'parameter_template_count',numel(theta),'composite_template_count',numel(base)*numel(theta), ...
            'experiment_scientific_hash',experiment_hash,'cache_configuration_hash',cache_hash);all_rt=append(all_rt,rr);
        clear cache raw observations
    end
    metrics=evaluate_stage4a5_metrics(all_dec,all_lab);gate=gate_summary(metrics,bank,base);
    write_outputs(cfg,sc,bank,all_dec,all_lab,metrics,all_thr,all_rt,all_mask,cache_rows,gate,experiment_hash,source_hash,canonical_text);
    make_figures(cfg,sc,metrics);
    out=struct('runtime_s',toc(started),'experiment_scientific_hash',experiment_hash,'source_tree_hash',source_hash,'gate',gate,'metrics',metrics);
    fprintf('Stage 4A.5.1 completed in %.3f s; gate=%d\n',out.runtime_s,gate.passed);
end

function obs=make_observations(bank,f,cfg,kind),obs=cell(numel(bank),1);for k=1:numel(bank),[net,lc]=topology_apply_parameters(bank(k).truth_network,cfg,bank(k).truth_theta);[m,~]=plc_measurement_bundle(kind,net,bank(k).truth_theta,lc);[obs{k},~]=plc_multiview_response(f,net,m,lc);end,end
function [cache,src,reason]=load_or_build(path,expected,grid,candidates,theta,cfg,sc,source_hash,experiment_hash,cache_hash)
    cache=[];src='rebuilt';reason='cache absent';if exist(path,'file'),z=load(path);if isfield(z,'cache'),[ok,reason]=validate_candidate_cache_identity(z.cache,expected);if ok,cache=z.cache;src='validated_stage4a5_1_cache';return;end,end,end
    nom=theta(find([theta.regularization]==0,1));lib=build_composite_topology_library(grid.frequency_hz,candidates,nom,sc.measurement_kind,cfg,numel(candidates));audit=audit_candidate_observability(candidates,lib,cfg,sc.distance.tie_tolerance);
    meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.distance.tie_tolerance,'distance_feature',sc.distance.feature, ...
        'distance_weights',sc.distance.weights,'distance_options',sc.distance.options,'scenario_id','P0_no_prior','configuration_hash',experiment_hash, ...
        'max_composite_templates',numel(candidates)*numel(theta),'baseline_P0_audit',audit,'cache_schema_version',sc.cache_schema_version, ...
        'cache_configuration_hash',cache_hash,'forward_model_source_hash',source_hash,'experiment_scientific_hash',experiment_hash,'source_tree_hash',source_hash);
    cache=build_stage4a5_1_template_cache(grid,candidates,theta,cfg,meta);save(path,'cache','-v7.3');reason=['rebuilt after: ' reason];
end
function x=frozen_specs(specs,sc,id),names=sc.frozen_methods.(id);x=specs(ismember({specs.method_id},names));if numel(x)~=4,error('stage4a5_1:FrozenSpecs','Expected four frozen methods.');end,end
function p=scientific_payload(cfg,sc,base,theta,source_hash),p=struct('stage',sc.stage_name,'version',sc.version,'source_tree_hash',source_hash,'generator',sc.generator,'candidates',{base}, ...
    'parameter_search',sc.parameter_search,'parameter_grid',{theta},'grids',sc.grids,'ofdm',cfg.ofdm,'measurement_kind',sc.measurement_kind,'Zs',cfg.Zs,'Zr',cfg.Zr, ...
    'distance',sc.distance,'bootstrap_repetitions',sc.bootstrap_repetitions,'block_count',sc.block_count,'block_fraction',sc.block_fraction,'resampling_base_seed',sc.resampling_base_seed, ...
    'development_seeds',sc.development_seeds,'final_seeds',sc.final_seeds,'sample_design',struct('development',sc.development,'final',sc.final),'frozen_methods',sc.frozen_methods);end
function g=gate_summary(m,bank,base)
    ix=strcmp({bank.category},'structure_out');ids=unique({bank(ix).truth_topology_id});keys=unique({bank(ix).canonical_key});
    a=metric_value(m,'A_stage4a1_quick61','M3','in_library_summary','set_accuracy_given_covered');b=metric_value(m,'B_ofdm_active_subcarriers','M3','in_library_summary','set_accuracy_given_covered');
    da=paired_improvement(m,'A_stage4a1_quick61');db=paired_improvement(m,'B_ofdm_active_subcarriers');
    g=struct('passed',isempty(intersect(ids,{base.topology_id}))&&isempty(intersect(keys,{base.canonical_key}))&&a>=0.80&&b>=0.80&&sum(da>0)>numel(da)/2&&sum(db>0)>numel(db)/2, ...
        'ool_id_collision_count',numel(intersect(ids,{base.topology_id})),'ool_key_collision_count',numel(intersect(keys,{base.canonical_key})), ...
        'A_M3_inlibrary_set_accuracy',a,'B_M3_inlibrary_set_accuracy',b,'A_positive_seed_improvements',sum(da>0),'A_seed_count',numel(da),'B_positive_seed_improvements',sum(db>0),'B_seed_count',numel(db), ...
        'A_mean_structure_far_improvement',mean(da),'B_mean_structure_far_improvement',mean(db));
end
function v=metric_value(m,grid,fam,cat,field),x=m(strcmp({m.grid_id},grid)&strcmp({m.category},cat)&startsWith({m.method_id},fam));v=mean([x.(field)],'omitnan');end
function d=paired_improvement(m,grid),a=m(strcmp({m.grid_id},grid)&strcmp({m.category},'structure_out')&startsWith({m.method_id},'M0'));b=m(strcmp({m.grid_id},grid)&strcmp({m.category},'structure_out')&startsWith({m.method_id},'M3'));r=intersect({a.replicate_id},{b.replicate_id},'stable');d=NaN(1,numel(r));for k=1:numel(r),aa=a(strcmp({a.replicate_id},r{k}));bb=b(strcmp({b.replicate_id},r{k}));d(k)=aa(1).accepted_rate-bb(1).accepted_rate;end,end
function write_outputs(cfg,sc,bank,d,l,m,t,r,mask,cache,gate,h,source,txt),p=sc.output_prefix;data=cfg.results_data;write(bank_rows(bank),fullfile(data,[p '_trial_bank.csv']));write(d,fullfile(data,[p '_match_decisions.csv']));write(l,fullfile(data,[p '_scoring_labels.csv']));write(m,fullfile(data,[p '_metrics.csv']));write(t,fullfile(data,[p '_thresholds.csv']));write(r,fullfile(data,[p '_runtime.csv']));write(mask,fullfile(data,[p '_resampling_manifest.csv']));write(cache,fullfile(data,[p '_cache_manifest.csv']));write(gate,fullfile(data,[p '_gate_summary.csv']));manifest=struct('experiment_scientific_hash',h,'source_tree_hash',source,'runtime_environment_hash',stage4a4_scientific_config_hash(struct('matlab',version,'computer',computer)),'canonical_configuration_text',txt);write(manifest,fullfile(data,[p '_configuration_manifest.csv']));save(fullfile(data,[p '_results.mat']),'sc','bank','d','l','m','t','r','mask','cache','gate','manifest','-v7.3');end
function x=bank_rows(b),x=repmat(struct('sample_id','','replicate_id','','split','','category','','truth_topology_id','','canonical_key','','outlier_dimension','','outlier_direction','','seed',0),numel(b),1);for k=1:numel(b),x(k)=struct('sample_id',b(k).sample_id,'replicate_id',b(k).replicate_id,'split',b(k).split,'category',b(k).category,'truth_topology_id',b(k).truth_topology_id,'canonical_key',b(k).canonical_key,'outlier_dimension',b(k).outlier_dimension,'outlier_direction',b(k).outlier_direction,'seed',b(k).seed);end,end
function write(s,path),if isempty(s),return;end;writetable(struct2table(s(:)),path);end
function y=append(x,z),if isempty(x),y=z(:);else,y=[x(:);z(:)];end,end
function make_figures(cfg,sc,m),for gi=1:numel(sc.grids),grid=sc.grids(gi).id;x=m(strcmp({m.grid_id},grid)&strcmp({m.scenario_id},'P0_no_prior'));families={'M0','M1','M2','M3'};setacc=NaN(1,4);sfar=NaN(1,4);pfar=NaN(1,4);for k=1:4,setacc(k)=family_mean(x,families{k},'in_library_summary','set_accuracy_given_covered');sfar(k)=family_mean(x,families{k},'structure_out','accepted_rate');pfar(k)=family_mean(x,families{k},'parameter_out','accepted_rate');end;plotbar(cfg,sc,grid,setacc,'in-library micro set accuracy','inlibrary_set_accuracy');plotbar(cfg,sc,grid,sfar,'structure-out false accept rate','structure_out_false_accept');h=figure('Visible','off');plot(setacc,sfar,'o-','DisplayName','structure-out');hold on;plot(setacc,pfar,'s-','DisplayName','parameter-out');xlabel('in-library micro set accuracy');ylabel('out-of-library false accept rate');legend('Location','best');title([grid ' P0 accuracy-OOL tradeoff']);saveas(h,fullfile(cfg.results_figures,[sc.output_prefix '_' grid '_accuracy_ool_tradeoff.png']));close(h);d=paired_improvement(x,grid);h=figure('Visible','off');bar(d);xlabel('final replicate');ylabel('FAR(M0)-FAR(M3)');title([grid ' paired structure-out improvement']);saveas(h,fullfile(cfg.results_figures,[sc.output_prefix '_' grid '_seed_paired_improvement.png']));close(h);z=x(strcmp({x.category},'parameter_out')&startsWith({x.method_id},'M3'));dims=unique({z.outlier_dimension},'stable');v=NaN(1,numel(dims));for k=1:numel(dims),v(k)=mean([z(strcmp({z.outlier_dimension},dims{k})).accepted_rate],'omitnan');end;h=figure('Visible','off');bar(v);set(gca,'XTick',1:numel(dims),'XTickLabel',dims,'XTickLabelRotation',35);ylabel('parameter-domain missed-alarm rate');title([grid ' M3 parameter-out dimensions']);saveas(h,fullfile(cfg.results_figures,[sc.output_prefix '_' grid '_M3_parameter_domain_missed_alarm.png']));close(h);end,end
function v=family_mean(x,fam,cat,field),z=x(strcmp({x.category},cat)&startsWith({x.method_id},fam));v=mean([z.(field)],'omitnan');end
function plotbar(cfg,sc,grid,v,yl,suffix),h=figure('Visible','off');bar(v);set(gca,'XTick',1:4,'XTickLabel',{'M0','M1','M2','M3'});ylabel(yl);title([grid ' P0 ' yl]);ylim([0 1]);saveas(h,fullfile(cfg.results_figures,[sc.output_prefix '_' grid '_' suffix '.png']));close(h);end
