function channel = stage3b_waveform_channel(tx, H_positive, cfg, impairment_spec, noise_spec, seed, test_causal_h)
%STAGE3B_WAVEFORM_CHANNEL Map sampled CFR to a linear-convolution waveform.
%   H_positive is the existing network response sampled on the explicit
%   positive-frequency study mask.  Its IFFT produces a band-limited,
%   circular discrete response with no calibrated physical time origin.
%   test_causal_h is only for analytical CP tests; it is not a PLC channel.

    if nargin < 4 || isempty(impairment_spec), impairment_spec=cfg.impairments; end
    if nargin < 5 || isempty(noise_spec), noise_spec=cfg.noise; end
    if nargin < 6 || isempty(seed), seed=1; end
    if nargin < 7, test_causal_h=[]; end
    H_positive=H_positive(:).'; bins=cfg.carrier.positive_bins;
    if numel(H_positive)~=numel(bins)
        error('stage3b_waveform_channel:SizeMismatch','H_positive must match positive study bins.');
    end
    front=frontend_response(cfg,numel(bins));
    H_positive_effective=H_positive.*front;
    H_full=zeros(1,cfg.nfft);
    H_full(bins)=H_positive_effective;
    H_full(cfg.carrier.mirror_bins)=conj(H_positive_effective);
    if isempty(test_causal_h)
        h=real(ifft(H_full,cfg.nfft));
        response_kind='bandlimited_sampled_cfr_ifft'; physical_delay=false;
    else
        h=test_causal_h(:).';
        H_full=fft(h,cfg.nfft);
        H_positive_effective=H_full(bins);
        response_kind='synthetic_causal_test_fir'; physical_delay=true;
    end
    y_line=conv(tx.frame,h); % Linear convolution is intentional.
    [y_sync,sync_meta]=stage3b_waveform_sync_impairments(y_line,cfg,impairment_spec);
    [y,noise,noise_meta]=stage3b_waveform_noise(y_sync,cfg,noise_spec,seed);
    channel=struct('H_positive_input',H_positive,'H_positive_effective',H_positive_effective, ...
        'H_full',H_full,'h_discrete',h,'response_kind',response_kind, ...
        'line_output',y_line,'rx_waveform',y,'noise',noise, ...
        'sync',sync_meta,'noise_meta',noise_meta, ...
        'cp_audit',stage3b_waveform_cp_audit(h,cfg.gi.ncp_samples, ...
            cfg.cp_audit_threshold_db,physical_delay), ...
        'frontend_status',cfg.frontend.status);
end

function g=frontend_response(cfg,n)
    fields={'C_tx_positive','C_rx_positive','H_frontend_positive'}; g=ones(1,n);
    for k=1:numel(fields)
        x=cfg.frontend.(fields{k});
        if isempty(x), continue; end
        if isscalar(x), x=repmat(x,1,n); end
        if numel(x)~=n, error('stage3b_waveform_channel:FrontendSize','%s must be scalar or one value per active bin.',fields{k}); end
        g=g.*reshape(x,1,[]);
    end
end
