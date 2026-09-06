function out = remap_out_of_library_topology_ids(out, candidates)
%REMAP_OUT_OF_LIBRARY_TOPOLOGY_IDS Assign stable IDs disjoint from library IDs.
    if isempty(out),return;end
    candidate_ids={candidates.topology_id};candidate_keys={candidates.canonical_key};
    [~,order]=sort({out.canonical_key});out=out(order);
    for k=1:numel(out),out(k).topology_id=sprintf('OOG%03d',k);end
    assert(isempty(intersect(candidate_ids,{out.topology_id})), ...
        'stage4a5_1:OutOfLibraryIdCollision','OOL IDs collide with candidate IDs.');
    assert(isempty(intersect(candidate_keys,{out.canonical_key})), ...
        'stage4a5_1:OutOfLibraryKeyCollision','OOL canonical keys collide with candidate keys.');
end
