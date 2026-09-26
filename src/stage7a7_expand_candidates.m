function out=stage7a7_expand_candidates(observed,pool,bank,base,cfg, ...
        base_indices,views,sigma,budget)
%STAGE7A7_EXPAND_CANDIDATES Incremental graph-edit search with safe completion.
%   Only observed spectra enter ranking. At full-pool budget, unvisited
%   candidates are explicitly scored; smaller budgets remain uncertified.
    assert(ismember(budget,cfg.candidate_budgets),'stage7a7:CandidateBudget');
    assert(isequal({pool.topology_id},bank.candidate_ids), ...
        'stage7a7:CandidateIdentity');
    active=base_indices(:).';
    depth=inf(1,numel(pool));depth(active)=0;
    expanded=false(1,numel(pool));generated=[];completion=[];
    blocked=0;frontier_log={};
    p=profile_new(active);
    for round=0:cfg.max_edit_depth-1
        eligible=active(~expanded(active)&depth(active)<=round);
        if isempty(eligible),break;end
        [~,loc]=ismember(eligible,p.candidate_indices);
        order=sortrows([reshape(p.distances(loc),[],1) eligible(:)], [1 2]);
        eligible=order(1:min(cfg.top_k,size(order,1)),2).';
        frontier_log{end+1}=bank.candidate_ids(eligible); %#ok<AGROW>
        additions=[];
        for parent=eligible
            expanded(parent)=true;
            near=stage7a7_graph_edit_neighbors(pool,parent);
            for child=near
                if ismember(child,active),continue;end
                if numel(active)>=budget
                    blocked=blocked+1;continue;
                end
                active(end+1)=child;depth(child)=depth(parent)+1; %#ok<AGROW>
                generated(end+1)=child;additions(end+1)=child; %#ok<AGROW>
            end
        end
        if isempty(additions),continue;end
        p=append_profile(p,profile_new(additions));
    end
    if budget==numel(pool)
        completion=setdiff(1:numel(pool),active,'stable');
        if ~isempty(completion)
            p=append_profile(p,profile_new(completion));
            active=[active completion];
        end
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
    out=p;out.active_indices=active;
    out.active_ids=bank.candidate_ids(active);
    out.generated_indices=generated;
    out.generated_ids=bank.candidate_ids(generated);
    out.completion_indices=completion;
    out.completion_ids=bank.candidate_ids(completion);
    out.search_frontiers=frontier_log;
    out.pool_exhausted=numel(active)==numel(pool);
    out.search_truncated=~out.pool_exhausted;
    out.budget_blocked_count=blocked;
    out.unvisited_count=numel(pool)-numel(active);
    out.frontier_limited=~out.pool_exhausted&&blocked==0;
    out.total_optimizer_evaluations=sum(p.evaluations);
    out.total_profile_evaluations=numel(active);
    out.profile_candidate_count=numel(active);
    function z=profile_new(ix)
        z=stage7a5_profile(observed,pool,bank,base,cfg,ix,views,sigma, ...
            cfg.frequency_train_indices,true);
    end
end
function p=append_profile(p,q)
    p.candidate_indices=[p.candidate_indices q.candidate_indices];
    p.candidate_ids=[p.candidate_ids q.candidate_ids];
    p.distances=[p.distances q.distances];
    p.grid_distances=[p.grid_distances q.grid_distances];
    p.params=[p.params;q.params];
    p.grid_rows=[p.grid_rows q.grid_rows];
    p.evaluations=[p.evaluations q.evaluations];
    p.exitflag=[p.exitflag q.exitflag];
    assert(numel(unique(p.candidate_indices))==numel(p.candidate_indices), ...
        'stage7a7:DuplicateProfile');
end
