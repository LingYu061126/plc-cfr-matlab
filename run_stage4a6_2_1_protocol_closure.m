function out=run_stage4a6_2_1_protocol_closure(mode)
%RUN_STAGE4A6_2_1_PROTOCOL_CLOSURE Run the short protocol smoke audit.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    out=exp_stage4a6_2_1_protocol_closure(root,mode);
end
