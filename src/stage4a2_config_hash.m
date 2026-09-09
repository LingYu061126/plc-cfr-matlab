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
        % R2024a -nojvm remains useful for headless recovery, but has no
        % Java runtime.  Use the system SHA-256 implementation rather than
        % the former non-cryptographic weighted-byte fallback.
        digest = sha256_system(unicode2native(canonical_text,'UTF-8'));
    end
end

function digest = sha256_system(bytes)
    tmp = [tempname '.sha256_input'];
    cleanup = onCleanup(@()delete_if_exists(tmp)); %#ok<NASGU>
    fid = fopen(tmp,'wb');
    if fid < 0, error('stage4a2_config_hash:FallbackOpenFailed','Cannot create SHA-256 fallback input.'); end
    fwrite(fid,uint8(bytes(:)),'uint8'); fclose(fid);
    [status,out] = system(['/usr/bin/sha256sum ' shell_quote(tmp)]);
    if status ~= 0
        error('stage4a2_config_hash:FallbackFailed','System SHA-256 failed: %s',strtrim(out));
    end
    digest = regexp(strtrim(out),'^[0-9A-Fa-f]{64}','match','once');
    if isempty(digest), error('stage4a2_config_hash:FallbackMalformed','System SHA-256 output was malformed.'); end
    digest = lower(digest);
end

function q = shell_quote(x)
    sq = char(39);
    q = [sq strrep(x,sq,[sq '"' sq '"' sq]) sq];
end

function delete_if_exists(p)
    if exist(p,'file'), delete(p); end
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
