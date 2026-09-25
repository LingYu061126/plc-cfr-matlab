function [clean,observed]=stage7a4_measure_views(network,theta,base,cfg,seed,snr_db,modifiers)
%STAGE7A4_MEASURE_VIEWS Simulate labelled complex CFR/ohm observations.
%   All states share the same physical theta. Each view receives independent
%   complex Gaussian error. CFR RMS noise follows the declared SNR; Zin has
%   the separate assumed 1-ohm RMS error. Seed is a split/sample identity.
    if nargin<7||isempty(modifiers),modifiers=struct();end
    nv=numel(cfg.view_names);clean=cell(1,nv);observed=cell(1,nv);
    for s=1:numel(cfg.states)
        state=cfg.states(s);local_theta=theta;
        if isfield(modifiers,'second_termination_error_fraction') && ...
                abs(state.receiver_ohm-50)>1e-12
            state.receiver_ohm=state.receiver_ohm*(1+modifiers.second_termination_error_fraction);
        end
        if isfield(modifiers,'second_branch_load_drift_fraction') && ...
                abs(state.receiver_ohm-50)>1e-12
            local_theta.branch_load_scale=theta.branch_load_scale* ...
                (1+modifiers.second_branch_load_drift_fraction);
        end
        if state.node_index>0&&isfield(modifiers,'node_port_error_fraction')
            state.node_load_ohm=state.node_load_ohm*(1+modifiers.node_port_error_fraction);
        end
        z=stage7a4_forward_state(network,local_theta,base,cfg.frequency_hz,state);
        if s<=numel(cfg.termination_ohm)
            clean{2*s-1}=z.H_endpoint;clean{2*s}=z.Zin;
        else
            j=s-numel(cfg.termination_ohm);
            ix=2*numel(cfg.termination_ohm)+2*j-1;
            clean{ix}=z.H_endpoint;clean{ix+1}=z.H_node;
        end
    end
    clean{nv}=clean{5};
    rs=RandStream('mt19937ar','Seed',seed);
    for v=1:nv
        if startsWith(cfg.view_names{v},'Zin')
            sigma=cfg.zin_error_rms_ohm;
        else
            sigma=sqrt(mean(abs(clean{v}).^2))/10^(snr_db/20);
        end
        observed{v}=clean{v}+sigma/sqrt(2)* ...
            (randn(rs,size(clean{v}))+1i*randn(rs,size(clean{v})));
    end
end
