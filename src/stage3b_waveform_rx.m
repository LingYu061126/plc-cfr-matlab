function rx = stage3b_waveform_rx(rx_waveform, tx, cfg, expected_H_positive)
%STAGE3B_WAVEFORM_RX Nominal-timing CP removal, FFT and known-training LS.
%   The receiver intentionally has no hidden synchronization estimator: the
%   impairment interface lets tests expose the resulting estimation error.
    if ~strcmp(tx.kind,'training')
        error('stage3b_waveform_rx:TrainingRequired','LS estimate requires a known training symbol.');
    end
    start=cfg.gi.ncp_samples+1; stop=start+cfg.nfft-1;
    r=rx_waveform(:).';
    if numel(r)<stop, r=[r zeros(1,stop-numel(r))]; end
    payload=r(start:stop);
    if cfg.gi.window_enabled
        valid=abs(tx.window)>eps;
        payload(valid)=payload(valid)./tx.window(valid);
    end
    Y=fft(payload,cfg.nfft);
    bins=tx.positive_bins;
    invalid=abs(tx.X_positive)<sqrt(eps);
    Hhat=Y(bins)./tx.X_positive;
    Hhat(invalid)=NaN;
    Hfull=zeros(1,cfg.nfft); Hfull(bins)=Hhat;
    Hfull(cfg.carrier.mirror_bins)=conj(Hhat);
    rx=struct('payload_after_cp',payload,'Y_full',Y,'H_positive_hat',Hhat, ...
        'H_full_hat',Hfull,'invalid_positive_mask',invalid,'ls_status', ...
        'known-training LS on enabled study bins; no interpolation required');
    if nargin>=4 && ~isempty(expected_H_positive)
        expected_H_positive=expected_H_positive(:).';
        rx.cfr_nmse=sum(abs(Hhat-expected_H_positive).^2)/max(sum(abs(expected_H_positive).^2),realmin);
    else
        rx.cfr_nmse=NaN;
    end
end
