function digest = stage4a7_2_r2_sha256_file(path)
%STAGE4A7_2_R2_SHA256_FILE Compute SHA-256 over the actual file bytes.
%   Bytes are read by MATLAB fread and then typecast to signed int8 only at
%   the Java boundary.  This avoids the Java FileInputStream overload that
%   can leave a MATLAB numeric buffer unchanged on some R2024a runtimes.
    if ~(ischar(path)||isstring(path)) || ~exist(path,'file')
        digest=''; return;
    end
    fid=fopen(char(path),'rb');
    if fid<0, error('stage4a7_2_r2:SHA256OpenFailed','Cannot open %s.',char(path)); end
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    try
        md=java.security.MessageDigest.getInstance('SHA-256');
        while true
            bytes=fread(fid,1024*1024,'*uint8');
            if isempty(bytes), break; end
            md.update(typecast(bytes(:),'int8'));
        end
        b=typecast(md.digest(),'uint8');
        digest=lower(reshape(dec2hex(b,2).',1,[]));
    catch
        % Keep the no-JVM execution path cryptographically equivalent.  The
        % input file is never changed; only a system digest is requested.
        % Release the normal-path cleanup before asking the shell to read the
        % file; otherwise its destructor would attempt a second fclose.
        cleanup=[];
        [status,out]=system(['/usr/bin/sha256sum ' shell_quote(char(path))]);
        if status~=0,error('stage4a7_2_r2:SHA256FallbackFailed','System SHA-256 failed: %s',strtrim(out));end
        digest=regexp(strtrim(out),'^[0-9A-Fa-f]{64}','match','once');
        if isempty(digest),error('stage4a7_2_r2:SHA256FallbackMalformed','System SHA-256 output was malformed.');end
        digest=lower(digest);
    end
end

function q=shell_quote(x)
    sq=char(39);q=[sq strrep(x,sq,[sq '"' sq '"' sq]) sq];
end
