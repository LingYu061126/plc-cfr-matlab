function [y, noise, meta] = stage3b_waveform_noise(x, cfg, spec, seed)
%STAGE3B_WAVEFORM_NOISE Add reproducible receiver-waveform equivalent noise.
%   It is deliberately not inferred from PSD, power, coupling loss, or NF.
    if nargin < 3 || isempty(spec), spec = cfg.noise; end
    if nargin < 4 || isempty(seed), seed = 1; end
    if ~isfield(spec,'kind'), spec.kind='none'; end
    y0=x(:).'; n=numel(y0); noise=zeros(1,n);
    if strcmp(spec.kind,'none') || isinf(spec.snr_db)
        y=y0; meta=struct('application_point','post-line receiver waveform','kind',spec.kind, ...
            'status','no equivalent noise added'); return;
    end
    prior=rng; cleanup=onCleanup(@() rng(prior)); rng(seed,'twister'); %#ok<NASGU>
    p=mean(abs(y0).^2); variance=p/10^(spec.snr_db/10);
    white=sqrt(variance/2)*(randn(1,n)+1i*randn(1,n));
    switch spec.kind
        case 'white_awgn', noise=white;
        case 'colored_gaussian'
            noise=filter(1,[1 -spec.color_alpha],white);
            noise=noise*sqrt(variance/max(mean(abs(noise).^2),realmin));
        case 'impulsive'
            bursts=rand(1,n)<spec.impulse_probability;
            impulses=sqrt(variance*spec.impulse_to_background_ratio/2)*(randn(1,n)+1i*randn(1,n));
            noise=white+bursts.*impulses;
        otherwise, error('stage3b_waveform_noise:InvalidKind','Unknown noise kind %s.',spec.kind);
    end
    y=y0+noise;
    meta=struct('application_point','after line convolution/sync; before receiver FFT', ...
        'kind',spec.kind,'requested_snr_db',spec.snr_db,'seed',seed, ...
        'status','receiver-waveform equivalent noise; not calibrated PLC hardware noise');
end
