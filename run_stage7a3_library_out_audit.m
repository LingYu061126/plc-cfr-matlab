function result=run_stage7a3_library_out_audit(root,mode)
%RUN_STAGE7A3_LIBRARY_OUT_AUDIT Run the isolated Stage 7A.3 diagnostic.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result=exp_stage7a3_library_out_audit(root,mode);
end
