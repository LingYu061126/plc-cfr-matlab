function test_stage4a6_3_trial_bank_isolation()
%TEST_STAGE4A6_3_TRIAL_BANK_ISOLATION Trial IDs, seeds and active masks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);sc=stage4a6_3_parameter_domain_config(cfg,'audit');c=generate_radial_topology_candidates(sc.generator);
    b=generate_stage4a6_3_trial_bank(sc,'all',c);a=audit_stage4a6_3_trial_bank(b,c,sc);
    assert(strcmp(a.audit_status,'passed'));
    assert(numel(unique({b.sample_id}))==numel(b));
    assert(numel(unique({c.topology_id}))==7);
    names=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta).names;
    for k=1:numel(b)
        if strcmp(b(k).parameter_domain_truth,'out_of_domain')
            q=topology_active_parameter_mask(c(strcmp({c.topology_id},b(k).truth_topology_id)),names);
            assert(q(strcmp(names,b(k).outlier_dimension)));
        end
    end
end
