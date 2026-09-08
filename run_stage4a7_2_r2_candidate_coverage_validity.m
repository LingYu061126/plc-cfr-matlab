function summary=run_stage4a7_2_r2_candidate_coverage_validity(mode)
%RUN_STAGE4A7_2_R2_CANDIDATE_COVERAGE_VALIDITY Project-root entry point.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'));
    summary=exp_stage4a7_2_r2_candidate_coverage_validity(root,mode);
end
