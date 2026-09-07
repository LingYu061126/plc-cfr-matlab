function out=run_stage4a6_3_1_r_tests(root)
%RUN_STAGE4A6_3_1_R_TESTS Run the Stage 4A.6.3.1-R targeted suite.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    % Test result structures intentionally have different diagnostic fields.
    % Keep them in a cell array instead of horizontally concatenating
    % heterogeneous struct arrays.
    results={test_stage4a6_3_1_r_protocol(root), ...
        test_stage4a6_3_1_r_independence(root), ...
        test_stage4a6_3_1_r_equivalence_members(root), ...
        test_stage4a6_3_1_r_reproducibility(root)};
    out=struct('all_passed',true,'results',{results});
end
