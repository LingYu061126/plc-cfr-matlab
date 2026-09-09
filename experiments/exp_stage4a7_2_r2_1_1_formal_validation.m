function summary=exp_stage4a7_2_r2_1_1_formal_validation(root)
%EXP_STAGE4A7_2_R2_1_1_FORMAL_VALIDATION Fresh formal rerun in a new tree.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    output_root=fullfile(root,'results','data','stage4a7_2_r2_1_1');
    summary=exp_stage4a7_2_r2_1_independent_validation(root,'formal',output_root,'Stage 4A.7.2-R.2.1.1');
end
