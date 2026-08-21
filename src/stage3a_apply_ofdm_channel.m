function [rx_frame,details] = stage3a_apply_ofdm_channel(symbol,H_active,ofdm_cfg,noise_cfg,impairment,seed)
%STAGE3A_APPLY_OFDM_CHANNEL Apply an equivalent OFDM frame channel.
%   H_active follows ofdm_cfg.active_bin_1based. The payload is filtered by
%   the specified sampled CFR, a CP is prepended, then noise and receiver
%   measurement errors are applied. Colored and impulsive noise are explicit
%   simulation models, not field-noise claims.
    H_active=H_active(:).';
    if numel(H_active)~=numel(ofdm_cfg.active_bin_1based) || any(~isfinite(H_active))
        error('stage3a_apply_ofdm_channel:InvalidCFR','H_active has invalid size/value.');
    end
    H_full=zeros(1,ofdm_cfg.nfft); H_full(ofdm_cfg.active_bin_1based)=H_active;
    y_payload=ifft(fft(symbol.payload).*H_full,ofdm_cfg.nfft);
    cp=symbol.cyclic_prefix_samples;
    if cp==0, prefix=zeros(1,0); else, prefix=y_payload(end-cp+1:end); end
    ideal=[prefix,y_payload];
    [noise,noise_details]=stage3a_noise(ideal,noise_cfg,seed);
    rx_frame=ideal+noise;
    phase=get_field(impairment,'pilot_phase_rotation_rad',0);
    if ~(isscalar(phase)&&isreal(phase)&&isfinite(phase))
        error('stage3a_apply_ofdm_channel:InvalidPhase','Invalid pilot phase rotation.');
    end
    rx_frame=rx_frame*exp(1i*phase);
    details=struct('H_active',H_active,'H_full',H_full,'ideal_frame',ideal, ...
        'noise',noise,'noise_details',noise_details,'phase_rotation_rad',phase, ...
        'channel_model','sampled CFR circular payload filtering with CP');
end

function [noise,d] = stage3a_noise(signal,spec,seed)
    if nargin<2||isempty(spec),spec=struct('kind','none','snr_db',Inf);end
    kind=lower(char(get_field(spec,'kind','none')));
    snr=get_field(spec,'snr_db',Inf);
    if ~(isscalar(snr)&&isreal(snr)&&(isfinite(snr)||(isinf(snr)&&snr>0)))
        error('stage3a_apply_ofdm_channel:InvalidSNR','Noise SNR must be finite or +Inf.');
    end
    p=mean(abs(signal).^2); if ~isfinite(p),error('stage3a_apply_ofdm_channel:NonfinitePower','Signal power is nonfinite.');end
    if isinf(snr),target=0;else,target=p/10^(snr/10);end
    old=rng; cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
    if nargin>=3 && ~isempty(seed),rng(seed,'twister');end
    n=zeros(size(signal));
    switch kind
        case 'none'
        case 'white_awgn'
            n=sqrt(target/2)*(randn(size(signal))+1i*randn(size(signal)));
        case 'colored_gaussian'
            w=randn(size(signal))+1i*randn(size(signal));
            f=(0:numel(signal)-1)/max(1,numel(signal)-1);
            shape=1+get_field(spec,'colored_tilt',0.8)*(1-f);
            n=ifft(fft(w).*shape); n=n*sqrt(target/max(mean(abs(n).^2),realmin));
        case 'impulsive'
            base_fraction=get_field(spec,'base_fraction',0.25);
            n=sqrt(target*base_fraction/2)*(randn(size(signal))+1i*randn(size(signal)));
            burst=max(1,round(get_field(spec,'burst_length_samples',8)));
            start=randi(max(1,numel(signal)-burst+1));
            idx=start:min(numel(signal),start+burst-1);
            factor=get_field(spec,'burst_factor',100);
            n(idx)=n(idx)+sqrt(target*factor/2)*(randn(size(idx))+1i*randn(size(idx)));
        otherwise
            error('stage3a_apply_ofdm_channel:UnknownNoise','Unknown noise kind %s.',kind);
    end
    noise=n;
    d=struct('kind',kind,'snr_db',snr,'signal_power',p, ...
        'target_noise_power',target,'actual_noise_power',mean(abs(n).^2), ...
        'seed',seed);
end

function v=get_field(s,name,default)
    if isfield(s,name)&&~isempty(s.(name)),v=s.(name);else,v=default;end
end
