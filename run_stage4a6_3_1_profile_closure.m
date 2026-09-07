function out = run_stage4a6_3_1_profile_closure()
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
out = exp_stage4a6_3_1_profile_closure(root);
end
