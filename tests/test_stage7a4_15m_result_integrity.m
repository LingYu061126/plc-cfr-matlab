function test_stage7a4_15m_result_integrity(root,mode)
%TEST_STAGE7A4_15M_RESULT_INTEGRITY Validate independent archive outputs.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    folder=fullfile(root,'results','data','stage7a_4_15m_continuous',mode);
    files={'samples.csv','summary.csv','calibration.csv','multistart_audit.csv', ...
        'metadata.csv','config_snapshot.mat','artifact_manifest.csv','source_inventory.csv'};
    for i=1:numel(files),assert(isfile(fullfile(folder,files{i})));end
    a=readtable(fullfile(folder,'artifact_manifest.csv'),'TextType','string');
    s=readtable(fullfile(folder,'source_inventory.csv'),'TextType','string');
    for rows={a,s}
        x=rows{1};
        for i=1:height(x)
            p=fullfile(root,strrep(char(x.relative_path(i)),'/',filesep));
            assert(isfile(p));info=dir(p);
            assert(info.bytes==x.size_bytes(i));
            assert(strcmpi(stage4a7_2_r2_sha256_file(p),char(x.sha256(i))));
        end
    end
    r=readtable(fullfile(folder,'samples.csv'),'TextType','string');
    assert(height(r)>0&&all(isfinite(r.distance_1))&& ...
        all(isfinite(r.distance_2))&&all(isfinite(r.fit_main))&& ...
        all(isfinite(r.fit_load)));
    assert(all(r.fit_main>=0.9-1e-6 & r.fit_main<=1.1+1e-6));
    assert(all(r.fit_load>=0.8-1e-6 & r.fit_load<=1.2+1e-6));
    assert(all(~(r.library=="original_three" & r.truth_id=="MIRROR_M3" & ...
        r.truth_in_library)));
    assert(all(r.library~="pair" | ismember(r.truth_id,["G003","MIRROR_M3"])));
    assert(all(ismember(r.state,["UNIQUE_CONFIDENT","MULTIPLE_AMBIGUOUS", ...
        "LOW_CONFIDENCE","REJECTED"])));
    c=readtable(fullfile(folder,'calibration.csv'),'TextType','string');
    assert(all(c.E_seed~=c.A_seed & c.A_seed~=c.F_seed));
    assert(all(c.A_seed<min(r.parameter_seed)));
    m=readtable(fullfile(folder,'metadata.csv'),'TextType','string');
    assert(m.C_trigger_pair==1&&m.C_trigger_original==0);
    fprintf('PASS test_stage7a4_15m_result_integrity(%s): %d rows and SHA-256 identities\n', ...
        mode,height(r));
end
