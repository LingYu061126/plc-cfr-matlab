function test_stage7a12_confirm(root)
%TEST_STAGE7A12_CONFIRM Identity, missing truth, candidate set and margins.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'));
    names=cell(1,17);names(:)={'unused'};
    templates=cell(3,17);
    for k=1:3
        for v=1:17,templates{k,v}=complex(k-1);end
    end
    bank=struct('identity','bank1','candidate_ids',{{'A','B','C'}}, ...
        'candidate_signatures',{{'sa','sb','sc'}}, ...
        'view_names',{names},'templates',{templates},'params',[1 1 1]);
    model=struct('bank_identity','bank1', ...
        'candidate_signatures',{{'sa','sb','sc'}},'sigma',ones(1,17), ...
        'class_threshold',1.1,'fit_threshold',1.1, ...
        'margin_threshold',0.5);
    obs=cell(1,17);obs(:)={complex(0)};
    z=stage7a12_confirm(obs,bank,model,[],1:3);
    assert(strcmp(z.decision_state,'REJECTED')&& ...
        strcmp(z.decision_reason,'empty_generated_library'));
    z=stage7a12_confirm(obs,bank,model,1,1:3);
    assert(strcmp(z.decision_state,'UNIQUE_CONFIDENT'));
    z=stage7a12_confirm(obs,bank,model,2,1:3);
    assert(strcmp(z.decision_state,'LOW_CONFIDENCE') || ...
        strcmp(z.decision_state,'REJECTED'), ...
        'Pruned true best may not become confident unique.');
    z=stage7a12_confirm(obs,bank,model,[1 2],1:3);
    assert(strcmp(z.decision_state,'MULTIPLE_AMBIGUOUS'));
    bad=model;bad.bank_identity='other';
    try
        stage7a12_confirm(obs,bank,bad,1,1:3);
        error('stage7a12:ExpectedIdentityError');
    catch err
        assert(strcmp(err.identifier,'stage7a12:BankIdentity'));
    end
    fprintf('PASS test_stage7a12_confirm: identity, empty, competing graphs\n');
end
