function cfg = ofdm_config()
%OFDM_CONFIG Configuration for the stage-2 OFDM-equivalent measurement model.
%   This is a complex-baseband frequency-domain model, not a complete
%   transmitter/receiver. Frequencies are Hz. The default uses all active
%   subcarriers as known pilots so that channel-estimation error can be
%   isolated before any pilot interpolation or waveform optimization.

    cfg = struct();
    cfg.nfft = 4096;
    cfg.sample_rate_hz = 64e6;
    cfg.subcarrier_spacing_hz = cfg.sample_rate_hz / cfg.nfft;
    cfg.frequency_band_hz = [2e6, 30e6];
    cfg.pilot_spacing = 1;
    cfg.pilot_mode = 'all_active_known_qpsk';
    cfg.pilot_seed = 20260819;
    cfg.cyclic_prefix_samples = 0; % not used by this frequency-domain baseline

    first_sc = ceil(cfg.frequency_band_hz(1) / cfg.subcarrier_spacing_hz);
    last_sc = floor(cfg.frequency_band_hz(2) / cfg.subcarrier_spacing_hz);
    cfg.active_subcarrier_zero_based = first_sc:last_sc;
    cfg.active_bin_1based = cfg.active_subcarrier_zero_based + 1;
    cfg.active_frequency_hz = cfg.active_subcarrier_zero_based * ...
        cfg.subcarrier_spacing_hz;
    cfg.pilot_active_index = 1:cfg.pilot_spacing:numel( ...
        cfg.active_subcarrier_zero_based);
    cfg.pilot_subcarrier_zero_based = cfg.active_subcarrier_zero_based( ...
        cfg.pilot_active_index);
    cfg.pilot_bin_1based = cfg.pilot_subcarrier_zero_based + 1;
    cfg.pilot_frequency_hz = cfg.pilot_subcarrier_zero_based * ...
        cfg.subcarrier_spacing_hz;
    cfg.num_active_subcarriers = numel(cfg.active_subcarrier_zero_based);
    cfg.num_pilots = numel(cfg.pilot_active_index);
    cfg.note = ['仿真基线假设：项目中未发现原有通信型OFDM波形代码，' ...
        '因此采用复基带全导频等效模型；参数待与实际波形确认。'];
end
