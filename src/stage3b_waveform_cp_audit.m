function audit = stage3b_waveform_cp_audit(h, ncp, threshold_db, physical_delay_available)
%STAGE3B_WAVEFORM_CP_AUDIT Support audit; it does not estimate physical ToA.
    if nargin < 4, physical_delay_available = false; end
    peak = max(abs(h));
    if peak == 0
        support_samples = 0;
    else
        last = find(abs(h) >= peak*10^(threshold_db/20),1,'last');
        support_samples = last - 1;
    end
    audit = struct('threshold_db',threshold_db,'effective_support_samples',support_samples, ...
        'ncp_samples',ncp,'mathematically_covered',ncp>=support_samples, ...
        'physical_delay_available',logical(physical_delay_available), ...
        'interpretation',['support is defined on this discrete sampled response; ' ...
            'without calibrated time origin it is not physical propagation delay']);
end
