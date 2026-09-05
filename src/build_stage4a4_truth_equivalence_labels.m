function labels = build_stage4a4_truth_equivalence_labels(bank,p0_audit,current_audit,candidates,grid_id,scenario_id,hash)
%BUILD_STAGE4A4_TRUTH_EQUIVALENCE_LABELS Offline scoring labels only.
    labels=repmat(label_template(),numel(bank),1);
    for k=1:numel(bank)
        b=bank(k); [base_class,base_size]=class_for_id(p0_audit,b.truth_topology_id);
        [cur_class,cur_size]=class_for_id(current_audit,b.truth_topology_id);
        in_current=any(strcmp({candidates.topology_id},b.truth_topology_id));
        covered=ismember(b.category,{'in_library_grid','in_library_continuous'}) && in_current;
        if covered, status='covered'; elseif ~in_current && ismember(b.category,{'in_library_grid','in_library_continuous'}), status='excluded_by_prior'; else, status='out_of_library'; end
        x=label_template(); x.sample_id=b.sample_id; x.split=b.split; x.category=b.category;
        x.truth_topology_id=b.truth_topology_id; x.canonical_key=b.canonical_key; x.coverage_status=status;
        x.truth_covered=covered; x.truth_graph_in_current_prior=in_current;
        x.baseline_P0_equivalence_class=base_class; x.baseline_P0_equivalence_class_size=base_size;
        x.prior_conditioned_equivalence_class=cur_class; x.prior_conditioned_equivalence_class_size=cur_size;
        x.truth_is_observationally_nonunique=base_size>1;
        x.grid_id=grid_id; x.scenario_id=scenario_id; x.configuration_hash=hash;
        labels(k)=x;
    end
end
function x=label_template()
    x=struct('sample_id','','split','','category','','truth_topology_id','','canonical_key','', ...
        'coverage_status','','truth_covered',false,'truth_graph_in_current_prior',false, ...
        'baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0, ...
        'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0, ...
        'truth_is_observationally_nonunique',false,'grid_id','','scenario_id','','configuration_hash','');
end
function [label,n]=class_for_id(audit,id)
    label=''; n=0; if isempty(audit), return; end
    for k=1:numel(audit.equivalence_classes)
        x=audit.equivalence_classes{k};
        if any(strcmp(x.member_topology_ids,id)), label=x.label; n=numel(x.member_indices); return; end
    end
end
