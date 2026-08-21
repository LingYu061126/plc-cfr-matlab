function result = run_stage3a(mode)
%RUN_STAGE3A Run the new communication-OFDM topology-awareness baseline.
%   Existing stage-1.5 through stage-2.3 experiments are not rerun here.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    ensure_result_dirs(default_config(root));
    test_stage3a();
    result=exp12_stage3a_communication_baseline(mode);
end
