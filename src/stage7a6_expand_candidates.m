function out=stage7a6_expand_candidates(observed,pool,bank,base,cfg, ...
        base_indices,views,sigma,budget)
%STAGE7A6_EXPAND_CANDIDATES Budgeted graph edit with full evaluation count.
%   Inputs contain observed complex spectra only, never truth ID or nuisance.
%   The graph search and tie order match Stage 7A.5; profile evaluations
%   from every round are counted rather than just the final round.
    assert(ismember(budget,cfg.candidate_budgets),'stage7a6:CandidateBudget');
    assert(isequal({pool.topology_id},bank.candidate_ids), ...
        'stage7a6:BankCandidateOrder');
    active=base_indices(:).';
    depth=inf(1,numel(pool));depth(active)=0;
    expanded=false(1,numel(pool));
    generated=[];frontier_log={};truncated=false;
    p=stage7a5_profile(observed,pool,bank,base,cfg,active,views,sigma, ...
        cfg.frequency_train_indices,true);
    total_evals=sum(p.evaluations);
    total_profile_count=numel(active);
    for round=0:cfg.max_edit_depth-1
        eligible=active(~expanded(active)&depth(active)<=round);
        if isempty(eligible),break;end
        [~,ord]=sort(p.distances(ismember(active,eligible)));
        eligible=eligible(ord(1:min(cfg.top_k,numel(ord))));
        frontier_log{end+1}=bank.candidate_ids(eligible); %#ok<AGROW>
        additions=[];
        for parent=eligible
            expanded(parent)=true;
            near=stage7a5_graph_edit_neighbors(pool,parent);
            for child=near
                if ismember(child,active),continue;end
                if numel(active)>=budget
                    truncated=true;
                    continue;
                end
                sig=bank.candidate_signatures{child};
                if any(strcmp(bank.candidate_signatures(active),sig)),continue;end
                active(end+1)=child;depth(child)=depth(parent)+1;
                generated(end+1)=child;additions(end+1)=child; %#ok<AGROW>
            end
        end
        if isempty(additions),break;end
        p=stage7a5_profile(observed,pool,bank,base,cfg,active,views,sigma, ...
            cfg.frequency_train_indices,true);
        total_evals=total_evals+sum(p.evaluations);
        total_profile_count=total_profile_count+numel(active);
    end
    [active,order]=sort(active);
    p.candidate_indices=p.candidate_indices(order);
    p.candidate_ids=p.candidate_ids(order);
    p.distances=p.distances(order);
    p.grid_distances=p.grid_distances(order);
    p.params=p.params(order,:);
    p.grid_rows=p.grid_rows(order);
    p.evaluations=p.evaluations(order);
    p.exitflag=p.exitflag(order);
    out=p;
    out.active_indices=active;
    out.active_ids=bank.candidate_ids(active);
    out.generated_indices=generated;
    out.generated_ids=bank.candidate_ids(generated);
    out.search_frontiers=frontier_log;
    out.search_truncated=truncated;
    out.total_optimizer_evaluations=total_evals;
    out.total_profile_evaluations=total_profile_count;
    out.profile_candidate_count=numel(active);
end
