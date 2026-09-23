function [library,timing,audit]=stage6b_build_candidate_library(kind,spec,base,options)
%STAGE6B_BUILD_CANDIDATE_LIBRARY Build without changing Stage 6A logic.
    if nargin<4||isempty(options),options=struct();end
    kind=lower(char(kind));whole=tic;
    timing=struct('generation_time_s',0,'constraint_time_s',0,'ranking_time_s',0, ...
        'export_time_s',0,'total_time_s',0);
    switch kind
        case 'partial_prior'
            t=tic;[raw,ga]=generate_candidate_topologies(spec);timing.generation_time_s=toc(t);
            t=tic;[valid,ca]=apply_topology_constraints(raw,spec);timing.constraint_time_s=toc(t);
            t=tic;[ranked,ra]=rank_candidate_complexity(valid,get_field(options,'rank',struct()));timing.ranking_time_s=toc(t);
            export_options=get_field(options,'export',struct('id_prefix','S6B','require_forward_compatible',true));
            t=tic;[library,ea]=export_candidate_library(ranked,base,export_options);timing.export_time_s=toc(t);
            audit=struct('kind',kind,'generation',ga,'constraints',ca,'ranking',ra,'export',ea);
        case 'radial_grammar'
            t=tic;library=generate_radial_topology_candidates(spec);timing.generation_time_s=toc(t);
            audit=struct('kind',kind,'candidate_count',numel(library),'grammar',spec);
        otherwise
            error('stage6b:UnknownLibraryKind','Unknown candidate library kind %s.',kind);
    end
    timing.total_time_s=toc(whole);
    assert(numel(library)>=2,'stage6b:TooFewCandidates','Robustness evaluation requires at least two candidates.');
end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
