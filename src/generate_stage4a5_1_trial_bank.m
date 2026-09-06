function bank = generate_stage4a5_1_trial_bank(sc,split_kind)
%GENERATE_STAGE4A5_1_TRIAL_BANK Preserve A5 sampling with collision-free OOL IDs.
    if nargin<2,split_kind='all';end
    bank=generate_stage4a5_trial_bank(sc,split_kind);
    base=generate_radial_topology_candidates(sc.generator);
    ix=find(strcmp({bank.category},'structure_out'));
    if isempty(ix),return;end
    keys=unique({bank(ix).canonical_key},'sorted');
    out=repmat(struct('topology_id','','canonical_key',''),numel(keys),1);
    for k=1:numel(keys),out(k)=struct('topology_id','','canonical_key',keys{k});end
    out=remap_out_of_library_topology_ids(out,base);
    for k=1:numel(ix)
        q=find(strcmp(keys,bank(ix(k)).canonical_key),1);
        bank(ix(k)).truth_topology_id=out(q).topology_id;
    end
end
