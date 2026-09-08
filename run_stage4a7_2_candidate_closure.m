function summary = run_stage4a7_2_candidate_closure(mode)
%RUN_STAGE4A7_2_CANDIDATE_CLOSURE Run the controlled Stage 4A.7.2 Pilot.
    if nargin < 1 || isempty(mode), mode='smoke'; end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage4a7_2_candidate_closure(root,mode);
end
