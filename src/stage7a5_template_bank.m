function bank=stage7a5_template_bank(pool,base,cfg)
%STAGE7A5_TEMPLATE_BANK Share H50/Zin50 templates across all three flows.
%   Each parameter row requires one forward solve and provides both views.
    [m,l]=ndgrid(cfg.main_scale_grid,cfg.load_scale_grid);params=[m(:),l(:)];
    nf=numel(cfg.frequency_hz);templates=cell(numel(pool),2);calls=0;t=tic;
    for k=1:numel(pool)
        templates{k,1}=complex(zeros(size(params,1),nf));
        templates{k,2}=complex(zeros(size(params,1),nf));
        for q=1:size(params,1)
            theta=theta_at(params(q,:));
            z=stage7a4_forward_state(pool(k).network,theta,base, ...
                cfg.frequency_hz,cfg.state_50);
            templates{k,1}(q,:)=z.H_endpoint;
            templates{k,2}(q,:)=z.Zin;calls=calls+1;
        end
    end
    ids={pool.topology_id};sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool,'UniformOutput',false);
    search_identity=stage4a4_scientific_config_hash(struct( ...
        'main_bounds',cfg.main_scale_bounds,'load_bounds',cfg.load_scale_bounds, ...
        'main_grid',cfg.main_scale_grid,'load_grid',cfg.load_scale_grid, ...
        'frequency_hz',cfg.frequency_hz,'state',cfg.state_50));
    payload=struct('ids',{ids},'signatures',{sigs},'params',params, ...
        'views',{{'H50','Zin50'}},'search_identity',search_identity);
    bank=struct('templates',{templates},'params',params,'candidate_ids',{ids}, ...
        'candidate_signatures',{sigs},'view_names',{{'H50','Zin50'}}, ...
        'frequency_hz',cfg.frequency_hz,'identity',stage4a4_scientific_config_hash(payload), ...
        'search_identity',search_identity,'forward_calls',calls, ...
        'build_time_s',toc(t),'candidate_count',numel(pool));
    w=whos('templates');bank.logical_cache_bytes=w.bytes;
    assert(calls<=cfg.max_forward_template_evaluations,'stage7a5:ForwardBudget');
end

function theta=theta_at(p)
    theta=struct('main_length_scale',p(1),'branch_length_scale',1, ...
        'branch_load_scale',p(2),'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end
