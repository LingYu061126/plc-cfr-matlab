function [files,expected,prefix]=stage2_3_partial_files(results_data,measurement_kinds,run_mode)
%STAGE2_3_PARTIAL_FILES Find sealed Stage-2.3 batches for one run mode.
%   Untagged legacy batches are deliberately excluded because their source
%   mode cannot be established safely.
    if nargin<3||isempty(run_mode),run_mode='formal';end
    run_mode=lower(char(run_mode));
    if ~ismember(run_mode,{'smoke','formal'})
        error('stage2_3_partial_files:InvalidMode','run_mode must be smoke or formal.');
    end
    if ~iscell(measurement_kinds)||isempty(measurement_kinds)|| ...
            any(~cellfun(@(x)ischar(x)||(isstring(x)&&isscalar(x)),measurement_kinds))
        error('stage2_3_partial_files:InvalidMeasurementKinds', ...
            'measurement_kinds must be a nonempty cell array of text labels.');
    end
    measurement_kinds=cellfun(@char,measurement_kinds,'UniformOutput',false);
    if numel(unique(measurement_kinds))~=numel(measurement_kinds)
        error('stage2_3_partial_files:DuplicateMeasurementKinds', ...
            'measurement_kinds contains duplicate labels.');
    end
    batches_per_kind=1;
    if strcmp(run_mode,'formal'),batches_per_kind=2;end
    expected=numel(measurement_kinds)*batches_per_kind;
    prefix=['stage2_3_' run_mode '_partial_'];
    files=dir(fullfile(results_data,[prefix '*_results.mat']));
    names={files.name};
    if numel(files)~=expected
        error('stage2_3_partial_files:BatchCount', ...
            ['Expected %d batches (%d kinds x %d batches/kind) for %s; found %d.\n' ...
             'Expected names: %s\nFound names: %s'],expected,numel(measurement_kinds), ...
            batches_per_kind,run_mode,numel(files),expected_names(measurement_kinds,run_mode,batches_per_kind), ...
            join_names(names));
    end
    seen=cell(0,1);
    for k=1:numel(files)
        token=regexp(files(k).name, ...
            ['^stage2_3_' run_mode '_partial_(.+)_b([0-9]+)_results\.mat$'], ...
            'tokens','once');
        if isempty(token)
            error('stage2_3_partial_files:InvalidFilename', ...
                'Invalid %s batch filename: %s',run_mode,files(k).name);
        end
        kind=token{1};batch=str2double(token{2});
        if ~ismember(kind,measurement_kinds)
            error('stage2_3_partial_files:UnexpectedMeasurementKind', ...
                'Filename %s contains unexpected measurement_kind %s.',files(k).name,kind);
        end
        if ~isscalar(batch)||~isfinite(batch)||batch~=fix(batch)||batch<1||batch>batches_per_kind
            error('stage2_3_partial_files:InvalidBatchNumber', ...
                'Filename %s has batch number %s; expected 1..%d.',files(k).name,token{2},batches_per_kind);
        end
        key=sprintf('%s|%d',kind,batch);
        if any(strcmp(seen,key))
            error('stage2_3_partial_files:DuplicateBatch', ...
                'Duplicate sealed batch key %s; file %s.',key,files(k).name);
        end
        seen{end+1,1}=key; %#ok<AGROW>
        path=fullfile(files(k).folder,files(k).name);
        x=load(path,'mode','sc','config');
        stage2_3_validate_partial_mode(x,run_mode,path);
        if ~isfield(x,'sc')||~isstruct(x.sc)||~isfield(x.sc,'measurement_kinds')|| ...
                numel(x.sc.measurement_kinds)~=1||~strcmp(char(x.sc.measurement_kinds{1}),kind)
            error('stage2_3_partial_files:ConfigurationMismatch', ...
                'Filename %s measurement_kind=%s disagrees with MAT sc.measurement_kinds.', ...
                files(k).name,kind);
        end
        if ~isfield(x,'config')||~isstruct(x.config)||isempty(x.config)|| ...
                any(~strcmp({x.config.measurement_kind},kind))
            error('stage2_3_partial_files:ConfigurationMismatch', ...
                'Filename %s measurement_kind=%s disagrees with MAT config.',files(k).name,kind);
        end
    end
    expected_keys=cell(numel(measurement_kinds)*batches_per_kind,1);n=0;
    for q=1:numel(measurement_kinds),for b=1:batches_per_kind,n=n+1;expected_keys{n}=sprintf('%s|%d',measurement_kinds{q},b);end,end
    missing=expected_keys(~ismember(expected_keys,seen));
    if ~isempty(missing)
        error('stage2_3_partial_files:MissingBatch', ...
            'Missing sealed batch keys for %s: %s. Found files: %s',run_mode, ...
            strjoin(missing,', '),join_names(names));
    end
end

function text=expected_names(kinds,mode,batches)
    names=cell(numel(kinds)*batches,1);n=0;
    for q=1:numel(kinds),for b=1:batches,n=n+1;names{n}=sprintf('stage2_3_%s_partial_%s_b%d_results.mat',mode,kinds{q},b);end,end
    text=strjoin(names,', ');
end
function text=join_names(names)
    if isempty(names),text='(none)';else,text=strjoin(names,', ');end
end
