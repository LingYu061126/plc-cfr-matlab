function path=exp_stage7a4_15m_intervals(root,mode)
%EXP_STAGE7A4_15M_INTERVALS Read-only Wilson review of archived counts.
%   This postprocessor does not alter formal sample/summary/calibration
%   files. Intervals are observation-level for fixed synthetic topologies.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'));
    folder=fullfile(root,'results','data','stage7a_4_15m_continuous',mode);
    source=fullfile(folder,'summary.csv');assert(isfile(source));
    t=readtable(source,'TextType','string');
    events={'correct_unique','false_unique','truth_covered','nonempty', ...
        'ambiguous','low_confidence','rejected'};
    cols={'correct_unique_k','false_unique_k','truth_covered_k', ...
        'nonempty_k','ambiguous_k','low_confidence_k','rejected_k'};
    nrows=height(t)*numel(events);
    rows=table('Size',[nrows 14], ...
        'VariableTypes',{'string','double','string','string','string','string', ...
        'string','string','logical','double','double','double','double','logical'}, ...
        'VariableNames',{'regime','snr_db','variant','scheme','profile', ...
        'library','truth_id','event','applicable','k','n','ci_low', ...
        'ci_high','observation_level'});
    cursor=0;
    for i=1:height(t)
        for j=1:numel(events)
            cursor=cursor+1;applicable=true;
            if ~t.truth_in_library(i)&&ismember(events{j}, ...
                    {'correct_unique','truth_covered'})
                applicable=false;
            end
            rows.regime(cursor)=t.regime(i);
            rows.snr_db(cursor)=t.snr_db(i);
            rows.variant(cursor)=t.variant(i);
            rows.scheme(cursor)=t.scheme(i);
            rows.profile(cursor)=t.profile(i);
            rows.library(cursor)=t.library(i);
            rows.truth_id(cursor)=t.truth_id(i);
            rows.event(cursor)=string(events{j});
            rows.applicable(cursor)=applicable;
            rows.k(cursor)=t.(cols{j})(i);rows.n(cursor)=t.n(i);
            rows.observation_level(cursor)=true;
            if applicable
                [rows.ci_low(cursor),rows.ci_high(cursor)]= ...
                    stage7a4_wilson(rows.k(cursor),rows.n(cursor));
            else
                rows.ci_low(cursor)=NaN;rows.ci_high(cursor)=NaN;
            end
        end
    end
    path=fullfile(folder,'summary_intervals.csv');writetable(rows,path);
    manifest=table(string(strrep(source,[root filesep],'')), ...
        string(stage4a7_2_r2_sha256_file(source)), ...
        string(strrep(path,[root filesep],'')), ...
        string(stage4a7_2_r2_sha256_file(path)), ...
        string(stage4a7_2_r2_sha256_file([mfilename('fullpath') '.m'])), ...
        'VariableNames',{'source_relative_path','source_sha256', ...
        'derived_relative_path','derived_sha256','postprocessor_sha256'});
    writetable(manifest,fullfile(folder,'interval_manifest.csv'));
    fprintf('PASS Stage 7A.4 15m intervals: %d group-event rows\n',height(rows));
end
