function result = run_stage3b_pre()
%RUN_STAGE3B_PRE Run isolated Stage-3B-pre tests and ideal-CFR diagnostic.
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    started=datetime('now','Format','yyyy-MM-dd HH:mm:ss Z');
    fprintf('Stage3B-pre start: %s\nMATLAB version: %s\nWorking directory: %s\n',char(started),version,root);
    fprintf('Entry: run_tests; run_stage3b_pre (Stage3B-pre uses ideal CFR plus receiver-domain sample noise).\n');
    run_tests;result=exp_stage3b_pre_level_a(root);
    fprintf('Stage3B-pre completed successfully at %s.\n',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')));
end
