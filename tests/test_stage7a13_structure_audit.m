function test_stage7a13_structure_audit(root)
%TEST_STAGE7A13_STRUCTURE_AUDIT Distinguish attachment, edges and attributes.
    if nargin<1||isempty(root)
        root=fileparts(fileparts(mfilename('fullpath')));
    end
    addpath(fullfile(root,'src'));
    branch=struct('node',1,'length',5,'cable_type',1,'load',50);
    truth=struct('main_lengths',[10 20], ...
        'main_cable_type',[0 0],'branches',branch);
    same=struct('topology_id','same','network',truth);
    result=stage7a13_structure_audit(truth,same);
    c=result.candidates;
    assert(c.attachment_positions_match && ...
        c.labelled_connectivity_match && c.edge_attributes_match && ...
        c.complete_physical_match && result.min_wrong_attachment_count==0);
    different_nodes=truth;
    different_nodes.main_lengths=[5 5 20];
    different_nodes.main_cable_type=[0 0 0];
    different_nodes.branches.node=2;
    shifted=struct('topology_id','shifted','network',different_nodes);
    c=stage7a13_structure_audit(truth,shifted).candidates;
    assert(c.attachment_positions_match && ...
        ~c.labelled_connectivity_match && ...
        ~c.complete_physical_match, ...
        'stage7a13:AttachmentIsNotLabelledGraph');
    different_length=truth;
    different_length.branches.length=6;
    changed=struct('topology_id','length6','network',different_length);
    c=stage7a13_structure_audit(truth,changed).candidates;
    assert(c.attachment_positions_match && ...
        c.labelled_connectivity_match && ...
        ~c.edge_attributes_match && ~c.complete_physical_match, ...
        'stage7a13:AttachmentIsNotPhysicalGraph');
    none=stage7a13_structure_audit(truth, ...
        struct('topology_id',{},'network',{}));
    assert(isnan(none.min_wrong_attachment_count) && ...
        ~none.any_complete_physical_match);
    fprintf('PASS test_stage7a13_structure_audit: four graph meanings\n');
end
