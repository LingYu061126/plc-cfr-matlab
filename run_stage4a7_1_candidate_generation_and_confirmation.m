function summary = run_stage4a7_1_candidate_generation_and_confirmation(mode)
%RUN_STAGE4A7_1_CANDIDATE_GENERATION_AND_CONFIRMATION Project-root entry.
    if nargin<1||isempty(mode),mode='pilot';end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'experiments'));
    summary=exp_stage4a7_1_candidate_generation_and_confirmation(root,mode);
end
