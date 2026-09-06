function test_stage4a6_3_no_truth_leakage()
%TEST_STAGE4A6_3_NO_TRUTH_LEAKAGE Decision code has no scoring-label inputs.
    root=fileparts(fileparts(mfilename('fullpath')));
    p=fileread(fullfile(root,'src','apply_stage4a6_2_parameter_decision.m'));
    forbidden={'truth_topology_id','truth_theta','parameter_domain_truth', ...
        'outlier_dimension','outlier_severity','coverage_status'};
    for k=1:numel(forbidden),assert(isempty(strfind(p,forbidden{k})));end %#ok<STREMP>
end
