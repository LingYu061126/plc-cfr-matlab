function out = run_stage4a6_3_1_r2_equivalence_parallel(root, workers, mode)
%RUN_STAGE4A6_3_1_R2_EQUIVALENCE_PARALLEL Run one R.2 fixed-size pilot.
%   This entry point is intentionally small so serial and parallel calls use
%   the same experiment function.  It does not run final_reserved scenarios.
    if nargin < 1 || isempty(root), root=fileparts(mfilename('fullpath')); end
    if nargin < 2 || isempty(workers), workers=1; end
    if nargin < 3 || isempty(mode), mode='pilot'; end
    use_parallel=workers>1;
    if strcmpi(mode,'pilot') && workers==1
        output_dir='';
    else
        output_dir=fullfile(root,'results','data','stage4a6_3_1_r2', ...
            sprintf('benchmark_w%02d',workers));
    end
    out=exp_stage4a6_3_1_r2_equivalence_parallel(root,use_parallel,workers,output_dir);
end
