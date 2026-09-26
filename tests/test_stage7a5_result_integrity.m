function test_stage7a5_result_integrity(root,mode)
%TEST_STAGE7A5_RESULT_INTEGRITY Check Stage 7A.5 isolated outputs.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    if strcmp(mode,'smoke'),dirout=fullfile(root,'results','data','stage7a_5','smoke_v5');
    else,dirout=fullfile(root,'results','data','stage7a_5','formal_v2');end
    required={'samples.csv','candidate_audit.csv','summary.csv','calibration.csv', ...
        'method_selection.csv','nonunique_controls.csv','control_candidate_audit.csv', ...
        'topology_inventory.csv','candidate_scale_benchmark.csv','seed_manifest.csv', ...
        'metadata.csv','config_snapshot.mat','source_inventory.csv','artifact_manifest.csv'};
    for k=1:numel(required)
        assert(exist(fullfile(dirout,required{k}),'file')==2, ...
            'stage7a5:MissingArtifact','Missing Stage 7A.5 artifact %s.',required{k});
    end
    samples=readtable(fullfile(dirout,'samples.csv'));
    candidates=readtable(fullfile(dirout,'candidate_audit.csv'));
    metadata=readtable(fullfile(dirout,'metadata.csv'));
    controls=readtable(fullfile(dirout,'nonunique_controls.csv'));
    inventory=readtable(fullfile(dirout,'topology_inventory.csv'));
    assert(height(samples)>0&&height(candidates)>=height(samples));
    assert(all(ismember(unique(string(samples.flow)),["A","B","C"])));
    assert(all(ismember(unique(string(samples.state)), ...
        ["UNIQUE_CONFIDENT","MULTIPLE_AMBIGUOUS","LOW_CONFIDENCE","REJECTED"])));
    unique_decision=string(samples.state)=="UNIQUE_CONFIDENT";
    expected_false=unique_decision & ...
        (string(samples.best_candidate)~=string(samples.truth_id));
    assert(all(samples.false_unique==expected_false), ...
        'False-unique labels must mean a wrong unique topology, not OOD membership.');
    assert(~any(samples.correct_unique&samples.false_unique));
    assert(height(inventory)==10&&all(inventory.grammar_valid));
    assert(metadata.template_forward_calls==450&&metadata.template_cache_bytes>0);
    assert(all(candidates.rank>=1)&&all(isfinite(candidates.distance)));
    verify_manifest(root,fullfile(dirout,'source_inventory.csv'),false);
    verify_manifest(root,fullfile(dirout,'artifact_manifest.csv'),true);
    h=string(controls.scheme)=="H50";
    nonunique=ismember(string(controls.truth_id),["T3","T5","T4_NEAR_T3"]);
    assert(~any(string(controls.state(h&nonunique))=="UNIQUE_CONFIDENT"), ...
        'stage7a5:ControlForcedUnique');
    fprintf('PASS test_stage7a5_result_integrity (%s): %d sample rows, %d candidate rows\n', ...
        mode,height(samples),height(candidates));
end

function verify_manifest(root,path,is_artifact)
    t=readtable(path,'TextType','string');
    for k=1:height(t)
        rel=t.relative_path(k);
        if is_artifact,full=fullfile(root,char(rel));
        else,full=fullfile(root,char(rel));end
        assert(exist(full,'file')==2,'stage7a5:ManifestMissing','Missing %s.',rel);
        [status,out]=system(sprintf('sha256sum "%s"',full));
        assert(status==0,'stage7a5:ManifestHashCommand');
        actual=regexp(strtrim(out),'^[0-9a-f]{64}','match','once');
        assert(strcmp(actual,t.sha256(k)),'stage7a5:ManifestHashMismatch', ...
            'SHA-256 mismatch for %s.',rel);
    end
end
