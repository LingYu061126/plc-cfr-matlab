function [H_pilot,H_active_hat,details] = stage3a_receive_ofdm(rx_frame,symbol,ofdm_cfg,impairment)
%STAGE3A_RECEIVE_OFDM Remove CP, FFT, and perform LS pilot estimation.
%   H_active_hat is obtained by complex linear interpolation for sparse
%   pilots. It is an equivalent sampled CFR, not a complete synchronizer.
    rx_frame=rx_frame(:).';
    n=ofdm_cfg.nfft; cp=symbol.cyclic_prefix_samples;
    offset=get_field(impairment,'timing_offset_samples',0);
    sco_ppm=get_field(impairment,'sample_clock_offset_ppm',0);
    if ~(isscalar(offset)&&isreal(offset)&&isfinite(offset)) || ...
            ~(isscalar(sco_ppm)&&isreal(sco_ppm)&&isfinite(sco_ppm))
        error('stage3a_receive_ofdm:InvalidTiming','Timing and clock errors must be finite scalars.');
    end
    start=cp+1+offset;
    sample_positions=start+(0:n-1)*(1+sco_ppm*1e-6);
    x=1:numel(rx_frame);
    re=interp1(x,real(rx_frame),sample_positions,'linear',0);
    im=interp1(x,imag(rx_frame),sample_positions,'linear',0);
    payload=re+1i*im;
    Y=fft(payload,n);
    bins=symbol.pilot_bin_1based;
    H_pilot=Y(bins)./symbol.X_pilot;
    H_active_hat=stage3a_interpolate_cfr(symbol.pilot_frequency_hz,H_pilot, ...
        ofdm_cfg.active_frequency_hz);
    details=struct('received_payload',payload,'Y_full',Y,'pilot_bins',bins, ...
        'timing_offset_samples',offset,'sample_clock_offset_ppm',sco_ppm, ...
        'interpolation','complex linear interpolation on active frequency grid');
end

function v=get_field(s,name,default)
    if isfield(s,name)&&~isempty(s.(name)),v=s.(name);else,v=default;end
end
