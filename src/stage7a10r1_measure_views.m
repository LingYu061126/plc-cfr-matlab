function [clean,observed,calls]=stage7a10r1_measure_views(network,theta,base,cfg,seed,snr_db,kind,bias)
%STAGE7A10R1_MEASURE_VIEWS Paired node-state perturbation in full forward model.
%   Output cells are 1-by-F complex CFR or ohm spectra. The first H50
%   acquisition is unchanged; bias is constant across frequency, not noise.
    assert(ismember(kind,{'node_port_bias','node_acquisition_load_drift'}), ...
        'stage7a10r1:Condition');
    assert(isfinite(bias)&&abs(bias)<1,'stage7a10r1:Bias');
    nv=numel(cfg.view_names);clean=cell(1,nv);observed=cell(1,nv);
    calls=0;
    for s=1:numel(cfg.states)
        state=cfg.states(s);local_theta=theta;
        if state.node_index>0
            if strcmp(kind,'node_port_bias')
                state.node_load_ohm=state.node_load_ohm*(1+bias);
            else
                local_theta.branch_load_scale=theta.branch_load_scale*(1+bias);
            end
        end
        z=stage7a4_forward_state(network,local_theta,base,cfg.frequency_hz,state);
        calls=calls+1;
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
