function test_stage7a4_forward_state()
%TEST_STAGE7A4_FORWARD_STATE Verify the new source-side impedance view.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_mirror_observation_config(base,'smoke');
    grammar=cfg_for_small(base);lib=generate_radial_topology_candidates(grammar);
    assert(numel(lib)==3&&strcmp(lib(3).topology_id,'G003'));
    network=lib(3).network;
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'source_impedance_ohm',50, ...
        'receiver_impedance_ohm',50,'first_segment_scale',1);
    f=cfg.frequency_hz;
    for k=1:numel(cfg.termination_ohm)
        state=cfg.states(k);o=stage7a4_forward_state(network,theta,base,f,state);
        [net,local]=topology_apply_parameters(network,base,theta);
        local.Zs=50;local.Zr=state.receiver_ohm;
        [h,d]=cascade_network_stable(f,net,local);
        assert(max(abs(o.H_endpoint-h.H_port))<2e-11, ...
            'Endpoint transfer changed when adding the input-impedance view.');
        assert(max(abs(o.Zin-d.input_impedance))<2e-8, ...
            'Line-side Zin disagrees with the independent backward recursion.');
        assert(max(abs(o.Gamma50-(o.Zin-50)./(o.Zin+50)))<1e-12);
    end
    low=stage7a4_forward_state(network,theta,base,f,cfg.states(2));
    high=stage7a4_forward_state(network,theta,base,f,cfg.states(4));
    assert(max(abs(low.Zin-high.Zin))>1e-4 && ...
        max(abs(low.H_endpoint-high.H_endpoint))>1e-5, ...
        'Changing the receiver termination did not change the network response.');
    for k=6:8
        o=stage7a4_forward_state(network,theta,base,f,cfg.states(k));
        assert(numel(o.H_node)==numel(f)&&all(isfinite(o.H_node))&& ...
            o.node_index==cfg.node_indices(k-5));
    end
    fprintf('PASS test_stage7a4_forward_state: endpoint CFR, Zin and loaded node ports\n');
end

function grammar=cfg_for_small(base)
    sc=stage7a_profile_search_config(base,'formal');
    grammar=sc.stage6b.scale.grammars(1);
end
