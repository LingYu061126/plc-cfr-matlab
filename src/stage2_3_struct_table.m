function t=stage2_3_struct_table(s,fields)
%STAGE2_3_STRUCT_TABLE Safe struct-array-to-table conversion for result I/O.
    if nargin<2||isempty(fields)
        if isstruct(s),fields=fieldnames(s);elseif isempty(s),fields={};
        else,error('stage2_3_struct_table:InvalidInput','Input must be a struct array or empty.');end
    end
    if isstring(fields),fields=cellstr(fields);end
    if ~iscell(fields)||any(~cellfun(@(x)ischar(x)&&isvarname(x),fields))|| ...
            numel(unique(fields))~=numel(fields)
        error('stage2_3_struct_table:InvalidFields','fields must be unique valid MATLAB field names.');
    end
    if isempty(s)
        t=cell2table(cell(0,numel(fields)),'VariableNames',fields(:).');
    else
        if ~isstruct(s),error('stage2_3_struct_table:InvalidInput','Input must be a struct array or empty.');end
        available=fieldnames(s);missing=fields(~ismember(fields,available));
        if ~isempty(missing)
            error('stage2_3_struct_table:MissingField','Input struct lacks requested field(s): %s.',strjoin(missing,', '));
        end
        t=struct2table(s(:));
        if ~isempty(fields),t=t(:,fields);end
    end
end
