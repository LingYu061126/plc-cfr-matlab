function sc=stage4a_freeze_r1_config(base,mode)
%STAGE4A_FREEZE_R1_CONFIG Frozen output-only reproducibility wrapper.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='formal';end
    sc=stage4a7_3_domain_validation_config(base,mode);
    sc.stage_name='Stage 4A Freeze-R.1';sc.version='stage4a_freeze_r1_v1';
    sc.output_root=fullfile(base.root_dir,'results','data','stage4a_freeze_r1','stage4a7_3');
    sc.results_logs=fullfile(base.root_dir,'results','logs','stage4a_freeze_r1');
    sc.freeze_root=fullfile(base.root_dir,'results','data','stage4a_freeze_r1');
    sc.sensitivity_root=fullfile(sc.freeze_root,'sensitivity');
end
