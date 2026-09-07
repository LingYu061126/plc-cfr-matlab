function rows = stage4a6_3_1_r1_independence_audit(splits)
%STAGE4A6_3_1_R1_INDEPENDENCE_AUDIT Audit IDs, parameters and CFR hashes.
% final_reserved is identity-only; its CFR checks are explicitly N/A.
    names = fieldnames(splits); rows=repmat(row(),0,1);
    for i=1:numel(names)
        for j=i+1:numel(names)
            a=splits.(names{i}); b=splits.(names{j});
            r=row();r.split_a=names{i};r.split_b=names{j};
            r.row_count_a=numel(a);r.row_count_b=numel(b);
            r.cross_split_physical_id_duplicate_count=intersect_count(a,b,'physical_scenario_id');
            r.cross_split_parameter_hash_duplicate_count=intersect_count(a,b,'parameter_vector_hash');
            if any(strcmp(names{i},'final_reserved')) || any(strcmp(names{j},'final_reserved'))
                r.cross_split_cfr_hash_duplicate_count=NaN;
                r.cross_split_observation_hash_duplicate_count=NaN;
                r.cross_split_numerical_equivalence_count=NaN;
                r.cfr_status='not_evaluated_final_reserved';
            else
                r.cross_split_cfr_hash_duplicate_count=intersect_count(a,b,'noiseless_cfr_hash');
                r.cross_split_observation_hash_duplicate_count=intersect_count(a,b,'observation_hash');
                r.cross_split_numerical_equivalence_count=0;
                r.cfr_status='exact_hash_only';
            end
            rows(end+1)=r; %#ok<AGROW>
        end
    end
end

function n=intersect_count(a,b,f)
    x=values(a,f);y=values(b,f);x=x(~cellfun(@isempty,x));y=y(~cellfun(@isempty,y));
    if isempty(x)||isempty(y),n=0;else,n=numel(intersect(unique(x),unique(y)));end
end
function x=values(a,f)
    x=cell(1,numel(a));for k=1:numel(a),if isfield(a(k),f),x{k}=a(k).(f);else,x{k}='';end,end
end
function r=row()
    r=struct('split_a','','split_b','','row_count_a',0,'row_count_b',0, ...
        'cross_split_physical_id_duplicate_count',0, ...
        'cross_split_parameter_hash_duplicate_count',0, ...
        'cross_split_cfr_hash_duplicate_count',0, ...
        'cross_split_observation_hash_duplicate_count',0, ...
        'cross_split_numerical_equivalence_count',0,'cfr_status','');
end
