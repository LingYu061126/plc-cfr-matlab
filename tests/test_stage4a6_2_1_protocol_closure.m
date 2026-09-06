function test_stage4a6_2_1_protocol_closure()
%TEST_STAGE4A6_2_1_PROTOCOL_CLOSURE Protocol semantics and resume checks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    test_uncalibrated_thresholds();test_m2_m3_separation();test_flatness_gates();test_single_start_semantics();test_shard_identity();test_batch_resume(root);
    fprintf('ALL STAGE-4A.6.2.1 PROTOCOL CLOSURE TESTS PASSED\n');
end
function test_uncalibrated_thresholds()
    p=parameter('main_length_scale',true,true);m=member(p);td=topology('unique_topology','G001');
    model=struct('calibration_status','insufficient_calibration','parameter_thresholds',calibrated_threshold('main_length_scale','insufficient_calibration'));
    out=apply_stage4a6_2_parameter_decision(td,m,model,'A6_2_M2_profile');
    assert(strcmp(out.parameter_statuses(1).profile_status,'indeterminate_insufficient_calibration'));
    assert(strcmp(out.parameter_domain_status,'parameter_domain_indeterminate'));
    model.calibration_status='calibrated';model.parameter_thresholds(1).status='calibrated';model.parameter_thresholds(1).absolute_improvement_threshold=NaN;
    out=apply_stage4a6_2_parameter_decision(td,m,model,'A6_2_M2_profile');
    assert(strcmp(out.parameter_statuses(1).profile_status,'indeterminate_insufficient_calibration'));
end
function test_m2_m3_separation()
    p=parameter('main_length_scale',true,true);p.extended_optimum_outside=true;p.absolute_improvement=.5;p.relative_improvement=.01;p.boundary_behavior='interior';p.outward_decrease=false;
    model=struct('calibration_status','calibrated','parameter_thresholds',calibrated_threshold('main_length_scale','calibrated'));
    td=topology('unique_topology','G001');out2=apply_stage4a6_2_parameter_decision(td,member(p),model,'A6_2_M2_profile');
    out3=apply_stage4a6_2_parameter_decision(td,member(p),model,'A6_2_M3_joint_diagnostic');
    assert(strcmp(out2.parameter_statuses(1).profile_status,'out_suspected'));
    assert(strcmp(out3.parameter_statuses(1).profile_status,'indeterminate_conflicting_evidence'));
end
function test_flatness_gates()
    [f,rr,aa]=stage4a6_2_flatness_rule([1 1.01],.05,.02);assert(f&&rr>.0&&aa<=.02);
    [f,~,aa]=stage4a6_2_flatness_rule([1 1.01],.05,.005);assert(~f&&aa>.005);
    [f,rr,aa]=stage4a6_2_flatness_rule([0 1],.05,2);assert(~f&&rr>0&&aa==1);
    [f,~,~]=stage4a6_2_flatness_rule([0 0],.05,1e-9);assert(f);
    [f,~,~]=stage4a6_2_flatness_rule([1 NaN 1.01],.05,.02);assert(f);
end
function test_single_start_semantics()
    cfg=stage4a6_2_profile_config(default_config(fileparts(fileparts(mfilename('fullpath')))),'smoke');
    assert(strcmp(cfg.profile.multistart_single_start_policy,'not_applicable'));
    assert(cfg.profile.profile_multi_start_count==1);
end
function test_shard_identity()
    s=failed_shard('x','science','source','p');[ok,~]=validate_stage4a6_2_shard(s,struct('case_id','x','scientific_hash','science','source_tree_hash','source','parameter_name','p'),'allow_failed',true);assert(ok);
    s.checksum='bad';[ok,~]=validate_stage4a6_2_shard(s,struct('case_id','x','scientific_hash','science','source_tree_hash','source','parameter_name','p'),'allow_failed',true);assert(~ok);
end
function test_batch_resume(root)
    folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
    cfg=default_config(root);sc=stage4a6_2_profile_config(cfg,'smoke');candidates=generate_radial_topology_candidates(sc.generator);g=candidates(1);theta=nominal_theta(cfg);
    [net,lc]=topology_apply_parameters(g.network,cfg,theta);[meas,~]=plc_measurement_bundle('siso_forward',net,theta,lc);[obs,~]=plc_multiview_response(sc.grids(1).frequency_hz(1),net,meas,lc);domain=build_extended_parameter_domain(sc.parameter_search,.5);
    ctx=struct('root_dir',folder,'scientific_hash','science','source_tree_hash','source','frequency_hz',sc.grids(1).frequency_hz(1),'cfg',cfg,'domain',domain,'initial_thetas',theta,'candidate',g,'observed_views',obs,'options',sc.optimization);ctx.options.profile.enabled=false;
    m=struct('case_id','case001','parameter_name','all_active','expected_output_path','results/data/case001.mat','case_seed',1);
    a=run_stage4a6_2_batch(m,ctx,struct('resume',true,'retry_failed',false));assert(a.attempted==1&&a.completed==1&&a.resumed==0);
    f=fullfile(folder,m.expected_output_path);d=dir(f);b=run_stage4a6_2_batch(m,ctx,struct('resume',true,'retry_failed',false));assert(b.attempted==0&&b.resumed==1);d2=dir(f);assert(d.datenum==d2.datenum);
    ctx2=ctx;ctx2.scientific_hash='other';c=run_stage4a6_2_batch(m,ctx2,struct('resume',true,'retry_failed',false));assert(c.attempted==1&&c.hash_mismatch>=1);
    failed_path=fullfile(folder,'results','data','failed.mat');failed=failed_shard('failed','failed-science','source','all_active');save_stage4a6_2_shard_atomic(failed,failed_path,struct('case_id','failed','scientific_hash','failed-science','source_tree_hash','source','parameter_name','all_active'));
    mf=m;mf.case_id='failed';mf.expected_output_path='results/data/failed.mat';ctxf=ctx;ctxf.scientific_hash='failed-science';
    nf=run_stage4a6_2_batch(mf,ctxf,struct('resume',true,'retry_failed',false));assert(nf.attempted==0&&nf.failed==1);
    nf=run_stage4a6_2_batch(mf,ctxf,struct('resume',true,'retry_failed',true));assert(nf.attempted==1&&nf.completed==1&&nf.retry_count==1);
    pending=mf;pending.case_id='pending';pending.expected_output_path='results/data/pending.mat';tmp=fullfile(folder,'results','data','pending.mat.tmp');x=1;save(tmp,'x');ap=aggregate_stage4a6_2_shards(pending,ctxf,'allow_failed',true);assert(ap.missing==1&&ap.completed==0);
end
function p=parameter(name,active,reliable),p=struct('parameter_name',name,'active',active,'profile_status','indeterminate','in_domain_min_distance',1,'extended_min_distance',.5,'absolute_improvement',.2,'relative_improvement',.2,'extended_optimum',1.1,'extended_optimum_outside',false,'boundary_behavior','interior','outward_decrease',false,'flatness_metric',1,'relative_dynamic_range',1,'absolute_dynamic_range',1,'valid_point_fraction',1,'local_sensitivity',1,'multistart_evaluated',false,'multistart_consistent','not_applicable','profile_reliable',reliable,'reliability_reason','test');end
function e=member(p),e=struct('profile_reliable',p.profile_reliable,'profile_computed',true,'residual_finite',true,'multistart_consistent',true,'active_parameters_identifiable',true,'optimizer_converged',true,'parameter_evidence',p);end
function t=topology(decision,id),t=struct('decision',decision,'accepted_topology_set',id,'best_topology_id',id);end
function t=calibrated_threshold(name,status),t=struct('parameter_name',name,'reliable_sample_count',1,'absolute_improvement_threshold',.1,'relative_improvement_threshold',.1,'sensitivity_floor',.1,'status',status);end
function s=failed_shard(id,science,source,param),s=struct('case_id',id,'scientific_hash',science,'source_tree_hash',source,'status','failed','exit_status',1,'parameter_name',param,'started_at','a','finished_at','b','runtime_s',0,'profile_summary',struct([]),'optimizer_state',struct(),'error_identifier','test:failed','error_message','failed','attempt_count',1,'retry_count',0,'attempt_history',struct([]),'checksum','');s.checksum=stage4a6_2_checksum_test(s);end
function h=stage4a6_2_checksum_test(v),v.checksum='';[h,~]=stage4a4_scientific_config_hash(v);end
function t=nominal_theta(cfg),t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',cfg.Zs,'receiver_impedance_ohm',cfg.Zr,'regularization',NaN);end
