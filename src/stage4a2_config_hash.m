function [digest, canonical_text] = stage4a2_config_hash(value)
%STAGE4A2_CONFIG_HASH Deterministic digest plus full canonical configuration.
%   The canonical text retains complete numeric arrays (including frequency
%   grids), sorted struct fields and ordered cells. The digest is a compact
%   identifier, not a replacement for the saved configuration itself.

    canonical_text = canonicalize(value);
    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        md.update(uint8(unicode2native(canonical_text,'UTF-8')));
        raw = typecast(md.digest(),'uint8');
        digest = lower(reshape(dec2hex(raw,2).',1,[]));
    catch
        bytes = uint64(uint8(canonical_text));
        weights = uint64(1:numel(bytes));
        digest = sprintf('fallback_%016X',sum(bytes.*weights));
    end
end

function text = canonicalize(value)
    if isstruct(value)
        if numel(value) ~= 1
            text = ['structarray[' strjoin(arrayfun(@canonicalize,value(:).','UniformOutput',false),';') ']'];
            return;
        end
        fields = sort(fieldnames(value));
        parts = cell(1,numel(fields));
        for k=1:numel(fields)
            parts{k} = [fields{k} '=' canonicalize(value.(fields{k}))];
        end
        text = ['struct{' strjoin(parts,'|') '}'];
    elseif iscell(value)
        parts = cellfun(@canonicalize,value(:).','UniformOutput',false);
        text = ['cell[' strjoin(parts,';') ']'];
    elseif ischar(value) || (isstring(value) && isscalar(value))
        text = ['char(' char(value) ')'];
    elseif isnumeric(value) || islogical(value)
        if isempty(value), text = sprintf('%s[%s]',class(value),mat2str(size(value))); return; end
        x = value(:).';
        parts = arrayfun(@numeric_token,x,'UniformOutput',false);
        text = sprintf('%s%s[%s]',class(value),mat2str(size(value)),strjoin(parts,','));
    else
        error('stage4a2_config_hash:UnsupportedType','Unsupported configuration type %s.',class(value));
    end
end

function token = numeric_token(x)
    if isnan(x), token='NaN'; elseif isinf(x), if x>0, token='Inf'; else, token='-Inf'; end
    elseif ~isreal(x), token=['(' numeric_token(real(x)) ',' numeric_token(imag(x)) ')'];
    else, token=sprintf('%.17g',x); end
end
