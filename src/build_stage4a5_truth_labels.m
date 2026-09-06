function labels = build_stage4a5_truth_labels(bank, p0_audit, current_audit, candidates, search, grid_id, scenario_id, hash)
%BUILD_STAGE4A5_TRUTH_LABELS Build offline-only scoring labels.
    labels=repmat(label_template(),numel(bank),1);ids={candidates.topology_id};base_ids={};
    for c=1:numel(p0_audit.equivalence_classes),base_ids=[base_ids p0_audit.equivalence_classes{c}.member_topology_ids];end %#ok<AGROW>
    for k=1:numel(bank)
        b=bank(k);r=label_template();r.sample_id=b.sample_id;r.replicate_id=b.replicate_id;r.split=b.split;r.category=b.category;r.outlier_dimension=b.outlier_dimension;r.truth_topology_id=b.truth_topology_id;r.canonical_key=b.canonical_key;r.grid_id=grid_id;r.scenario_id=scenario_id;r.configuration_hash=hash;
        in_graph=any(strcmp(ids,b.truth_topology_id));base_graph=any(strcmp(base_ids,b.truth_topology_id));in_domain=is_in_parameter_domain(b.truth_theta,search);
        r.truth_graph_in_current_prior=in_graph;r.truth_covered=base_graph&&in_domain;
        if r.truth_covered && ~in_graph,r.coverage_status='excluded_by_prior';elseif r.truth_covered,r.coverage_status='covered';else,r.coverage_status='out_of_library';end
        [r.baseline_P0_equivalence_class,r.baseline_P0_equivalence_class_size]=class_for_id(p0_audit,b.truth_topology_id);
        if in_graph,[r.prior_conditioned_equivalence_class,r.prior_conditioned_equivalence_class_size]=class_for_id(current_audit,b.truth_topology_id);end
        r.truth_is_observationally_nonunique=r.baseline_P0_equivalence_class_size>1;labels(k)=r;
    end
end
function tf=is_in_parameter_domain(t,s)
    names={'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'};tf=true;for k=1:numel(names),v=t.(names{k});tf=tf&&v>=min(s.(names{k}))&&v<=max(s.(names{k}));end
end
function [lab,n]=class_for_id(audit,id)
    lab='';n=0;for k=1:numel(audit.equivalence_classes),x=audit.equivalence_classes{k};if any(strcmp(x.member_topology_ids,id)),lab=x.label;n=numel(x.member_topology_ids);return;end,end
end
function r=label_template(),r=struct('sample_id','','replicate_id','','split','','category','','outlier_dimension','','truth_topology_id','','canonical_key','','grid_id','','scenario_id','','truth_covered',false,'truth_graph_in_current_prior',false,'coverage_status','','baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0,'truth_is_observationally_nonunique',false,'configuration_hash','');end
