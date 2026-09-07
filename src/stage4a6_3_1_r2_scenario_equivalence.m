function audit = stage4a6_3_1_r2_scenario_equivalence(scenario, observed_views, candidates, cache, cfg, frequency_hz, eq_cfg, subband_sets, raw)
%STAGE4A6_3_1_R2_SCENARIO_EQUIVALENCE Offline scenario-level equivalence.
% Truth-bearing inputs are restricted to scoring/audit code, never matcher code.
    if nargin < 8, subband_sets = {}; end
    if nargin < 9, raw = []; end
    ids={candidates.topology_id};truth=scenario.truth_topology_id;
    truth_i=find(strcmp(ids,truth),1);tol=eq_cfg.same_theta_relative_tolerance;
    nominal='';if isfield(scenario,'truth_equivalence_set'),nominal=scenario.truth_equivalence_set;end
    same_ids={};composite_ids={};notcomp={};status='evaluable';
    if isempty(truth_i),status='truth_topology_not_in_candidate_library';
    else
        % The same physical theta is applied to each candidate. A candidate
        % that cannot accept the theta is not comparable, not non-equivalent.
        for j=1:numel(candidates)
            try
                [net,lcfg]=topology_apply_parameters(candidates(j).network,cfg,scenario.truth_theta);
                [meas,~]=plc_measurement_bundle('siso_forward',net,scenario.truth_theta,lcfg);
                [pred,~]=plc_multiview_response(frequency_hz(:).',net,meas,lcfg);
                if response_close(pred,observed_views,tol),same_ids{end+1}=ids{j};end %#ok<AGROW>
            catch
                notcomp{end+1}=ids{j}; %#ok<AGROW>
            end
        end
        % Composite equivalence is a diagnostic based on the frozen library;
        % its tolerance is separate from confirmation thresholds.
        if isempty(raw) && ~isempty(subband_sets)
            try
                raw=score_stage4a5_observation(observed_views,cache,subband_sets, ...
                    struct('stability_seed',1,'repetitions',1));
            catch
                raw=[];
            end
        end
        if isstruct(raw)&&isfield(raw,'topology_scores')&&isfield(raw,'topology_labels')
            s=raw.topology_scores(:);finite_s=s(isfinite(s));
            if ~isempty(finite_s)
                b=min(finite_s);keep=s<=b+eq_cfg.composite_relative_distance_tolerance*max(abs(b),1);
                composite_ids=raw.topology_labels(keep);
                if ischar(composite_ids),composite_ids={composite_ids};end
            end
        end
    end
    if ~isempty(notcomp)&&isempty(same_ids),status='partially_comparable';end
    if isempty(notcomp) && isempty(same_ids),status='evaluable_unique';end
    eq_hash=getfield_default(eq_cfg,'hash',getfield_default(eq_cfg,'definition_version',''));
    audit=struct('sample_id',scenario.sample_id,'truth_topology_id',truth, ...
        'nominal_equivalence_set',nominal,'same_theta_equivalence_set',strjoin(same_ids,','), ...
        'same_theta_equivalence_member_count',numel(same_ids), ...
        'composite_equivalence_set',strjoin(composite_ids,','), ...
        'composite_equivalence_member_count',numel(composite_ids), ...
        'not_comparable_under_same_theta',strjoin(notcomp,','), ...
        'equivalence_tolerance',tol,'comparison_status',status, ...
        'equivalence_configuration_hash',eq_hash, ...
        'scenario_parameter_hash',getfield_default(scenario,'parameter_vector_hash',''), ...
        'scenario_observation_hash',getfield_default(scenario,'observation_hash',''), ...
        'equivalence_evaluable',~strcmp(status,'truth_topology_not_in_candidate_library') && ...
            ~strcmp(status,'error'));
end
function tf=response_close(a,b,tol)
    if numel(a)~=numel(b),tf=false;return;end
    tf=true;for k=1:numel(a),den=max(max(abs(b{k}(:))),1);tf=tf&&max(abs(a{k}(:)-b{k}(:)))/den<=tol;end
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
