function t=stage2_3_struct_table(s,fields)
%STAGE2_3_STRUCT_TABLE Safe struct-array-to-table conversion for result I/O.
    if nargin<2||isempty(fields),fields=fieldnames(s);end
    if isempty(s)
        t=cell2table(cell(0,numel(fields)),'VariableNames',fields(:).');
    else
        t=struct2table(s(:));
    end
end
