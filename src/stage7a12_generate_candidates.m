function out=stage7a12_generate_candidates(Rhat,labels,pool,cfg,tolerance,top_k)
%STAGE7A12_GENERATE_CANDIDATES Truth-free bounded graph-template search.
%   Returns actual compatible candidate graph structs, not truth IDs.
%   Known meter labels/number form an explicit independent prior.
    assert(isscalar(tolerance)&&tolerance>=0&&top_k>=1, ...
        'stage7a12:GeneratorConfig');
    n=numel(pool);scores=inf(n,1);signatures=cell(n,1);valid=false(n,1);
    for k=1:n
        signatures{k}=stage6b_network_signature(pool(k).network);
        nominal=stage7a12_ci_matrix(pool(k).network,cfg);
        scale=Rhat(1,1)/nominal.R(1,1);
        scale=max(cfg.lf_candidate_main_scale_bounds(1), ...
            min(cfg.lf_candidate_main_scale_bounds(2),scale));
        profiled=pool(k).network;
        profiled.main_lengths=profiled.main_lengths*scale;
        ci=stage7a12_ci_matrix(profiled,cfg);
        if isequal(ci.labels,labels) && isequal(size(ci.R),size(Rhat))
            valid(k)=true;
            scores(k)=norm(ci.R-Rhat,'fro')/sqrt(numel(Rhat));
        end
    end
    assert(numel(unique(signatures))==n,'stage7a12:DuplicatePool');
    ids=string(signatures);
    ordering=table(scores,ids,(1:n)','VariableNames', ...
        {'score','signature','pool_index'});
    [~,order]=sortrows(ordering,{'score','signature','pool_index'});
    order=order(valid(order));
    selected=order(scores(order)<=tolerance);
    selected=selected(1:min(top_k,numel(selected)));
    out=struct('indices',selected(:).','graphs',pool(selected), ...
        'scores',scores,'eligible_indices',order(:).', ...
        'selected_signatures',{signatures(selected)}, ...
        'signature_order',{cellstr(ids(order))}, ...
        'eligible_count',numel(order),'candidate_count',numel(selected));
end
