function test_stage6b_robustness()
%TEST_STAGE6B_ROBUSTNESS Library perturbation, scale and decision interfaces.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6b_robustness_config(base,'smoke');options=struct('rank',sc.rank,'export',sc.export);
    correct=sc.prior.base_prior;wrong_open=set_switch(correct,sc.prior.wrong_open_edge,'open');
    wrong_closed=set_switch(correct,sc.prior.wrong_closed_edge,'closed');
    [a,~,~]=stage6b_build_candidate_library('partial_prior',correct,base,options);
    [b,~,~]=stage6b_build_candidate_library('partial_prior',wrong_open,base,options);
    [c,~,~]=stage6b_build_candidate_library('partial_prior',wrong_closed,base,options);
    assert(isequal([numel(a) numel(b) numel(c)],[7 4 3]),'Prior perturbation candidate counts changed.');
    truth=find(arrayfun(@(x)isequal(sort([x.network.branches.node]),2),a),1);truth_key=stage6b_network_signature(a(truth).network);
    assert(any(strcmp(arrayfun(@(x)stage6b_network_signature(x.network),a,'UniformOutput',false),truth_key)), ...
        'Unperturbed library lost truth.');
    assert(~any(strcmp(arrayfun(@(x)stage6b_network_signature(x.network),b,'UniformOutput',false),truth_key)), ...
        'Wrong-open library unexpectedly retained truth.');
    assert(~any(strcmp(arrayfun(@(x)stage6b_network_signature(x.network),c,'UniformOutput',false),truth_key)), ...
        'Wrong-closed library unexpectedly retained truth.');
    counts=zeros(1,3);
    for k=1:3,lib=stage6b_build_candidate_library('radial_grammar',sc.scale.grammars(k),base,struct());counts(k)=numel(lib);end
    assert(isequal(counts,[3 7 23]),'Small/medium/large candidate counts changed.');
    [model,~]=stage6b_calibrate_candidate_library(a,base,sc,'stage6b_test',900000);
    theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1, ...
        'source_impedance_ohm',sc.parameter_search.source_impedance_ohm(1), ...
        'receiver_impedance_ohm',sc.parameter_search.receiver_impedance_ohm(1),'regularization',0);
    observation=stage6b_forward_cfr(a(truth).network,theta,base,sc.frequency_hz,sc.measurement_kind);
    result=stage6b_evaluate_observation(observation,model,a(truth).network);
    assert(result.best_is_truth&&~result.false_unique&&isfinite(result.margin), ...
        'Stage 6B evaluation interface failed on an in-library truth.');
    saved=load(sc.identifiability.stage5b1_model_file,'evidence_model');d=[0 1e-16 1e-7];
    margin=compute_candidate_margin(d,{'A','B','C'});confidence=compute_candidate_confidence(d,saved.evidence_model.beta,{'A','B','C'});
    frozen=struct('candidate_set_size',3,'domain_accepted',true,'best_candidate_in_set',true);
    decision=classify_stage5b1_decision_state(frozen,struct('margin',margin.margin), ...
        struct('top1_confidence',confidence.top1_confidence,'normalized_entropy',confidence.normalized_entropy),saved.evidence_model);
    assert(strcmp(decision.enhanced_decision_state,'MULTIPLE_AMBIGUOUS'), ...
        'Three-candidate near-tie was not expressed as ambiguity.');
    fprintf('  PASS Stage 6B prior perturbation, candidate scale, evaluation and identifiability interfaces\n');
end

function p=set_switch(p,edge,state)
    for k=1:numel(p.switch_state)
        if isequal(sort({p.switch_state(k).from,p.switch_state(k).to}),sort(edge)),p.switch_state(k).state=state;return;end
    end
    error('stage6b:SwitchNotFound','Switch edge not found.');
end
