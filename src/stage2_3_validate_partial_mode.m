function stage2_3_validate_partial_mode(partial,run_mode,partial_path)
%STAGE2_3_VALIDATE_PARTIAL_MODE Reject a renamed batch from another mode.
    if nargin<3||isempty(partial_path),partial_path='partial result';end
    if ~isstruct(partial)||~isfield(partial,'mode')||isempty(partial.mode) || ...
            ~strcmpi(char(partial.mode),char(run_mode))
        error('stage2_3_validate_partial_mode:ModeMismatch', ...
            '%s is not a sealed %s result batch.',partial_path,run_mode);
    end
end
