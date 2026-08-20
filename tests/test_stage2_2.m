function test_stage2_2()
%TEST_STAGE2_2 Complete-network multiview and joint-inversion tests.
    fprintf('Running stage-2.2 physical multiview/joint-matching tests...\n');
    root=fileparts(fileparts(mfilename('fullpath'))); cfg=default_config(root);
    f=linspace(2e6,30e6,41); candidates=topology_candidates(cfg);
    theta=struct('source_impedance_ohm',50,'receiver_impedance_ohm',50);

    for k=1:numel(candidates)
        [m,~]=plc_measurement_bundle('siso_forward',candidates(k).network,theta,cfg);
        [Hn,d]=plc_full_network_response(f,candidates(k).network,m,cfg);
        [Hs,~]=cascade_network_stable(f,candidates(k).network,cfg);
        assert(max(relative_error(Hn.H_port,Hs.H_port))<2e-11 && d.full_network, ...
            'Complete nodal model does not match stable endpoint CFR.');
    end
    fprintf('  PASS complete-network endpoint CFR matches stage-1.5 stable recursion\n');

    asym=struct('source_impedance_ohm',50,'receiver_impedance_ohm',75);
    [role,rolemeta]=plc_measurement_bundle('siso_reverse_role_fixed',candidates(3).network,asym,cfg);
    [fixed,fixedmeta]=plc_measurement_bundle('siso_reverse_endpoint_fixed',candidates(3).network,asym,cfg);
    assert(role.source_impedance_ohm==50 && role.receiver_loads_ohm==75 && ...
        fixed.source_impedance_ohm==75 && fixed.receiver_loads_ohm==50 && ...
        ~rolemeta.network_is_truncated && ~fixedmeta.network_is_truncated, ...
        'Reverse role-fixed and endpoint-fixed semantics are not separated.');
    Hr=plc_full_network_response(f,candidates(3).network,role,cfg);
    Hf=plc_full_network_response(f,candidates(3).network,fixed,cfg);
    assert(all(isfinite(Hr.H_port))&&all(isfinite(Hf.H_port))&& ...
        max(abs(Hr.H_port-Hf.H_port))>1e-8, ...
        'The two asymmetric reverse cases were not independently evaluated.');
    fprintf('  PASS reverse-only and reverse-plus-impedance-swap cases are explicit\n');

    [dual,~]=plc_measurement_bundle('dual_receiver_complete',candidates(4).network,theta,cfg);
    [views,vd]=plc_multiview_response(f,candidates(4).network,dual,cfg);
    expected_edges=numel(candidates(4).network.main_lengths)+numel(candidates(4).network.branches);
    assert(numel(views)==2 && vd.full_network_for_every_view && ...
        numel(vd.solve_details{1}.edges)==expected_edges, ...
        'Dual receiver view removed downstream lines or branches.');
    fprintf('  PASS internal receiver uses the complete network without prefix truncation\n');

    Href=(0.1+0.03i)*exp(-1i*linspace(0,2*pi,numel(f))); Hscaled=2*Href;
    [dshape,~]=topology_feature_distance(Hscaled,Href,'amplitude',cfg.ofdm,[.5,.5]);
    [dabs,~]=topology_feature_distance(Hscaled,Href,'amplitude_raw_db',cfg.ofdm,[.5,.5]);
    [dz,~]=topology_feature_distance(Hscaled,Href,'amplitude_db_standardized',cfg.ofdm,[.5,.5]);
    assert(dshape<1e-14 && dz<1e-12 && dabs>5.9, ...
        'Absolute level and amplitude-shape features are not separated.');
    for threshold=cfg.stage2_2.phase_mask_thresholds_db
        d=topology_feature_distance(Hscaled,Href,'amp_phase_joint_weighted', ...
            cfg.ofdm,[.5,.5],struct('phase_mask_threshold_db',threshold));
        assert(isfinite(d),'Weighted joint phase threshold scan is nonfinite.');
    end
    fprintf('  PASS absolute/shape amplitude and weighted joint phase features\n');

    grid=topology_parameter_grid(cfg.stage2_2.search);
    assert(numel(grid)==243,'Configured independent line-parameter grid size is incorrect.');
    nominal=grid([grid.regularization]==0);
    subset=candidates([3,5]);
    library=topology_parameter_library(f,subset,nominal,'dual_receiver_complete',cfg);
    [m,~]=plc_measurement_bundle('dual_receiver_complete',subset(1).network,nominal, cfg);
    obs=plc_multiview_response(f,subset(1).network,m,cfg);
    result=topology_joint_match(obs,library,'complex',cfg.ofdm,[.5,.5],.01);
    assert(result.predicted_index==1 && isfield(result.theta_hat,'main_length_scale'), ...
        'Joint topology/parameter matcher failed a noiseless complete-view case.');
    weighted_options=struct('phase_mask_threshold_db',-30);
    raw_weighted=topology_joint_match(obs,library,'amp_phase_joint_weighted', ...
        cfg.ofdm,[.2,.8],.01,weighted_options);
    cached=topology_prepare_parameter_library(library);
    cached_weighted=topology_joint_match(obs,cached,'amp_phase_joint_weighted', ...
        cfg.ofdm,[.2,.8],.01,weighted_options);
    assert(max(abs(raw_weighted.scores-cached_weighted.scores))<1e-12 && ...
        raw_weighted.template_index==cached_weighted.template_index, ...
        'Prepared joint-matching cache changed the reference scores.');
    fprintf('  PASS configured joint topology/parameter grid matching\n');

    shortnet=candidates(2).network; shortnet.branches(1).load=0;
    Hshort=plc_full_network_response(f,shortnet, ...
        plc_measurement_bundle('siso_forward',shortnet,theta,cfg),cfg);
    assert(all(isfinite(Hshort.H_port)),'Zero-ohm branch load was not handled explicitly.');
    opennet=candidates(2).network;opennet.branches(1).load=Inf;
    Hopen=plc_full_network_response(f,opennet, ...
        plc_measurement_bundle('siso_forward',opennet,theta,cfg),cfg);
    complexnet=candidates(2).network;complexnet.branches(1).load=50+15i;
    Hcomplex=plc_full_network_response(f,complexnet, ...
        plc_measurement_bundle('siso_forward',complexnet,theta,cfg),cfg);
    assert(all(isfinite(Hopen.H_port))&&all(isfinite(Hcomplex.H_port)), ...
        'Open or scalar-complex full-network loads were not handled explicitly.');
    empty=candidates(1).network;
    Hempty=plc_full_network_response(f,empty, ...
        plc_measurement_bundle('siso_forward',empty,theta,cfg),cfg);
    assert(all(isfinite(Hempty.H_port)),'Empty branches failed.');
    bad=empty; bad.main_lengths(1)=0;
    assert_throws(@()plc_full_network_response(f,bad, ...
        plc_measurement_bundle('siso_forward',bad,theta,cfg),cfg), ...
        'plc_full_network_response:ZeroLengthEdge');
    assert_throws(@()plc_full_network_response(0,empty, ...
        plc_measurement_bundle('siso_forward',empty,theta,cfg),cfg), ...
        'plc_full_network_response:InvalidFrequency');
    badload=candidates(2).network;badload.branches(1).load=NaN;
    assert_throws(@()plc_full_network_response(f,badload, ...
        plc_measurement_bundle('siso_forward',badload,theta,cfg),cfg), ...
        'plc_full_network_response:InvalidLoad');
    assert_throws(@()topology_apply_parameters(empty,cfg, ...
        struct('main_length_scale',-1)), ...
        'topology_apply_parameters:InvalidScale');
    fprintf('  PASS Inf/zero/zero-length/empty-network boundaries are explicit\n');
    fprintf('ALL STAGE-2.2 TESTS PASSED\n');
end

function err=relative_error(a,b),err=abs(a-b)./max(abs(b),realmin);end
function assert_throws(fun,id)
    ok=false;try,fun();catch ME,ok=strcmp(ME.identifier,id);end
    assert(ok,'Expected error %s was not thrown.',id);
end
