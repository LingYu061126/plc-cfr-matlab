function rows=stage4a_freeze_r1_stamp_identity(rows,id)
%STAGE4A_FREEZE_R1_STAMP_IDENTITY Add run identity without field collisions.
%   Scientific result fields are never silently overwritten by run identity.
%   In particular, a result row's selected_method is distinct from the
%   canonical execution method stored in the run identity.
    if isempty(rows),return;end
    identity=id;
    if isfield(identity,'selected_method')
        identity.canonical_execution_method=identity.selected_method;
        identity=rmfield(identity,'selected_method');
    end
    fields=fieldnames(identity);
    row_fields=fieldnames(rows);
    for j=1:numel(fields)
        f=fields{j};value=identity.(f);
        % A method-selection table has one calibration hash per method,
        % whereas the run identity has the hash for the canonical method.
        % Keep both meanings instead of treating them as the same field.
        if strcmp(f,'domain_calibration_hash') && ismember(f,row_fields)
            f='canonical_domain_calibration_hash';
        end
        if ismember(f,row_fields)
            for k=1:numel(rows)
                if ~same_value(rows(k).(f),value)
                    error('stage4a_freeze_r1:IdentityFieldCollision', ...
                        'Run identity field %s conflicts with a scientific result field.',f);
                end
            end
        else
            for k=1:numel(rows),rows(k).(f)=value;end
        end
    end
end

function tf=same_value(a,b)
    if ischar(a)||isstring(a)||ischar(b)||isstring(b)
        tf=strcmp(string(a),string(b));
    else
        tf=isequaln(a,b);
    end
end
