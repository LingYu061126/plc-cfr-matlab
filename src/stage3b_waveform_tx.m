function tx = stage3b_waveform_tx(cfg, symbol_position, seed)
%STAGE3B_WAVEFORM_TX Build one abstract Hermitian OFDM training/data frame.
%   Separate masks are retained even though this baseline defaults to known
%   training on every study-window bin.  No standard preamble is asserted.

    if nargin < 2 || isempty(symbol_position), symbol_position = 1; end
    if nargin < 3 || isempty(seed), seed = 1; end
    is_training = ismember(symbol_position, cfg.frame.training_symbol_positions);
    if is_training
        mask = cfg.carrier.training_mask_positive;
        kind = 'training';
    else
        mask = cfg.carrier.data_mask_positive;
        kind = 'data';
    end
    bins = find(mask);
    if isempty(bins), error('stage3b_waveform_tx:EmptyMask','No enabled positive-frequency bins.'); end
    q = mod((0:numel(bins)-1) + seed + symbol_position - 2, 4);
    Xpos = exp(1i*(pi/4 + q*pi/2)); % deterministic unit-energy QPSK abstraction
    Xfull = zeros(1,cfg.nfft);
    Xfull(bins) = Xpos;
    Xfull(cfg.nfft-bins+2) = conj(Xpos);
    payload_complex = ifft(Xfull,cfg.nfft);
    if max(abs(imag(payload_complex))) > 1e-11
        error('stage3b_waveform_tx:HermitianFailure','Hermitian mapping did not produce a real waveform.');
    end
    payload = real(payload_complex);
    window = waveform_window(cfg.gi, cfg.nfft);
    payload_windowed = payload .* window;
    cp = payload_windowed(end-cfg.gi.ncp_samples+1:end);
    tx = struct('symbol_position',symbol_position,'kind',kind,'positive_bins',bins(:).', ...
        'X_positive',Xpos(:).','X_full',Xfull,'payload',payload,'window',window, ...
        'payload_windowed',payload_windowed,'cp',cp,'frame',[cp payload_windowed], ...
        'mapping_status',cfg.mapping.status,'training_pattern_status',cfg.frame.training_pattern_status);
end

function w = waveform_window(gi,n)
    w = ones(1,n);
    if ~gi.window_enabled, return; end
    if ~strcmp(gi.window_kind,'raised_cosine_diagnostic')
        error('stage3b_waveform_tx:InvalidWindow','Unsupported diagnostic window kind.');
    end
    m = min(gi.beta_samples, floor(n/2));
    edge = 0.5*(1-cos(pi*(1:m)/m));
    w(1:m) = edge;
    w(end-m+1:end) = fliplr(edge);
end
