function summary=run_stage4a7_2_r2_1_independent_35_pilot()
%RUN_STAGE4A7_2_R2_1_INDEPENDENT_35_PILOT Run the frozen independent pilot.
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'));summary=stage4a7_2_r2_1_run_independent_35_pilot(root);
end
