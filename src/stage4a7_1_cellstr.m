function c = stage4a7_1_cellstr(x)
%STAGE4A7_1_CELLSTR Small MATLAB/Octave-compatible text normalization.
    if iscell(x)
        c=cell(size(x));for k=1:numel(x),c{k}=char(x{k});end
    elseif ischar(x)
        c=cellstr(x);
    else
        try,c=cellstr(x);catch,error('stage4a7_1:InvalidText','Expected text or cell text.');end
    end
    c=c(:).';
end
