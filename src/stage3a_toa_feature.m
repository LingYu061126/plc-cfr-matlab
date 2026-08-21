function [delay_s,details] = stage3a_toa_feature(H,ofdm_cfg)
%STAGE3A_TOA_FEATURE Return the circular-delay proxy from a band-limited CFR.
%   This is deliberately not physical ToA or ranging: no CP calibration,
%   negative-frequency completion, or time synchronization is performed.
    full_cfg=ofdm_cfg;
    full_cfg.pilot_bin_1based=ofdm_cfg.active_bin_1based;
    [cir,time_s]=ofdm_cfr_to_cir(H,full_cfg);
    [~,idx]=max(abs(cir)); delay_s=time_s(idx);
    details=struct('name','circular band-limited CIR delay proxy', ...
        'is_physical_toa',false,'peak_index',idx,'cir',cir,'time_s',time_s);
end
