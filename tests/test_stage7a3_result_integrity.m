function test_stage7a3_result_integrity(root,mode)
%TEST_STAGE7A3_RESULT_INTEGRITY Check isolated Stage 7A.3 outputs and hashes.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    out=fullfile(root,'results','data','stage7a_3','formal');
    if strcmp(mode,'smoke'),out=fullfile(root,'results','data','stage7a_3','smoke');end
    required={'stage7a3_sample_diagnostics.csv','stage7a3_candidate_distances.csv', ...
        'stage7a3_group_summary.csv','stage7a3_topology_family_summary.csv', ...
        'stage7a3_topology_cluster_summary.csv','stage7a3_library_out_inventory.csv', ...
        'stage7a3_gate_calibration.csv','stage7a3_response_overlap.csv', ...
        'stage7a3_positive_controls.csv','stage7a3_seed_manifest.csv', ...
        'stage7a3_model_identity.csv','stage7a3_residual_spectra.csv', ...
        'stage7a3_source_inventory.csv','stage7a3_metadata.csv','stage7a3_config_snapshot.mat'};
    for k=1:numel(required)
        assert(exist(fullfile(out,required{k}),'file')==2, ...
            'stage7a3:MissingArtifact','Required artifact missing: %s',required{k});
    end
    samples=readtable(fullfile(out,'stage7a3_sample_diagnostics.csv'),'TextType','string');
    inventory=readtable(fullfile(out,'stage7a3_library_out_inventory.csv'),'TextType','string');
    manifest=readtable(fullfile(out,'stage7a3_source_inventory.csv'),'TextType','string');
    canon=samples(samples.scenario=="stage7a2_library_out_replay" & ...
        samples.library=="scale_small" & samples.method=="M2",:);
    assert(height(canon)==100&&nnz(canon.false_unique)==94, ...
        'The Stage 7A.2 94/100 small-library M2 failure did not replay exactly.');
    for library=["scale_small","scale_medium","scale_large"]
        replay=samples(samples.scenario=="stage7a2_library_out_replay" & samples.library==library,:);
        assert(height(replay)==300,'Expected 100 rows for each of M2, M2R and the diagnostic gate.');
        assert(nnz(replay.method=="M2")==100&&nnz(replay.method=="M2R")==100&& ...
            nnz(replay.method=="M2R_plus_band_gate")==100);
        inv=inventory(inventory.library==library,:);
        selected=logical(inv.selected_for_final_holdout);
        assert(height(inv)>=8&&nnz(selected)==8, ...
            'The eight pre-registered holdout structures are not present in inventory.');
        assert(~any(logical(inv.is_in_candidate_library(selected))), ...
            'A selected final holdout topology is actually in the candidate library.');
    end
    reps=2;if strcmp(mode,'formal'),reps=30;end
    final=samples(ismember(samples.scenario,["T_library_out_20db","T_library_out_10db"]),:);
    for library=["scale_small","scale_medium","scale_large"]
        for scenario=["T_library_out_20db","T_library_out_10db"]
            block=final(final.library==library & final.scenario==scenario,:);
            assert(height(block)==8*reps*3, ...
                'Final OOD sample rows must be 8 structures × repetitions × three methods.');
            assert(numel(unique(block.truth_signature))==8, ...
                'Final OOD evaluation must include eight distinct physical topology signatures.');
        end
    end
    m2r=samples(samples.method=="M2R",:);gate=samples(samples.method=="M2R_plus_band_gate",:);
    [~,ia,ib]=intersect(strcat(m2r.library,"|",m2r.scenario,"|",string(m2r.sample_seed)), ...
        strcat(gate.library,"|",gate.scenario,"|",string(gate.sample_seed)),'stable');
    assert(numel(ia)==height(gate)&&numel(unique(ib))==height(gate), ...
        'Each gate output must have exactly one paired M2R output.');
    assert(all(m2r.candidate_set_size(ia)==gate.candidate_set_size(ib))&& ...
        all(m2r.candidate_set(ia)==gate.candidate_set(ib)), ...
        'Residual gate must not alter candidate set membership.');
    promoted=gate.decision_state(ib)=="UNIQUE_CONFIDENT" & m2r.decision_state(ia)~="UNIQUE_CONFIDENT";
    assert(~any(promoted),'Residual gate must never promote a decision to unique.');
    for k=1:height(manifest)
        path=fullfile(root,strrep(char(manifest.relative_path(k)),'/',filesep));
        assert(exist(path,'file')==2,'stage7a3:InventoryPath','Source inventory path is missing.');
        info=dir(path);assert(info.bytes==manifest.size_bytes(k), ...
            'stage7a3:InventorySize','Source file size differs from inventory.');
        assert(strcmp(stage4a7_2_r2_sha256_file(path),char(manifest.sha256(k))), ...
            'stage7a3:InventoryHash','Source file SHA-256 differs from inventory.');
    end
end
