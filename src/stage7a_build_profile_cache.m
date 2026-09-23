function cache=stage7a_build_profile_cache(candidates,base,sc)
%STAGE7A_BUILD_PROFILE_CACHE Build each admissible CFR template once.
%   Inputs: candidate array, base configuration, Stage 7A configuration.
%   Output: complex H{k} is template-by-frequency for candidate k.
%   This function never receives an observation or its generating theta.
    assert(numel(candidates)>=2,'stage7a:TooFewCandidates','At least two candidates are required.');
    b=sc.search.main_scale_bounds;l=sc.search.branch_load_scale_bounds;
    main_grid=bounded_grid(b,sc.search.fine_main_step);
    load_grid=bounded_grid(l,sc.search.fine_load_step);
    coarse_main=bounded_grid(b,sc.search.coarse_main_step);
    coarse_load=bounded_grid(l,sc.search.coarse_load_step);
    [mg,lg]=ndgrid(main_grid,load_grid);
    main_values=mg(:);load_values=lg(:);
    coarse=ismembertol(main_values,coarse_main,1e-10)& ...
        ismembertol(load_values,coarse_load,1e-10);
    assert(any(coarse),'stage7a:MissingCoarseGrid','No coarse template was selected.');
    ids=cell(1,numel(candidates));H=cell(1,numel(candidates));
    admissible=cell(1,numel(candidates));signatures=cell(1,numel(candidates));
    start=tic;forward_count=0;
    for k=1:numel(candidates)
        c=candidates(k);ids{k}=candidate_id(c);
        assert(isfield(c,'network')&&isfield(c.network,'main_lengths')&& ...
            all(abs(c.network.main_lengths-sc.search.main_nominal_length_m)<1e-10), ...
            'stage7a:UnsupportedNominalLength', ...
            'Candidate %s does not use the audited 20 m main-edge nominal.',ids{k});
        candidate_bounds=main_bounds(c,sc.search);
        allow=main_values>=candidate_bounds(1)-1e-12 & main_values<=candidate_bounds(2)+1e-12;
        assert(any(allow&coarse),'stage7a:NoAdmissibleTemplate', ...
            'Candidate %s has no admissible coarse template.',ids{k});
        admissible{k}=allow;
        signatures{k}=stage6b_network_signature(c.network);
        H{k}=complex(NaN(numel(main_values),numel(sc.frequency_hz)));
        for q=find(allow).'
            theta=theta_at(main_values(q),load_values(q),sc.search);
            H{k}(q,:)=stage6b_forward_cfr(c.network,theta,base,sc.frequency_hz,sc.measurement_kind);
            forward_count=forward_count+1;
        end
    end
    cache=struct('candidate_ids',{ids},'candidate_signatures',{signatures}, ...
        'H',{H},'main_scale',main_values,'branch_load_scale',load_values, ...
        'coarse_mask',coarse,'admissible',{admissible},'frequency_hz',sc.frequency_hz, ...
        'forward_evaluation_count',forward_count,'build_time_s',toc(start), ...
        'definition_version','stage7a_truth_free_cached_coarse_to_fine_v1');
end

function grid=bounded_grid(bounds,step)
    span=(bounds(2)-bounds(1))/step;
    assert(abs(span-round(span))<1e-9&&span>=1,'stage7a:GridDivisibility', ...
        'Search step must divide the declared bounded interval.');
    grid=linspace(bounds(1),bounds(2),round(span)+1);
end
function theta=theta_at(main,load,search)
    theta=struct('main_length_scale',main,'branch_length_scale',search.branch_length_scale, ...
        'branch_load_scale',load,'source_impedance_ohm',search.source_impedance_ohm, ...
        'receiver_impedance_ohm',search.receiver_impedance_ohm,'regularization',0);
end
function id=candidate_id(c)
    if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);
    elseif isfield(c,'id')&&~isempty(c.id),id=char(c.id);
    else,error('stage7a:MissingCandidateId','Candidate identifier is required.');end
end
function bounds=main_bounds(c,search)
    bounds=search.main_scale_bounds;
    if ~isfield(c,'length_interval_per_edge')||isempty(c.length_interval_per_edge),return;end
    if ~isfield(c.network,'adapter_metadata')|| ...
            ~isfield(c.network.adapter_metadata,'path_node_ids')
        error('stage7a:MissingPathMetadata','Audited partial-prior candidate lacks path metadata.');
    end
    nodes=c.network.adapter_metadata.path_node_ids;
    intervals=c.length_interval_per_edge;
    for q=1:numel(nodes)-1
        pair=sort({char(nodes{q}),char(nodes{q+1})});key=[pair{1} '--' pair{2}];
        ix=find(strcmp({intervals.edge_key},key),1);
        assert(~isempty(ix),'stage7a:MissingLengthInterval','Missing main-edge prior interval %s.',key);
        x=intervals(ix);
        bounds(1)=max(bounds(1),x.minimum_m/x.nominal_m);
        bounds(2)=min(bounds(2),x.maximum_m/x.nominal_m);
    end
    % Apply the Stage 6A total-length interval only to partial-prior graphs.
    % It does not constrain the broader Stage 6B radial grammar.
    main_total=sum(c.network.main_lengths);
    branch_total=sum([c.network.branches.length])*search.branch_length_scale;
    total_range=search.partial_prior_total_length_range_m;
    bounds(1)=max(bounds(1),(total_range(1)-branch_total)/main_total);
    bounds(2)=min(bounds(2),(total_range(2)-branch_total)/main_total);
    assert(bounds(1)<=bounds(2),'stage7a:EmptyLengthDomain','Candidate length domain is empty.');
end
