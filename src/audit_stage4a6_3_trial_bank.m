function audit = audit_stage4a6_3_trial_bank(bank, candidates, sc)
%AUDIT_STAGE4A6_3_TRIAL_BANK Check identity, split and active-mask coverage.
    if isempty(bank),error('stage4a6_3:EmptyTrialBank','Trial bank is empty.');end
    ids={bank.sample_id};if numel(unique(ids))~=numel(ids),error('stage4a6_3:DuplicateSampleID','Sample IDs overlap.');end
    keys={candidates.canonical_key};tkeys={bank.canonical_key};
    if any(~ismember(tkeys,keys)),error('stage4a6_3:UnknownCanonicalKey','Unknown candidate canonical key.');end
    topology_ids={candidates.topology_id};
    if numel(unique(topology_ids))~=7,error('stage4a6_3:TopologyCount','Expected seven P0 topologies, got %d.',numel(topology_ids));end
    split={bank.split};sets=unique(split);overlap={};
    for i=1:numel(sets),for j=i+1:numel(sets),if any(ismember({bank(strcmp(split,sets{i})).sample_id},{bank(strcmp(split,sets{j})).sample_id})),overlap{end+1}=[sets{i} '|' sets{j}];end,end,end %#ok<AGROW>
    if ~isempty(overlap),error('stage4a6_3:SplitOverlap','Split sample IDs overlap.');end
    seed_overlap_count=0;
    for i=1:numel(sets)
        for j=i+1:numel(sets)
            si=unique([bank(strcmp(split,sets{i})).seed]);sj=unique([bank(strcmp(split,sets{j})).seed]);
            seed_overlap_count=seed_overlap_count+numel(intersect(si,sj));
        end
    end
    if seed_overlap_count>0,error('stage4a6_3:SeedOverlap','Calibration/development/final seeds overlap.');end
    names=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta).names;
    bad_inactive=0;
    for k=1:numel(bank)
        active=topology_active_parameter_mask(candidates(strcmp(topology_ids,bank(k).truth_topology_id)),names);
        if strcmp(bank(k).parameter_domain_truth,'out_of_domain') && ~active(strcmp(names,bank(k).outlier_dimension)),bad_inactive=bad_inactive+1;end
    end
    if bad_inactive>0,error('stage4a6_3:InactiveOOD','OOD samples use inactive parameters.');end
    audit=struct('sample_count',numel(bank),'topology_count',numel(topology_ids), ...
        'topology_ids',strjoin(topology_ids,','),'split_count',numel(sets), ...
        'split_names',strjoin(sets,','),'split_overlap_count',numel(overlap), ...
        'unique_canonical_key_count',numel(unique(tkeys)), ...
        'inactive_ood_count',bad_inactive,'seed_count',numel(unique([bank.seed])), ...
        'seed_overlap_count',seed_overlap_count, ...
        'audit_status','passed');
end
