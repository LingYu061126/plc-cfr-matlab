function test_stage7a_profile_search()
%TEST_STAGE7A_PROFILE_SEARCH Bound, cache, truth isolation and decision API.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage7a_profile_search_config(base,'smoke');
    assert(max(abs(sc.search.main_scale_bounds-[.9 1.1]))<1e-12, ...
        'Stage 7A main-length bounds no longer match the Stage 6A prior.');
    assert(max(abs(sc.search.branch_load_scale_bounds-[.8 1.2]))<1e-12, ...
        'Stage 7A synthetic load range changed.');
    grammar=sc.stage6b.scale.grammars(2);
    library=stage6b_build_candidate_library('radial_grammar',grammar,base,struct());
    cache=stage7a_build_profile_cache(library,base,sc);
    assert(numel(cache.H)==7&&cache.forward_evaluation_count==7*45, ...
        'Expected exactly one forward CFR per candidate and admissible template.');
    options=struct('rank',sc.stage6b.rank,'export',sc.stage6b.export);
    partial=stage6b_build_candidate_library('partial_prior',sc.prior,base,options);
    partial_cache=stage7a_build_profile_cache(partial,base,sc);
    for k=1:numel(partial)
        scale=partial_cache.main_scale(partial_cache.admissible{k});
        if isempty(partial(k).network.branches)
            assert(min(scale)>=1-1e-12,'No-branch partial prior violated total-length minimum.');
        elseif numel(partial(k).network.branches)==2
            assert(max(scale)<=1+1e-12,'Two-branch partial prior violated total-length maximum.');
        end
    end
    truth=find(arrayfun(@(x)isequal(sort([x.network.branches.node]),2),library),1);
    theta=struct('main_length_scale',1.05,'branch_length_scale',1, ...
        'branch_load_scale',1.1,'source_impedance_ohm',sc.search.source_impedance_ohm, ...
        'receiver_impedance_ohm',sc.search.receiver_impedance_ohm,'regularization',0);
    y=stage6b_forward_cfr(library(truth).network,theta,base,sc.frequency_hz,sc.measurement_kind);
    a=stage7a_profile_distance(y,cache,sc.search);
    assert(a.forward_evaluations==0&&a.profile_distances(truth)<1e-12&& ...
        abs(a.best_main_scale(truth)-1.05)<1e-12&& ...
        abs(a.best_branch_load_scale(truth)-1.1)<1e-12, ...
        'Bounded coarse-to-fine cache did not recover an on-grid truth.');
    [model,~]=stage7a_calibrate_candidate_library(library,base,sc,'unit_test',800000);
    out=stage7a_score_observation(y,model,sc.search);
    assert(isfinite(out.distance)&&out.best_index>=1&& ...
        ismember(out.decision_state,{'UNIQUE_CONFIDENT','MULTIPLE_AMBIGUOUS', ...
        'LOW_CONFIDENCE','REJECTED'}),'Stage 7A decision contract is invalid.');
    assert(strcmp(out.normalized_score_semantics,'not_a_Bayesian_posterior'), ...
        'Normalized score was incorrectly labeled as probability.');
    wrong_search=sc.search;wrong_search.coarse_main_step=0.10;
    assert_throws(@()stage7a_score_observation(y,model,wrong_search), ...
        'stage7a:CalibrationIdentityMismatch');
    wrong_model=model;wrong_model.cache.candidate_signatures{1}='wrong_network';
    assert_throws(@()stage7a_score_observation(y,wrong_model,sc.search), ...
        'stage7a:CalibrationIdentityMismatch');
    wrong_model=model;wrong_model.cache.main_scale(1)=0.91;
    assert_throws(@()stage7a_score_observation(y,wrong_model,sc.search), ...
        'stage7a:CalibrationIdentityMismatch');
    assert_throws(@() stage7a_profile_distance(y(1:end-1),cache,sc.search), ...
        'stage7a:InvalidObservation');
    assert_throws(@() stage7a_build_profile_cache(library(1),base,sc), ...
        'stage7a:TooFewCandidates');
    fprintf('  PASS Stage 7A prior-derived bounds, cached coarse-to-fine profile and truth-free scoring\n');
end
function assert_throws(fun,id)
    ok=false;
    try,fun();catch ME,ok=strcmp(ME.identifier,id);end
    assert(ok,'Expected MATLAB error %s.',id);
end
