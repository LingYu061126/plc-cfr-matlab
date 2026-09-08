function summary=run_stage4a7_2_r1_data_driven_closure(mode)
%RUN_STAGE4A7_2_R1_DATA_DRIVEN_CLOSURE Run the controlled R.1 pilot.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));diary_path=fullfile(root,'results','logs',['stage4a7_2_r1_' mode '.log']);
    if ~exist(fileparts(diary_path),'dir'),mkdir(fileparts(diary_path));end
    diary(diary_path);cleanup=onCleanup(@()diary('off'));fprintf('Stage 4A.7.2-R.1 mode=%s\n',mode);disp(version);summary=exp_stage4a7_2_r1_data_driven_closure(root,mode);disp(summary);
end
