function out=run_stage4a6_3_1_protocol_pilot()
%RUN_STAGE4A6_3_1_PROTOCOL_PILOT Entry point for the controlled A-grid pilot.
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'experiments'),fullfile(root,'src'),fullfile(root,'config'));out=exp_stage4a6_3_1_protocol_pilot(root);
end
