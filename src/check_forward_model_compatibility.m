function [candidate, report] = check_forward_model_compatibility(candidate, cfg)
%CHECK_FORWARD_MODEL_COMPATIBILITY Separate engineering and model layers.
%   This conservative adapter recognizes the stable single-path/first-level
%   branch network interface used by the existing CFR model.  Unsupported
%   engineering graphs remain visible and are never silently deleted.
    reason=''; compatible=true;
    if ~isfield(candidate,'edges') || isempty(candidate.edges)
        compatible=false;reason='missing edge representation';
    elseif ~isfield(candidate,'network')
        compatible=false;reason='no stable-forward-model network adapter';
    end
    if compatible && isfield(candidate,'network')
        net=candidate.network;
        if ~isfield(net,'main_lengths')||~isfield(net,'main_cable_type')||~isfield(net,'branches')
            compatible=false;reason='network lacks main_lengths/main_cable_type/branches';
        elseif any(~isfinite(net.main_lengths(:)))||any(net.main_lengths(:)<=0)
            compatible=false;reason='invalid main line lengths';
        elseif numel(net.main_lengths)~=numel(net.main_cable_type)
            compatible=false;reason='main length and cable type count mismatch';
        elseif numel(net.branches)>1
            % The current stable adapter supports a first-level branch list,
            % but not nested branch subgraphs. A flat list is compatible.
            for k=1:numel(net.branches)
                if ~isfield(net.branches(k),'node')||~isscalar(net.branches(k).node)
                    compatible=false;reason='nested or non-scalar branch node unsupported';break;
                end
            end
        end
    end
    candidate.forward_model_compatible=compatible;
    candidate.compatibility_reason=ternary(compatible,'stable_single_path_first_level_branch',reason);
    candidate.adapter_hash=stage4a4_scientific_config_hash(struct('adapter','stage4a7_1_stable_network_adapter_v1','compatible',compatible,'reason',candidate.compatibility_reason));
    candidate.scored_library_included=compatible;
    report=struct('forward_model_compatible',compatible,'compatibility_reason',candidate.compatibility_reason, ...
        'adapter_hash',candidate.adapter_hash,'scored_library_included',compatible, ...
        'candidate_id',getf(candidate,'graph_candidate_id',''));
    if nargin>1 && ~isempty(cfg), report.cfg_supplied=true; else, report.cfg_supplied=false; end
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n),x=s.(n);else,x=d;end,end
