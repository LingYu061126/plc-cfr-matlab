function stage7a9_archive_sources(root)
%STAGE7A9_ARCHIVE_SOURCES Byte-exact source snapshots and SHA-256 inventory.
    addpath(fullfile(root,'src'));
    folder=fullfile(root,'results','data','stage7a_9');
    snapshot=fullfile(folder,'source_snapshot');
    paths={'config/stage7a9_config.m','run_stage7a9_study.m', ...
        'experiments/exp_stage7a9_study.m','experiments/exp_stage7a9_end_to_end.m', ...
        'experiments/stage7a9_archive_sources.m', ...
        'src/stage7a9_forward_state.m','src/stage7a9_network_response.m', ...
        'src/stage7a9_profile.m','src/stage7a9_holdout_stat.m', ...
        'src/stage7a9_score_observation.m','tests/test_stage7a9_equivalence.m', ...
        'tests/test_stage7a9_result_integrity.m'};
    rows=cell(numel(paths),4);
    for i=1:numel(paths)
        file=fullfile(root,paths{i});dest=fullfile(snapshot,paths{i});
        if ~isfolder(fileparts(dest)),mkdir(fileparts(dest));end
        copyfile(file,dest);
        hash=stage4a7_2_r2_sha256_file(file);info=dir(file);
        assert(strcmp(hash,stage4a7_2_r2_sha256_file(dest)));
        rows(i,:)={paths{i},hash,info.bytes, ...
            '1801416699fe858a53be03a976633fed71da9b19+Stage7A9 changes'};
    end
    writetable(cell2table(rows,'VariableNames', ...
        {'relative_path','sha256','size_bytes','source_identity'}), ...
        fullfile(folder,'source_inventory.csv'));
    s=readtable(fullfile(folder,'final_code','formal','samples.csv'), ...
        'Delimiter',',','TextType','string');
    b=s(s.method=="B",:);
    requests=sum(b.spectrum_requests);evaluations=sum(b.spectrum_evaluations);
    hit_fraction=(requests-evaluations)/requests;
    forward_calls=sum(b.forward_model_calls);
    frequency_requests=sum(b.frequency_point_requests);
    frequency_evaluations=sum(b.frequency_point_evaluations);
    resource=table(forward_calls,requests,evaluations,hit_fraction, ...
        frequency_requests,frequency_evaluations);
    writetable(resource,fullfile(folder,'resource_summary.csv'));
    fprintf('PASS Stage7A9 source snapshots: %d files\n',numel(paths));
end
