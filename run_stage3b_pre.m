function result = run_stage3b_pre()
%RUN_STAGE3B_PRE Run only isolated Stage-3B-pre test and diagnostic.
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    test_stage3b_pre();result=exp_stage3b_pre_level_a(root);
end
