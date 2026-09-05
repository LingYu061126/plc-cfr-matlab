function candidates = generate_prior_constrained_candidates(grammar, asset_prior)
%GENERATE_PRIOR_CONSTRAINED_CANDIDATES Filter the Stage-4A.1 tree grammar.
%   Hard prior rules exclude infeasible current-model trees; soft rules only
%   score retained candidates. P0 with an empty edge-prior reproduces the
%   Stage-4A.1 count, order and canonical keys.

    asset_prior=validate_topology_prior_consistency(asset_prior,grammar);
    base=generate_radial_topology_candidates(grammar);
    keep=false(1,numel(base)); scored=base;
    for k=1:numel(base)
        [keep(k),trace,hard,score,intervals,cables]=evaluate_candidate(base(k),asset_prior,grammar);
        scored(k).prior_trace=trace; scored(k).satisfied_hard_constraints=hard;
        scored(k).soft_prior_score=score; scored(k).length_interval_per_edge=intervals;
        scored(k).permitted_cable_types=cables; scored(k).prior_config_hash=asset_prior.prior_config_hash;
    end
    candidates=scored(keep);
end

function [ok,trace,hard,score,intervals,cables]=evaluate_candidate(c,prior,grammar)
    edges=c.edges; trace={};hard={};score=0;ok=true;
    intervals=repmat(struct('edge_id','','length_min_m',0,'length_max_m',Inf),1,numel(edges));
    cables=cell(1,numel(edges));
    for q=1:numel(edges), intervals(q)=struct('edge_id',edges(q).id,'length_min_m',0,'length_max_m',Inf); cables{q}=[]; end
    eprior=prior.edge_prior;
    for p=1:numel(eprior)
        matched=false(1,numel(edges));
        for q=1:numel(edges)
            matched(q)=edge_matches(edges(q),eprior(p));
            if matched(q)
                intervals(q).length_min_m=max(intervals(q).length_min_m,eprior(p).length_min_m);
                intervals(q).length_max_m=min(intervals(q).length_max_m,eprior(p).length_max_m);
                if ~isempty(eprior(p).permitted_cable_types), cables{q}=eprior(p).permitted_cable_types; end
                valid_length=edges(q).length_m>=intervals(q).length_min_m && edges(q).length_m<=intervals(q).length_max_m;
                valid_cable=isempty(cables{q}) || ismember(edges(q).cable_type,cables{q});
                if strcmp(eprior(p).prior_kind,'hard') && (~valid_length || ~valid_cable), ok=false; trace{end+1}=sprintf('edge %s violates hard length/cable rule',edges(q).id); end %#ok<AGROW>
            end
        end
        if strcmp(eprior(p).prior_kind,'hard')
            if ~eprior(p).allowed && any(matched)
                ok=false; trace{end+1}=sprintf('edge %s-%s is not allowed',eprior(p).from,eprior(p).to); %#ok<AGROW>
            end
            if eprior(p).required && ~any(matched), ok=false; trace{end+1}=sprintf('required edge %s-%s absent',eprior(p).from,eprior(p).to); else
                if eprior(p).required, hard{end+1}=sprintf('required edge %s-%s satisfied',eprior(p).from,eprior(p).to); end %#ok<AGROW>
            end
            if eprior(p).forbidden && any(matched), ok=false; trace{end+1}=sprintf('forbidden edge %s-%s present',eprior(p).from,eprior(p).to); else
                if eprior(p).forbidden, hard{end+1}=sprintf('forbidden edge %s-%s absent',eprior(p).from,eprior(p).to); end %#ok<AGROW>
            end
        elseif any(matched)
            score=score+1; trace{end+1}=sprintf('soft edge preference %s-%s matched',eprior(p).from,eprior(p).to); %#ok<AGROW>
        end
    end
    degrees=zeros(1,numel(c.nodes)); ids={c.nodes.id};
    for q=1:numel(edges), degrees(strcmp(ids,edges(q).from))=degrees(strcmp(ids,edges(q).from))+1; degrees(strcmp(ids,edges(q).to))=degrees(strcmp(ids,edges(q).to))+1; end
    if any(degrees>prior.network_rules.maximum_degree), ok=false; trace{end+1}='maximum degree violated'; end %#ok<AGROW>
    if any(~ismember([c.network.branches.node],prior.network_rules.permitted_branch_nodes)), ok=false; trace{end+1}='permitted branch node rule violated'; end %#ok<AGROW>
    if ok, hard{end+1}='radial rule satisfied'; trace{end+1}='length range feasible'; end %#ok<AGROW>
end
function hit=edge_matches(edge,rule)
    hit=(strcmp(rule.edge_kind,'any')||strcmp(rule.edge_kind,edge.kind)) && ...
        ((wild(rule.from,edge.from)&&wild(rule.to,edge.to))||(wild(rule.from,edge.to)&&wild(rule.to,edge.from)));
end
function ok=wild(rule,value),ok=strcmp(rule,'*')||strcmp(rule,value);end
