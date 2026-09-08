function out = stage4a7_1_multinode_tomography_capability(observation)
%STAGE4A7_1_MULTINODE_TOMOGRAPHY_CAPABILITY Route-C capability gate.
%   RNJA/GLRT tomography needs a pairwise distance matrix.  A single CFR is
%   not silently converted into that matrix.
    has_matrix=isstruct(observation)&&isfield(observation,'pairwise_distance_matrix')&& ...
        ~isempty(observation.pairwise_distance_matrix);
    out=struct('route','multi_node_tomography','status',ternary(has_matrix,'applicable','not_applicable'), ...
        'reason',ternary(has_matrix,'pairwise distance matrix supplied','pairwise ToA/distance matrix is absent'), ...
        'requires_pairwise_distance_matrix',true,'uses_single_port_cfr_as_distance',false);
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
