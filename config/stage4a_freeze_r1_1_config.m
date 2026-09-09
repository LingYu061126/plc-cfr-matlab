function sc=stage4a_freeze_r1_1_config(base,mode,freeze_root_override,source_override)
%STAGE4A_FREEZE_R1_1_CONFIG Canonical clean-source archive configuration.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='formal';end
    assert(ismember(lower(char(mode)),{'smoke','formal'}),'stage4a_freeze_r1_1:Mode','Mode must be smoke or formal.');
    if nargin<3||isempty(freeze_root_override)
        freeze_root=fullfile(base.root_dir,'results','data','stage4a_freeze_r1_1');
    else
        freeze_root=char(freeze_root_override);
    end
    sc=stage4a7_3_domain_validation_config(base,mode);
    sc.stage_name='Stage 4A Freeze-R.1.1';
    sc.version='stage4a_freeze_r1_1_v1';
    % R2.1.2 archive and Stage 4A.7.3 share the frozen v3 source root;
    % the latter resolves its formal subdirectory internally.
    sc.source_formal_dir=fullfile(base.root_dir,'results','data','stage4a7_2_r2_1_1','final_source_v3');
    sc.freeze_root=freeze_root;
    sc.output_root=fullfile(freeze_root,'stage4a7_3');
    sc.results_logs=fullfile(base.root_dir,'results','logs','stage4a_freeze_r1_1');
    if nargin>=4&&~isempty(source_override),sc.source_formal_dir=char(source_override);end
    sc.canonical_status=ternary(strcmpi(mode,'formal'),'canonical','history_or_smoke');
    sc.final_reserved_status='manifest_only_not_materialized';
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
