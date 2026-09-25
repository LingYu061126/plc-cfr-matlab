function bank=stage7a4_template_bank(candidates,base,cfg,asymmetry_grid)
%STAGE7A4_TEMPLATE_BANK Cache all views using one nuisance point per row.
%   templates{k,v} is parameter-template-by-frequency (complex). The same
%   row index across every view fixes main length, branch load and optional
%   first-segment asymmetry for physical topology k. No test observation or
%   truth label enters this function.
    if nargin<4||isempty(asymmetry_grid),asymmetry_grid=1;end
    [m,l,a]=ndgrid(cfg.main_scale_grid,cfg.branch_load_grid,asymmetry_grid);
    params=[m(:),l(:),a(:)];nv=numel(cfg.view_names);n=numel(candidates);
    templates=cell(n,nv);t=tic;calls=0;
    for k=1:n
        for v=1:nv,templates{k,v}=complex(zeros(size(params,1),numel(cfg.frequency_hz)));end
        for p=1:size(params,1)
            theta=theta_at(params(p,:));
            for s=1:numel(cfg.states)
                z=stage7a4_forward_state(candidates(k).network,theta,base,cfg.frequency_hz,cfg.states(s));
                calls=calls+1;
                if s<=numel(cfg.termination_ohm)
                    templates{k,2*s-1}(p,:)=z.H_endpoint;
                    templates{k,2*s}(p,:)=z.Zin;
                else
                    j=s-numel(cfg.termination_ohm);
                    ix=2*numel(cfg.termination_ohm)+2*j-1;
                    templates{k,ix}(p,:)=z.H_endpoint;
                    templates{k,ix+1}(p,:)=z.H_node;
                end
            end
            templates{k,nv}(p,:)=templates{k,5}(p,:); % independent H50 repeat
        end
    end
    ids={candidates.topology_id};
    signatures=arrayfun(@(x)stage6b_network_signature(x.network),candidates,'UniformOutput',false);
    payload=struct('ids',{ids},'signatures',{signatures},'params',params, ...
        'states',cfg.states,'frequency_hz',cfg.frequency_hz,'view_names',{cfg.view_names});
    bank=struct('templates',{templates},'params',params,'candidate_ids',{ids}, ...
        'candidate_signatures',{signatures},'view_names',{cfg.view_names}, ...
        'frequency_hz',cfg.frequency_hz,'state_count',numel(cfg.states), ...
        'forward_calls',calls,'build_time_s',toc(t), ...
        'identity',stage4a4_scientific_config_hash(payload));
    w=whos('templates');bank.logical_cache_bytes=w.bytes;
end

function theta=theta_at(p)
    theta=struct('main_length_scale',p(1),'branch_length_scale',1, ...
        'branch_load_scale',p(2),'first_segment_scale',p(3), ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end
