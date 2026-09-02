function test_stage3b_pre()
%TEST_STAGE3B_PRE Validate isolated standard-derived diagnostic boundaries.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    cfg=stage3b_pre_config(root);before=default_config(root);
    bb0=stage3b_pre_band_selector('BB','Level-A0_matched_points');nb0=stage3b_pre_band_selector('NB','Level-A0_matched_points');
    bb1=stage3b_pre_band_selector('BB','Level-A1_native_points');nb1=stage3b_pre_band_selector('NB','Level-A1_native_points');after=default_config(root);
    assert(bb0.active_point_count==36&&nb0.active_point_count==36&&bb1.active_point_count>nb1.active_point_count,'Level-A0/A1 point rules failed.');
    assert(bb1.nfft==4096&&bb1.fs_hz==100e6&&nb1.nfft==256&&nb1.fs_hz==.4e6&&nb1.ncp==30&&nb1.overlap_samples==8,'Standard-derived fields failed.');
    assert(isequal(before.ofdm,after.ofdm)&&strcmp(cfg.analysis_kind,'analytic_extrapolation_diagnostic'),'Existing configuration was changed.');
    fair=stage3b_pre_fair_sampling(bb0,1,3.2e-3);assert(fair.total_injected_energy==1&&fair.repetitions>0,'Fairness metadata failed.');
    candidates=topology_candidates(before);out=stage3b_pre_level_a_match(nb0.frequency_hz,candidates([2,3,4,5]),before,struct(),Inf,1,cfg);
    assert(any(out.classes.class_sizes>1)&&all(isfinite(out.classes.pairwise_complex_distance(:))),'Equivalence diagnostic failed.');
    fprintf('  PASS Stage3B-pre isolated standard-derived diagnostic boundaries\n');
end
