function labels = stage4a6_3_1_r1_build_truth_equivalence_labels( ...
        scenarios, candidates, equivalence_audit, equivalence_configuration_hash)
%STAGE4A6_3_1_R1_BUILD_TRUTH_EQUIVALENCE_LABELS Offline scoring labels only.
% This function must be called after decisions are produced; its output is
% never passed to a matcher, optimizer or calibration routine.
    labels = scenarios;
    class_index = equivalence_audit.core.class_index(:).';
    for k=1:numel(labels)
        j=find(strcmp({candidates.topology_id},labels(k).truth_topology_id),1);
        if isempty(j) || j>numel(class_index)
            labels(k).truth_equivalence_set='';
            labels(k).truth_equivalence_member_count=NaN;
            labels(k).truth_unique_under_observation=NaN;
        else
            members=find(class_index==class_index(j));
            ids={candidates(members).topology_id};
            labels(k).truth_equivalence_set=strjoin(ids,',');
            labels(k).truth_equivalence_member_count=numel(ids);
            labels(k).truth_unique_under_observation=(numel(ids)==1);
        end
        labels(k).equivalence_audit_hash=equivalence_configuration_hash;
        labels(k).equivalence_configuration_hash=equivalence_configuration_hash;
    end
end
