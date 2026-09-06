function evidence = run_stage4a6_1_member_batch(indices,topology_decisions,observations,raw,cache,base,grid,cfg,domain,sc)
%RUN_STAGE4A6_1_MEMBER_BATCH Fit independent accepted cases in one outer batch.
%   Parallelism is deliberately restricted to this outer case dimension.

    evidence = cell(numel(indices),1);
    use_parallel = isfield(sc,'parallel') && sc.parallel.use_parallel && ...
        exist('parpool','file') == 2;
    if use_parallel
        ensure_pool(sc.parallel.num_workers);
        parfor q=1:numel(indices)
            evidence{q}=case_evidence(indices(q),topology_decisions,observations,raw,cache,base,grid,cfg,domain,sc);
        end
    else
        for q=1:numel(indices)
            evidence{q}=case_evidence(indices(q),topology_decisions,observations,raw,cache,base,grid,cfg,domain,sc);
        end
    end
end

function out=case_evidence(i,td,obs,raw,cache,base,grid,cfg,domain,sc)
    ids_text=td(i).accepted_topology_set;
    if isempty(ids_text), ids_text=raw{i}.best_equivalence_members; end
    ids=strsplit(ids_text,',');members=struct([]);
    for k=1:numel(ids)
        g=find(strcmp({base.topology_id},ids{k}),1);ti=find(strcmp(raw{i}.topology_labels,ids{k}),1);
        if isempty(g)||isempty(ti),continue;end
        ix=raw{i}.topk_evidence.topK_template_indices{ti};
        starts=[cache.templates(ix(1:min(3,numel(ix)))).theta];
        fit_options=sc.optimization;
        fit_options.profile=sc.profile;
        e=compute_stage4a6_1_member_evidence(obs{i},grid.frequency_hz,base(g),cfg,domain,starts,fit_options);
        members=append(members,e);
    end
    out=members;
end

function ensure_pool(n)
    pool=gcp('nocreate');
    if isempty(pool)
        cluster=parcluster('local');
        if cluster.NumWorkers<n, cluster.NumWorkers=n; end
        parpool(cluster,n);
    elseif pool.NumWorkers~=n,error('stage4a6_1:WorkerMismatch','Existing pool has %d workers; requested %d.',pool.NumWorkers,n);end
end
function y=append(x,z),if isempty(z),y=x;elseif isempty(x),y=z(:);else,y=[x(:);z(:)];end,end
