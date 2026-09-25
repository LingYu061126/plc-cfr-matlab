function [all4,pair_indices,library_indices]=stage7a4_fixed_topologies(base)
%STAGE7A4_FIXED_TOPOLOGIES Exact 3-library and withheld M3 mirror network.
%   Candidate nodes/edges are generated from the same physical grammar;
%   merely changing a network branch field would leave metadata inconsistent.
    sc=stage7a_profile_search_config(base,'formal');
    grammar=sc.stage6b.scale.grammars(1);
    old=generate_radial_topology_candidates(grammar);
    assert(numel(old)==3&&strcmp(old(3).topology_id,'G003'), ...
        'stage7a4:LegacyLibraryIdentity');
    extended=grammar;extended.allowed_branch_main_nodes=[1 2 3];
    extended.max_side_branches_per_node=1;extended.max_branches=1;
    extended.max_nodes=6;extended.max_candidates=16;
    pool=generate_radial_topology_candidates(extended);
    target='M=20,20,20,20,|T=0,0,0,0,|B=3,15,1,50;';
    signatures=arrayfun(@(x)stage6b_network_signature(x.network),pool,'UniformOutput',false);
    ix=find(strcmp(signatures,target));
    assert(numel(ix)==1,'stage7a4:MissingMirror','M3 mirror is missing from grammar.');
    mirror=pool(ix);mirror.topology_id='MIRROR_M3';
    old_signatures=arrayfun(@(x)stage6b_network_signature(x.network),old,'UniformOutput',false);
    assert(~ismember(target,old_signatures),'stage7a4:TruthLeakage', ...
        'The mirror topology is unexpectedly in the original three-candidate library.');
    all4=[old,mirror];library_indices=1:3;pair_indices=[3 4];
end
