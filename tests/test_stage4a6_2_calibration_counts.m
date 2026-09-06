function test_stage4a6_2_calibration_counts()
%TEST_STAGE4A6_2_CALIBRATION_COUNTS Retain reliable and excluded denominators.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);sc=stage4a6_2_profile_config(cfg,'smoke');
    p=parameter_evidence('main_length_scale',true,'in_domain',true);
    good=member_evidence(true,true,true,true,p);bad=member_evidence(false,true,true,true,p);bad.parameter_evidence.profile_status='scan_unreliable';bad.parameter_evidence.profile_reliable=false;
    m=calibrate_stage4a6_2_parameter_thresholds([good bad],sc,0.5,'hash');
    assert(m.total_calibration_evidence_count==2,'Total calibration denominator was not retained.');
    assert(m.reliable_calibration_evidence_count==1,'Reliable calibration count is incorrect.');
    assert(m.excluded_calibration_evidence_count==1,'Excluded calibration count is incorrect.');
    assert(m.total_calibration_evidence_count==m.reliable_calibration_evidence_count+m.excluded_calibration_evidence_count);
    assert(m.exclusion_reason_counts.insufficient_valid_scan_points==1,'Scan exclusion reason was not recorded.');
    fprintf('ALL STAGE-4A.6.2 CALIBRATION COUNT TESTS PASSED\n');
end
function e=member_evidence(opt,finite,consistent,computed,p),e=struct('profile_reliable',opt,'profile_computed',computed,'residual_finite',finite,'multistart_consistent',consistent,'active_parameters_identifiable',true,'optimizer_converged',opt,'parameter_evidence',p);end
function p=parameter_evidence(name,active,status,reliable),p=struct('parameter_name',name,'active',active,'profile_status',status,'in_domain_min_distance',1,'extended_min_distance',1,'absolute_improvement',0.01,'relative_improvement',0.01,'extended_optimum',1,'extended_optimum_outside',false,'boundary_behavior','interior','flatness_metric',1,'valid_point_fraction',1,'local_sensitivity',1,'profile_reliable',reliable,'reliability_reason','test');end
