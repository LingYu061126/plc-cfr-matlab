function test_stage7a4_joint_profile()
%TEST_STAGE7A4_JOINT_PROFILE Verify paired topology and shared theta rows.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_mirror_observation_config(base,'smoke');
    sc=stage7a_profile_search_config(base,'formal');
    lib=generate_radial_topology_candidates(sc.stage6b.scale.grammars(1));
    mirror=lib(3);mirror.topology_id='MIRROR_M3';mirror.network.branches.node=3;
    pair=[lib(3),mirror];bank=stage7a4_template_bank(pair,base,cfg);
    assert(size(bank.params,1)==45&&bank.forward_calls==2*45*8);
    nominal=find(all(abs(bank.params-[1 1 1])<1e-12,2),1);
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    [clean,observed]=stage7a4_measure_views(mirror.network,theta,base,cfg,720040001,20);
    for v=1:numel(clean)
        assert(max(abs(clean{v}-bank.templates{2,v}(nominal,:)))<2e-11, ...
            'The template and observation use different physical boundaries.');
        assert(all(isfinite(observed{v})));
    end
    hrel=sqrt(mean(abs(clean{5}-bank.templates{1,5}(nominal,:)).^2))/ ...
        max(sqrt(mean(abs(clean{5}).^2)),eps);
    zrel=sqrt(mean(abs(clean{6}-bank.templates{1,6}(nominal,:)).^2))/ ...
        max(sqrt(mean(abs(clean{6}).^2)),eps);
    assert(hrel<1e-12&&zrel>1e-4, ...
        'The baseline CFR mirror overlap or Zin difference was not reproduced.');
    sigma=ones(1,numel(cfg.view_names));sigma(5)=0.03;sigma(6)=1;
    p=stage7a4_profile_views(clean,bank,[1 2],[5 6],sigma);
    assert(p.distances(2)<1e-10&&p.best_template_indices(2)==nominal, ...
        'A joint clean observation did not recover one shared nuisance row.');
    info=stage7a4_information_distance(bank,[1 2],[5 6],sigma);
    assert(isfinite(info.min_joint_distance)&&info.min_joint_distance>=0&& ...
        info.fixed_relative_rms_per_view(1)<1e-12);
    a=[0.1 5;0.2 4;0.15 6;5 0.1;4 0.2;6 0.15];
    model=stage7a4_calibrate_decision(a,[1;1;1;2;2;2],a,bank, ...
        [1 2],[5 6],sigma,cfg,'unit');
    z=stage7a4_decide(clean,bank,model);
    assert(ismember(z.decision_state,{'UNIQUE_CONFIDENT','MULTIPLE_AMBIGUOUS', ...
        'LOW_CONFIDENCE','REJECTED'})&&z.best_index==2);
    wrong=bank;wrong.identity='wrong';
    assert_throws(@()stage7a4_decide(clean,wrong,model),'stage7a4:BankIdentity');
    fprintf('PASS test_stage7a4_joint_profile: mirror, same-theta templates, decision identity\n');
end
function assert_throws(fun,id)
    hit=false;try,fun();catch ME,hit=strcmp(ME.identifier,id);end
    assert(hit,'Expected %s.',id);
end
