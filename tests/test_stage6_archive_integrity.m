function test_stage6_archive_integrity()
%TEST_STAGE6_ARCHIVE_INTEGRITY Verify archived Stage 6 results and hashes.
%   This checks fixed scientific counts and original-byte SHA-256 identities.
%   It does not recalibrate thresholds or regenerate canonical results.
    root=fileparts(fileparts(mfilename('fullpath')));
    a=fullfile(root,'results','data','stage6a');
    b=fullfile(root,'results','data','stage6b');
    required_a={'stage6a_candidate_generation_summary.csv', ...
        'stage6a_identification_summary.csv','stage6a_identification_metrics.csv', ...
        'stage6a_runtime.csv'};
    required_b={'stage6b_prior_sensitivity.csv','stage6b_prior_sensitivity_summary.csv', ...
        'stage6b_candidate_scale.csv','stage6b_candidate_scale_samples.csv', ...
        'stage6b_parameter_uncertainty.csv','stage6b_parameter_uncertainty_summary.csv', ...
        'stage6b_identifiability.csv','stage6b_identifiability_distance_matrix.csv', ...
        'stage6b_runtime.csv'};
    for k=1:numel(required_a)
        assert(isfile(fullfile(a,required_a{k})),'Missing Stage 6A CSV: %s',required_a{k});
    end
    for k=1:numel(required_b)
        assert(isfile(fullfile(b,required_b{k})),'Missing Stage 6B CSV: %s',required_b{k});
    end

    gen=readtable(fullfile(a,'stage6a_candidate_generation_summary.csv'),'TextType','string');
    cases=["broad_unknown_switches","informative_switch_prior","stale_switch_prior"];
    expected=[7 2 4];
    for k=1:numel(cases)
        ix=gen.prior_case==cases(k);
        assert(nnz(ix)==1 && gen.candidate_count(ix)==expected(k), ...
            'Stage 6A candidate count changed: %s',cases(k));
    end
    scale=readtable(fullfile(b,'stage6b_candidate_scale.csv'),'TextType','string');
    assert(isequal(scale.candidate_number(:).',[3 7 23]),'Stage 6B candidate scale changed.');
    prior=readtable(fullfile(b,'stage6b_prior_sensitivity.csv'),'TextType','string');
    corrupted=logical(prior.prior_error_applied);
    assert(nnz(corrupted)==14,'Stage 6B corrupted sample count changed.');
    assert(nnz(logical(prior.false_unique(corrupted)))==0,'Corrupted false unique is nonzero.');
    assert(all(prior.decision_state(corrupted)=="REJECTED"),'Corrupted sample was not rejected.');
    param=readtable(fullfile(b,'stage6b_parameter_uncertainty.csv'),'TextType','string');
    nominal=param.parameter_error==0;
    assert(nnz(nominal)==10 && all(param.decision_state(nominal)=="UNIQUE_CONFIDENT"), ...
        'Stage 6B nominal parameter decision changed.');
    assert(nnz(~nominal)==60 && all(param.decision_state(~nominal)=="REJECTED"), ...
        'Stage 6B nonzero length-error decision changed.');
    ident=readtable(fullfile(b,'stage6b_identifiability.csv'),'TextType','string');
    assert(height(ident)==2 && all(ident.decision_state=="MULTIPLE_AMBIGUOUS"), ...
        'Stage 6B identifiability control changed.');

    closure=fullfile(root,'results','data','stage6_closure');
    verify_manifest(fullfile(closure,'source_inventory.csv'),root);
    verify_manifest(fullfile(closure,'artifact_manifest.csv'),root);
    fprintf('  PASS Stage 6 archive CSV counts, states and source/artifact SHA-256 identities\n');
end

function verify_manifest(path,root)
    assert(isfile(path),'Missing Stage 6 archive manifest: %s',path);
    rows=readtable(path,'TextType','string');
    assert(height(rows)>0 && all(ismember(["relative_path","sha256","size_bytes"], ...
        string(rows.Properties.VariableNames))),'Invalid Stage 6 archive manifest schema.');
    for k=1:height(rows)
        rel=char(rows.relative_path(k));
        assert(~isempty(rel) && ~startsWith(rel,'/') && ~contains(rel,'..') && ...
            ~contains(rel,char(92)),'Invalid manifest relative path: %s',rel);
        file=fullfile(root,strrep(rel,'/',filesep));
        assert(isfile(file),'Manifest file missing: %s',rel);
        info=dir(file);
        assert(info.bytes==rows.size_bytes(k),'Manifest size mismatch: %s',rel);
        hash=stage4a7_2_r2_sha256_file(file);
        assert(strcmpi(hash,char(rows.sha256(k))),'Manifest SHA-256 mismatch: %s',rel);
    end
end
