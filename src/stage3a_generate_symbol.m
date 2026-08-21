function symbol = stage3a_generate_symbol(ofdm_cfg,pilot_spacing,seed)
%STAGE3A_GENERATE_SYMBOL Make one complex-baseband OFDM pilot symbol.
%   X_full is an NFFT row vector with known QPSK pilots on the selected
%   active bins. The returned tx_frame contains a cyclic prefix followed by
%   the IFFT payload. No global RNG state is changed.
    if nargin < 2 || isempty(pilot_spacing), pilot_spacing=1; end
    if nargin < 3 || isempty(seed), seed=ofdm_cfg.pilot_seed; end
    if ~(isscalar(pilot_spacing)&&isreal(pilot_spacing)&&isfinite(pilot_spacing)&& ...
            pilot_spacing==fix(pilot_spacing)&&pilot_spacing>=1)
        error('stage3a_generate_symbol:InvalidPilotSpacing', ...
            'pilot_spacing must be a positive integer.');
    end
    active = ofdm_cfg.active_bin_1based(:).';
    selected = active(1:pilot_spacing:end);
    if isempty(selected), error('stage3a_generate_symbol:EmptyPilots', ...
            'Pilot spacing leaves no active pilots.'); end
    q = mod((0:numel(selected)-1)+double(seed),4);
    X = exp(1i*(pi/4+q*pi/2));
    X_full = zeros(1,ofdm_cfg.nfft);
    X_full(selected)=X;
    payload = ifft(X_full,ofdm_cfg.nfft);
    cp = ofdm_cfg.cyclic_prefix_samples;
    if ~(isscalar(cp)&&isreal(cp)&&isfinite(cp)&&cp==fix(cp)&&cp>=0&&cp<ofdm_cfg.nfft)
        error('stage3a_generate_symbol:InvalidCP','Invalid cyclic prefix length.');
    end
    if cp==0, prefix=zeros(1,0); else, prefix=payload(end-cp+1:end); end
    symbol = struct('X_pilot',X,'X_full',X_full,'pilot_bin_1based',selected, ...
        'pilot_frequency_hz',ofdm_cfg.sample_rate_hz*(selected-1)/ofdm_cfg.nfft, ...
        'active_bin_1based',active,'payload',payload,'tx_frame',[prefix,payload], ...
        'cyclic_prefix_samples',cp,'pilot_spacing',pilot_spacing,'seed',seed, ...
        'nfft',ofdm_cfg.nfft,'sample_rate_hz',ofdm_cfg.sample_rate_hz);
end
