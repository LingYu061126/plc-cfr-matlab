function summary=run_stage4a7_3_domain_rejection_and_nonunique_validation(root,mode)
if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
if nargin<2||isempty(mode),mode='formal';end
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
summary=exp_stage4a7_3_domain_rejection_and_nonunique_validation(root,mode);
end
