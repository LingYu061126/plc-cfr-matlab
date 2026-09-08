function cache=stage4a7_2_r1_build_profile_template_cache(frequency_hz,candidates,theta_grid,cfg,measurement_kind)
%STAGE4A7_2_R1_BUILD_PROFILE_TEMPLATE_CACHE Build candidate-specific CFRs.
%   Each candidate is evaluated at every frozen nuisance-parameter template;
%   no observation truth is accepted by this function.
    if nargin<5||isempty(measurement_kind),measurement_kind='siso_forward';end
    n=numel(candidates);p=numel(theta_grid);f=frequency_hz(:).';
    H=cell(1,n);timer=tic;
    for k=1:n
        H{k}=complex(zeros(p,numel(f)));
        for q=1:p
            [net,local]=topology_apply_parameters(candidates(k).network,cfg,theta_grid(q));
            [m,~]=plc_measurement_bundle(measurement_kind,net,theta_grid(q),local);
            [v,~]=plc_multiview_response(f,net,m,local);
            H{k}(q,:)=v{1}(:).';
        end
    end
    cache=struct('frequency_hz',f,'candidate_ids',{arrayfun(@candidate_id,candidates,'UniformOutput',false)}, ...
        'candidates',candidates,'theta_grid',theta_grid,'H',{H}, ...
        'measurement_kind',measurement_kind,'template_count',p*n, ...
        'build_runtime_s',toc(timer),'cache_contains_truth',false);
end
function id=candidate_id(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
