function digest = stage4a7_2_r2_sha256_file(path)
%STAGE4A7_2_R2_SHA256_FILE Portable SHA-256 for provenance manifests.
    if ~(ischar(path)||isstring(path)) || ~exist(path,'file')
        digest=''; return;
    end
    md=java.security.MessageDigest.getInstance('SHA-256');
    fis=java.io.FileInputStream(char(path)); cleanup=onCleanup(@()fis.close()); %#ok<NASGU>
    buf=zeros(1,1024*1024,'int8');
    while true
        n=fis.read(buf,0,numel(buf)); if n<0,break;end
        md.update(buf(1:n));
    end
    b=typecast(md.digest(),'uint8');digest=lower(reshape(dec2hex(b,2).',1,[]));
end
