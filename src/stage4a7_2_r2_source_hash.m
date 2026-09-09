function hash = stage4a7_2_r2_source_hash(root_dir)
%STAGE4A7_2_R2_SOURCE_HASH Hash the complete repository scientific source.
%   Configuration, source and experiment MATLAB files are collected by
%   repository-relative path. Outputs, logs, timestamps, cache files and
%   machine-local absolute paths are excluded. Missing source files are hard
%   failures rather than placeholder hash inputs.
    if nargin<1 || isempty(root_dir), root_dir=fileparts(fileparts(mfilename('fullpath'))); end
    dirs={'config','src','experiments'}; rel={};
    for d=1:numel(dirs)
        p=fullfile(root_dir,dirs{d});
        if ~exist(p,'dir'), error('stage4a7_2_r2:MissingSourceDirectory','Missing source directory %s.',dirs{d}); end
        files=dir(fullfile(p,'*.m'));
        for k=1:numel(files), rel{end+1}=fullfile(dirs{d},files(k).name); end %#ok<AGROW>
    end
    run_files=dir(fullfile(root_dir,'run_stage4a*.m'));
    for k=1:numel(run_files), rel{end+1}=run_files(k).name; end %#ok<AGROW>
    rel=sort(unique(rel));
    payload=repmat(struct('relative_path','','content',''),numel(rel),1);
    for k=1:numel(rel)
        p=fullfile(root_dir,rel{k});
        if ~exist(p,'file'), error('stage4a7_2_r2:MissingSourceFile','Missing source file %s.',rel{k}); end
        payload(k).relative_path=strrep(rel{k},filesep,'/');
        payload(k).content=fileread(p);
    end
    hash=stage4a4_scientific_config_hash(payload);
end
