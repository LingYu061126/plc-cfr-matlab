function [library, audit, incompatible] = export_candidate_library(candidates, cfg, options)
%EXPORT_CANDIDATE_LIBRARY Adapt engineering graphs to the frozen interface.
%   Output candidates provide topology_id, canonical_key and network, which
%   are consumed by existing Stage 4A forward/profile functions. No Stage 4A
%   or Stage 5B.1 source file is modified by this compatibility boundary.
    if nargin<2||isempty(cfg),cfg=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<3||isempty(options),options=struct();end
    prefix=get_text(options,'id_prefix','S6A');
    require_compatible=get_field(options,'require_forward_compatible',true);
    rows={}; bad={}; reports={};reason_counts=struct();
    for k=1:numel(candidates)
        [c,report]=adapt_engineering_candidate_to_forward_model(candidates(k),cfg);
        if ~isfield(c,'network'),c.network=struct();end
        c.topology_id=sprintf('%s_%04d',prefix,k);
        c.id=c.topology_id;
        c.canonical_key=c.canonical_graph_key;
        c.export_schema='stage6a_forward_candidate_v1';
        c.export_source_graph_candidate_id=c.graph_candidate_id;
        reports{end+1}=report; %#ok<AGROW>
        if report.forward_model_compatible
            rows{end+1}=c; %#ok<AGROW>
        else
            field=matlab.lang.makeValidName(report.reason_code);
            if ~isfield(reason_counts,field),reason_counts.(field)=0;end
            reason_counts.(field)=reason_counts.(field)+1;
            bad{end+1}=c; %#ok<AGROW>
            if ~require_compatible,rows{end+1}=c;end %#ok<AGROW>
        end
    end
    library=pack(rows,candidates);incompatible=pack(bad,candidates);
    forward_count=0;
    for k=1:numel(reports),forward_count=forward_count+double(reports{k}.forward_model_compatible);end
    audit=struct('input_candidate_count',numel(candidates),'exported_candidate_count',numel(library), ...
        'forward_compatible_count',forward_count, ...
        'incompatible_candidate_count',numel(bad),'require_forward_compatible',logical(require_compatible), ...
        'incompatibility_reason_counts',reason_counts,'adapter_reports',{reports}, ...
        'schema','stage6a_forward_candidate_v1');
end
function out=pack(rows,prototype)
    if isempty(rows),out=prototype([]);return;end
    out=[rows{:}];
end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if isstring(x),x=char(x);end,end
