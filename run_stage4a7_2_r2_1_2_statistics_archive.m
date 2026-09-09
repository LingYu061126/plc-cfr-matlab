function summary=run_stage4a7_2_r2_1_2_statistics_archive(root)
if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
summary=exp_stage4a7_2_r2_1_2_statistics_archive(root);
end
