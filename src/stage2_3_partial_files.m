function [files,expected,prefix]=stage2_3_partial_files(results_data,measurement_kinds,run_mode)
%STAGE2_3_PARTIAL_FILES Find sealed Stage-2.3 batches for one run mode.
%   Untagged legacy batches are deliberately excluded because their source
%   mode cannot be established safely.
    if nargin<3||isempty(run_mode),run_mode='formal';end
    run_mode=lower(char(run_mode));
    if ~ismember(run_mode,{'smoke','formal'})
        error('stage2_3_partial_files:InvalidMode','run_mode must be smoke or formal.');
    end
    expected=numel(measurement_kinds);
    if strcmp(run_mode,'formal'),expected=2*expected;end
    prefix=['stage2_3_' run_mode '_partial_'];
    files=dir(fullfile(results_data,[prefix '*_results.mat']));
end
