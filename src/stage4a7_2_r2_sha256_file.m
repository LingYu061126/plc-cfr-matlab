function digest = stage4a7_2_r2_sha256_file(path)
%STAGE4A7_2_R2_SHA256_FILE Compute SHA-256 over the actual file bytes.
%   The project supports MATLAB -nojvm/-singleCompThread execution.  The
%   system sha256sum implementation is therefore the single digest path;
%   this avoids the R2024a Java/no-JVM distinction and makes the byte-level
%   contract auditable with the same utility used outside MATLAB.
    if ~(ischar(path)||isstring(path)) || ~exist(path,'file')
        digest=''; return;
    end
    if exist('/usr/bin/sha256sum','file') ~= 2
        error('stage4a7_2_r2:SHA256ToolMissing','/usr/bin/sha256sum is required for reproducible no-JVM execution.');
    end
    [status,out]=system(['/usr/bin/sha256sum ' shell_quote(char(path))]);
    if status~=0,error('stage4a7_2_r2:SHA256Failed','System SHA-256 failed: %s',strtrim(out));end
    digest=regexp(strtrim(out),'^[0-9A-Fa-f]{64}','match','once');
    if isempty(digest),error('stage4a7_2_r2:SHA256Malformed','System SHA-256 output was malformed.');end
    digest=lower(digest);
end

function q=shell_quote(x)
    sq=char(39);q=[sq strrep(x,sq,[sq '"' sq '"' sq]) sq];
end
