function audit = stage4a7_2_r2_scenario_equivalence(candidates,theta_grid,frequency_hz,base,measurement_kind,max_count,tolerance)
%STAGE4A7_2_R2_SCENARIO_EQUIVALENCE Compute same-theta equivalence directly.
%   Truth sets are produced only from calculated CFR comparisons.  No
%   candidate is declared equivalent from a legacy label or decision output.
    n=min(max_count,numel(theta_grid)); rows=repmat(row_template(),0,1);
    H=cell(n,numel(candidates));
    for q=1:n
        for k=1:numel(candidates),H{q,k}=candidate_cfr(candidates(k),theta_grid(q),frequency_hz,base,measurement_kind);end
        for a=1:numel(candidates)
            for b=a+1:numel(candidates)
                x=H{q,a};y=H{q,b};dc=sqrt(mean(abs(x-y).^2));
                dm=sqrt(mean((abs(x)-abs(y)).^2));
                ph=unwrap(angle(x))-unwrap(angle(y));dp=sqrt(mean(ph.^2));
                if dc<=tolerance
                    r=row_template();r.sample_id=sprintf('r2_eq_%03d_%03d_%03d',q,a,b);
                    r.theta_index=q;r.candidate_a=candidate_id(candidates(a));
                    r.candidate_b=candidate_id(candidates(b));r.same_theta_distance=dc;
                    r.magnitude_distance=dm;r.phase_distance=dp;r.equivalence_tolerance=tolerance;
                    r.equivalence_status='same_theta_equivalent';r.equivalence_evaluable=true;
                    r.parameter_vector_hash=stage4a4_scientific_config_hash(theta_grid(q));
                    r.cfr_hash_a=stage4a4_scientific_config_hash(x);r.cfr_hash_b=stage4a4_scientific_config_hash(y);
                    rows(end+1)=r; %#ok<AGROW>
                end
            end
        end
    end
    audit=struct('status',ternary(isempty(rows),'no_same_theta_equivalent_pair','completed'), ...
        'requested_count',max_count,'unique_count',n,'duplicate_count',0, ...
        'rows',rows,'candidate_count',numel(candidates),'tolerance',tolerance, ...
        'definition','same-theta CFR equivalence under fixed model, frequency grid and tolerance');
end
function h=candidate_cfr(c,theta,f,base,kind)
    [net,local]=topology_apply_parameters(c.network,base,theta);[m,~]=plc_measurement_bundle(kind,net,theta,local);[v,~]=plc_multiview_response(f,net,m,local);h=v{1}(:).';
end
function id=candidate_id(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function r=row_template()
    r=struct('sample_id','','theta_index',0,'candidate_a','','candidate_b','', ...
        'same_theta_distance',NaN,'magnitude_distance',NaN,'phase_distance',NaN, ...
        'equivalence_tolerance',NaN,'equivalence_status','','equivalence_evaluable',false, ...
        'parameter_vector_hash','','cfr_hash_a','','cfr_hash_b','');
end
