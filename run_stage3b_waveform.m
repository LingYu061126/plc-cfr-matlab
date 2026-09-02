function result = run_stage3b_waveform()
%RUN_STAGE3B_WAVEFORM Run regression then the isolated waveform diagnostic.
    root_dir=fileparts(mfilename('fullpath'));
    addpath(fullfile(root_dir,'src')); addpath(fullfile(root_dir,'config'));
    addpath(fullfile(root_dir,'experiments')); addpath(fullfile(root_dir,'tests'));
    fprintf('MATLAB %s\nWorking directory: %s\n',version,pwd);
    run_tests();
    test_stage3b_waveform();
    result=exp_stage3b_waveform_baseline(root_dir);
end
