function test_stage7a11_selector(root)
%TEST_STAGE7A11_SELECTOR Candidate order, shared theta, truth-free gate tests.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    names=arrayfun(@(x)sprintf('view_%d',x),1:17,'UniformOutput',false);
    bank=struct('identity','synthetic_bank','candidate_ids',{{'X','Y'}}, ...
        'view_names',{names},'params',[1;2],'templates',{cell(2,17)});
    for k=1:2
        for v=1:17,bank.templates{k,v}=zeros(2,1);end
    end
    % Two physical parameter rows: the joint surface must not combine
    % H50 from row 1 with an extra view from row 2 of the same candidate.
    bank.templates{1,5}=[0;10];bank.templates{2,5}=[2;12];
    bank.templates{1,3}=[0;100];bank.templates{2,3}=[4;104];
    bank.templates{1,7}=[0;100];bank.templates{2,7}=[1;101];
    bank.templates{1,11}=[0;100];bank.templates{2,11}=[2;102];
    bank.templates{1,12}=[0;100];bank.templates{2,12}=[3;103];
    bank.templates{1,13}=[0;100];bank.templates{2,13}=[2;102];
    bank.templates{1,14}=[0;100];bank.templates{2,14}=[3;103];
    bank.templates{1,15}=[0;100];bank.templates{2,15}=[2;102];
    bank.templates{1,16}=[0;100];bank.templates{2,16}=[3;103];
    sigma=ones(1,17);selector=stage7a11_view_selector(bank,sigma,[3 7 12 14 16]);
    expected=sqrt((2^2+4^2)/2);
    assert(abs(selector.surfaces{1,2,1}(1,1)-expected)<1e-12, ...
        'Joint view must use the same parameter row across observations.');
    observed=cell(1,17);
    for v=1:17,observed{v}=bank.templates{1,v}(1,:);end
    p=stage7a11_adaptive_profile(observed,bank,1:2,sigma,selector,[1 1]);
    assert(p.selected_view==3 && p.first_set(1) && ~p.first_set(2), ...
        'H50 conditioning or predeclared tie order failed.');
    assert(isequal(p.competition_indices,[1 2]), ...
        'Singleton H50 set needs runner-up as a diagnostic competitor.');
    % Candidate order must not change the selected physical view.
    perm=bank;perm.candidate_ids=fliplr(bank.candidate_ids);
    perm.templates=flipud(bank.templates);perm.identity='permuted_bank';
    sel2=stage7a11_view_selector(perm,sigma,[3 7 12 14 16]);
    p2=stage7a11_adaptive_profile(observed,perm,1:2,sigma,sel2,[1 1]);
    assert(p.selected_view==p2.selected_view && ...
        isequal(sort(p.distances),sort(p2.distances)), ...
        'Graph order changed the physical selection or distances.');
    a=[0;0;0;0];truth=[1;1;2;2];
    model=stage7a10_calibrate([a a],truth,[a a],truth,[a a], ...
        bank,1:2,sigma,selector,struct('alpha',0.2, ...
        'separation_threshold',0,'extra_view_threshold',0));
    model.first_threshold=[1 1];model.class_threshold=[Inf Inf];
    model.fit_threshold=Inf;z=stage7a11_decide(observed,bank,model);
    assert(z.candidate_set_size<=nnz(z.first_set), ...
        'Final set must be a subset of first-stage candidates.');
    model.first_threshold=[-Inf -Inf];z=stage7a11_decide(observed,bank,model);
    assert(strcmp(z.decision_state,'REJECTED') && ...
        strcmp(z.decision_reason,'empty_first_set'),'Empty first set did not reject.');
    symmetric=bank;symmetric.templates(2,:)=symmetric.templates(1,:);
    symmetric.identity='symmetric_bank';
    ss=stage7a11_view_selector(symmetric,sigma,[3 7 12 14 16]);
    model.bank_identity=symmetric.identity;model.candidate_ids=symmetric.candidate_ids;
    model.selector=ss;model.first_threshold=[Inf -Inf];
    model.class_threshold=[Inf -Inf];model.fit_threshold=Inf;
    model.extra_view_threshold=3;
    z=stage7a11_decide(observed,symmetric,model);
    assert(strcmp(z.decision_state,'LOW_CONFIDENCE') && ...
        z.extra_view_separation==0, ...
        'Strictly symmetric graphs must not be forced to a unique state.');
    bad=model;bad.selector.identity='tampered';
    bad.selector.bank_identity='wrong';
    try
        stage7a11_decide(observed,symmetric,bad);
        error('stage7a11:ExpectedIdentityError');
    catch err
        assert(strcmp(err.identifier,'stage7a11:BankIdentity'), ...
            'Calibration/selector identity mismatch was not detected.');
    end
    fprintf('PASS test_stage7a11_selector: rows, order, sets, symmetry, identity\n');
end
