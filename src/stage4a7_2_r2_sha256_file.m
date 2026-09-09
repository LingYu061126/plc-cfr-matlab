function digest = stage4a7_2_r2_sha256_file(path)
%STAGE4A7_2_R2_SHA256_FILE SHA-256 of the original file bytes.
%   A JVM path is preferred on both native Windows and Linux.  No-JVM
%   fallbacks use sha256sum on POSIX and PowerShell Get-FileHash on Windows.
%   Paths are passed as literal arguments/environment values, never as code.
    if ~(ischar(path)||isstring(path)) || ~exist(path,'file')
        digest=''; return;
    end
    path=char(path);
    if exist('usejava','builtin') && usejava('jvm')
        try
            digest=sha256_java(path);
            if numel(digest)==64, return; end
        catch ME
            java_error=ME;
        end
    end
    if ispc
        digest=sha256_powershell(path);
    else
        digest=sha256_posix(path);
    end
    if isempty(digest)
        if exist('java_error','var')
            error('stage4a7_2_r2:SHA256Failed','All SHA-256 paths failed; Java error was: %s',java_error.message);
        end
        error('stage4a7_2_r2:SHA256ToolMissing','No usable cross-platform SHA-256 implementation was found.');
    end
end

function digest=sha256_java(path)
    md=java.security.MessageDigest.getInstance('SHA-256');
    bytes=java.nio.file.Files.readAllBytes(java.nio.file.Paths.get(path));
    raw=typecast(int8(md.digest(bytes)),'uint8');
    digest=lower(reshape(dec2hex(raw,2).',1,[]));
end

function digest=sha256_posix(path)
    tool='';
    if exist('/usr/bin/sha256sum','file')==2,tool='/usr/bin/sha256sum';
    elseif system('command -v sha256sum >/dev/null 2>&1')==0,tool='sha256sum';end
    if isempty(tool),digest='';return;end
    [status,out]=system([tool ' -- ' shell_quote(path)]);
    if status~=0,error('stage4a7_2_r2:SHA256Failed','POSIX SHA-256 failed: %s',strtrim(out));end
    digest=regexp(strtrim(out),'^[0-9A-Fa-f]{64}','match','once');
    if isempty(digest),error('stage4a7_2_r2:SHA256Malformed','POSIX SHA-256 output was malformed.');end
    digest=lower(digest);
end

function digest=sha256_powershell(path)
    name=sprintf('PLC_FREEZE_R1_SHA_PATH_%d',round(now*1e7));
    old=getenv(name);setenv(name,path);cleanup=onCleanup(@()setenv(name,old)); %#ok<NASGU>
    command=['powershell.exe -NoLogo -NoProfile -NonInteractive -Command ' ...
        '"$p=$env:' name '; (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()"'];
    [status,out]=system(command);
    if status~=0,error('stage4a7_2_r2:SHA256Failed','PowerShell SHA-256 failed: %s',strtrim(out));end
    digest=regexp(strtrim(out),'^[0-9A-Fa-f]{64}','match','once');
    if isempty(digest),error('stage4a7_2_r2:SHA256Malformed','PowerShell SHA-256 output was malformed.');end
    digest=lower(digest);
end

function q=shell_quote(x)
    sq=char(39);q=[sq strrep(x,sq,[sq '"' sq '"' sq]) sq];
end
