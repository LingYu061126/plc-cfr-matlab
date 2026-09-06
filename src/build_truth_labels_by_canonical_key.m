function labels = build_truth_labels_by_canonical_key(bank,p0_candidates,p0_audit,current_audit,candidates,search,grid_id,scenario_id,hashes)
%BUILD_TRUTH_LABELS_BY_CANONICAL_KEY Offline labels independent of local IDs.
    labels=repmat(template(),numel(bank),1);current_keys={candidates.canonical_key};
    p0_keys={p0_candidates.canonical_key};
    for k=1:numel(bank)
        b=bank(k);r=template();r.sample_id=b.sample_id;r.replicate_id=b.replicate_id;r.split=b.split;r.category=b.category;r.outlier_dimension=b.outlier_dimension;r.truth_topology_id=b.truth_topology_id;r.canonical_key=b.canonical_key;r.grid_id=grid_id;r.scenario_id=scenario_id;
        r.truth_graph_in_current_prior=any(strcmp(current_keys,b.canonical_key));
        r.truth_parameter_in_domain=in_domain(b.truth_theta,search);
        graph_in_p0=any(strcmp(p0_keys,b.canonical_key));
        r.truth_covered=r.truth_graph_in_current_prior&&r.truth_parameter_in_domain;
        if ~graph_in_p0
            r.coverage_status='structure_out_of_library';
        elseif ~r.truth_graph_in_current_prior
            r.coverage_status='excluded_by_prior';
        elseif ~r.truth_parameter_in_domain
            r.coverage_status='parameter_out_of_domain';
        else
            r.coverage_status='covered';
        end
        if graph_in_p0,[r.baseline_P0_equivalence_class,r.baseline_P0_equivalence_class_size]=class_by_key(p0_audit,p0_candidates,b.canonical_key);end
        if r.truth_graph_in_current_prior,[r.prior_conditioned_equivalence_class,r.prior_conditioned_equivalence_class_size]=class_by_key(current_audit,candidates,b.canonical_key);end
        r.truth_is_observationally_nonunique=r.baseline_P0_equivalence_class_size>1;
        r.experiment_scientific_hash=hashes.experiment_scientific_hash;r.source_tree_hash=hashes.source_tree_hash;labels(k)=r;
    end
end
function tf=in_domain(t,s),n={'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'};tf=true;for k=1:numel(n),tf=tf&&t.(n{k})>=min(s.(n{k}))&&t.(n{k})<=max(s.(n{k}));end,end
function [lab,n]=class_by_key(a,candidates,key),lab='';n=0;for k=1:numel(a.equivalence_classes),x=a.equivalence_classes{k};ix=x.member_indices;keys={candidates(ix).canonical_key};if any(strcmp(keys,key)),lab=x.label;n=numel(ix);return;end,end,end
function r=template(),r=struct('sample_id','','replicate_id','','split','','category','','outlier_dimension','','truth_topology_id','','canonical_key','','grid_id','','scenario_id','','truth_graph_in_current_prior',false,'truth_parameter_in_domain',false,'truth_covered',false,'coverage_status','','baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0,'truth_is_observationally_nonunique',false,'experiment_scientific_hash','','source_tree_hash','');end
