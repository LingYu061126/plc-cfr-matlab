function [views,details] = stage3a_compute_observations(f_hz,candidate,base_cfg,theta,kind)
%STAGE3A_COMPUTE_OBSERVATIONS Generate one complete-network observation O.
%   Ordinary configurations call the existing complete-network multiview
%   interface. Reflection and admittance entries are explicitly labelled
%   derived proxies and are not time-domain FDR/TFDR measurements.
    info=stage3a_observation_config(kind);
    [network,cfg_theta,theta]=stage3a_apply_parameters(candidate.network,base_cfg,theta); %#ok<ASGLU>
    if strcmp(info.O,'ordinary_ofdm_cfr')
        [measurements,meta]=plc_measurement_bundle(info.kind,network,theta,cfg_theta);
        [views,solve]=plc_multiview_response(f_hz,network,measurements,cfg_theta);
        details=struct('O',info.O,'physical_quantity',info.physical_quantity, ...
            'measurement_kind',info.kind,'metadata',meta,'network_complete',true, ...
            'view_count',numel(views),'solve_details',solve,'is_proxy',false);
    else
        [~,d]=cascade_network_stable(f_hz,network,cfg_theta);
        Zin=d.input_impedance; Zref=cfg_theta.port_reference_ohm;
        if strcmp(info.O,'fdr_tfdr_reflection_proxy')
            views={((Zin-Zref)./(Zin+Zref))};
        else
            views={1./Zin};
        end
        details=struct('O',info.O,'physical_quantity',info.physical_quantity, ...
            'measurement_kind',info.kind,'network_complete',true,'view_count',1, ...
            'input_impedance_ohm',Zin,'is_proxy',true,'description',info.description);
    end
end
