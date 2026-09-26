function out=stage7a5_expand_candidates(observed,pool,bank,base,cfg, ...
        base_indices,views,sigma,frequency_indices,budget)
%STAGE7A5_EXPAND_CANDIDATES Observation-driven, budgeted one-level graph search.
%   No truth labels or generating nuisance values are accepted by this API.
    assert(ismember(budget,cfg.candidate_budgets),'stage7a5:CandidateBudget');
    assert(strcmp(bank.identity,bank_identity(pool,bank)),'stage7a5:BankOrder');
    active=base_indices(:).';depth=inf(1,numel(pool));depth(active)=0;
    expanded=false(1,numel(pool));generated=[];frontier_log={};
    profile=stage7a5_profile(observed,pool,bank,base,cfg,active,views,sigma, ...
        frequency_indices,true);
    truncated=false;
    for round=0:cfg.max_edit_depth-1
        eligible=active(~expanded(active)&depth(active)<=round);
        if isempty(eligible),break;end
        [~,ord]=sort(profile.distances(ismember(active,eligible)));
        eligible=eligible(ord(1:min(cfg.top_k,numel(ord))));
        frontier_log{end+1}=bank.candidate_ids(eligible); %#ok<AGROW>
        additions=[];
        for parent=eligible
            expanded(parent)=true;
            near=stage7a5_graph_edit_neighbors(pool,parent);
            for child=near
                if ismember(child,active),continue;end
                if numel(active)>=budget,truncated=true;continue;end
                sig=bank.candidate_signatures{child};
                if any(strcmp(bank.candidate_signatures(active),sig)),continue;end
                active(end+1)=child;depth(child)=depth(parent)+1;
                generated(end+1)=child;additions(end+1)=child; %#ok<AGROW>
            end
        end
        if isempty(additions),break;end
        profile=stage7a5_profile(observed,pool,bank,base,cfg,active,views,sigma, ...
            frequency_indices,true);
    end
    % Re-score all active hypotheses in stable grammar order for calibration/output.
    [active,ord]=sort(active);
    profile.candidate_indices=profile.candidate_indices(ord);
    profile.candidate_ids=profile.candidate_ids(ord);
    profile.distances=profile.distances(ord);
    profile.grid_distances=profile.grid_distances(ord);
    profile.params=profile.params(ord,:);
    profile.grid_rows=profile.grid_rows(ord);
    profile.evaluations=profile.evaluations(ord);
    profile.exitflag=profile.exitflag(ord);
    out=profile;out.generated_indices=generated;out.active_indices=active;
    out.generated_ids=bank.candidate_ids(generated);
    out.active_ids=bank.candidate_ids(active);out.search_frontiers=frontier_log;
    out.search_truncated=truncated;out.profile_candidate_count=numel(active);
    out.forward_model_calls_in_search=0;
end

function id=bank_identity(pool,bank)
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool,'UniformOutput',false);
    assert(isequal(sigs,bank.candidate_signatures)&& ...
        isequal({pool.topology_id},bank.candidate_ids),'stage7a5:BankCandidateMismatch');
    id=bank.identity;
end
