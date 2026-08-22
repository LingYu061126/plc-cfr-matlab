function [cfg_nb, cfg_bb, meta] = stage3_band_configs(root_dir)
%STAGE3_BAND_CONFIGS Design-only narrowband and broadband configurations.
%   [CFG_NB, CFG_BB, META] = STAGE3_BAND_CONFIGS(ROOT_DIR) returns two
%   frequency-band configurations that share the existing H(f;G,theta)
%   network interface.  This function does not modify DEFAULT_CONFIG and
%   does not run a dual-band experiment.
%
%   Frequencies are Hz, sampling rates are Hz, CP lengths are samples, and
%   all line lengths/RLGC values remain in the units used by the existing
%   stage-1.5 model.  The NB configuration deliberately contains NaN for
%   PHY values that cannot be established from the local literature alone.
%   A caller must validate and replace those fields before numerical use.

    if nargin < 1 || isempty(root_dir)
        root_dir = fileparts(fileparts(mfilename('fullpath')));
    end
    if ~(ischar(root_dir) || (isstring(root_dir) && isscalar(root_dir)))
        error('stage3_band_configs:InvalidRoot', ...
            'root_dir must be a character vector or scalar string.');
    end
    root_dir = char(root_dir);

    base = default_config(root_dir);
    base_ofdm = base.ofdm;

    common = struct();
    common.root_dir = root_dir;
    common.model_equation = 'H(f;G,theta)';
    common.communication_equation = ...
        'Y_rt[k] = X_t[k] H_rt(k;G,theta) + N_rt[k]';
    common.estimate_equation = 'H_hat_rt[k] = Y_rt[k] / X_t[k]';
    common.observation_types = {'ordinary_ofdm_cfr', ...
        'cir_or_circular_band_limited_cir', 'toa_or_group_delay_proxy', ...
        'input_impedance_or_reflection', 'node_admittance', ...
        'multi_node_or_multi_port_channel_matrix'};
    common.shared_network_interface = {'topology_candidates', ...
        'cascade_network_stable', 'branch_input_impedance', ...
        'plc_full_network_response', 'topology_feature_distance'};
    common.parameter_vector = {'line_length_m','Rprime_ohm_per_m', ...
        'Lprime_H_per_m','Gprime_S_per_m','Cprime_F_per_m', ...
        'load_impedance_ohm','source_impedance_ohm', ...
        'receiver_impedance_ohm','coupler_parameters'};
    common.noise_status = 'candidate PSD/noise models are simulation assumptions; no field calibration';
    common.coupler_status = 'not a measured coupler model; keep as an explicit future parameter';
    common.load_status = 'scalar, complex, vector and parallel-RLC interfaces exist; field spectra are unavailable';
    common.rlgc_status = ['The current project implementation and its validated ' ...
        'baseline are 2--30 MHz. Outside that range is parameter extrapolation ' ...
        'until RLGC data are independently checked.'];
    common.default_result_policy = ...
        'Do not overwrite stage-1.5--3A.2 results; save dual-band outputs with a new prefix.';

    cfg_nb = common;
    cfg_nb.name = 'NB_candidate_42_472_kHz';
    cfg_nb.band_kind = 'narrowband_candidate';
    cfg_nb.frequency_band_hz = [42e3, 472e3];
    cfg_nb.frequency_grid_hz = [];
    cfg_nb.frequency_spacing_hz = NaN;
    cfg_nb.fs_hz = NaN;
    cfg_nb.nfft = NaN;
    cfg_nb.cp_samples = NaN;
    cfg_nb.active_subcarrier_rule = '待与实际 NB-PLC PHY 确认';
    cfg_nb.pilot_rule = '待与实际 NB-PLC PHY 确认；不得假定全导频';
    cfg_nb.psd_rule = '待确认；当前仅记录候选频带，不代表标准 PSD';
    cfg_nb.noise_psd_rule = '待确认；应允许有色/窄带/脉冲噪声';
    cfg_nb.load_frequency_model = 'use existing load interface; frequency law not field-calibrated';
    cfg_nb.reference_basis = {'project_design_candidate_below_500_kHz', ...
        'P1 local review compares 42--472 kHz NB-PLC conditions', ...
        'not a claim that this is the project modem standard'};
    cfg_nb.status = 'design_only_protocol_and_sampling_parameters_required';
    cfg_nb.extension_note = ['NB frequency endpoints are a controlled research ' ...
        'candidate. They are not sufficient to instantiate OFDM without a confirmed PHY.'];
    cfg_nb.validation = struct('frequency_grid_valid', false, ...
        'subcarrier_spacing_consistent', false, ...
        'active_subcarriers_in_band', false, ...
        'physical_delay_available', false, ...
        'cp_coverage_evaluable', false, ...
        'ready_for_dual_band_experiment', false, ...
        'reason', 'NB PHY grid, CP and physical delay are not confirmed');

    cfg_bb = common;
    cfg_bb.name = 'BB_project_2_30_MHz';
    cfg_bb.band_kind = 'broadband_project_baseline';
    cfg_bb.frequency_band_hz = base_ofdm.frequency_band_hz;
    cfg_bb.frequency_grid_hz = base_ofdm.active_frequency_hz;
    cfg_bb.frequency_spacing_hz = base_ofdm.subcarrier_spacing_hz;
    cfg_bb.fs_hz = base_ofdm.sample_rate_hz;
    cfg_bb.nfft = base_ofdm.nfft;
    cfg_bb.cp_samples = 256;
    cfg_bb.active_subcarrier_rule = 'existing project active bins in 2--30 MHz';
    cfg_bb.pilot_rule = 'existing project all-active baseline; sparse spacing is audit-only';
    cfg_bb.pilot_spacings = [1, 2, 4, 8];
    cfg_bb.psd_rule = 'equal-energy/equivalent-pilot simulation assumption; not a standard PSD mask';
    cfg_bb.noise_psd_rule = 'white baseline plus existing colored/impulsive interfaces';
    cfg_bb.load_frequency_model = 'existing scalar/complex/vector/parallel-RLC interfaces';
    cfg_bb.reference_basis = {'current_project_simulation_assumption_2_30_MHz', ...
        'P8 discusses 1.1--30 MHz and 30--86 MHz separately in standard-specific context', ...
        'not a claim that Fs=64 MHz/NFFT=4096/CP=256 is a standard profile'};
    cfg_bb.extension_band_hz = [30e6, 86e6];
    cfg_bb.extension_status = ['design extension only; current RLGC, Fs, PSD, ' ...
        'outdoor attenuation and coupler validity must be checked before running'];
    cfg_bb.status = 'project_baseline_assumption_not_standard_parameter_set';
    cfg_bb.validation = struct();
    cfg_bb.validation.frequency_grid_valid = all(isfinite(cfg_bb.frequency_grid_hz)) && ...
        all(diff(cfg_bb.frequency_grid_hz) > 0) && ...
        all(cfg_bb.frequency_grid_hz >= cfg_bb.frequency_band_hz(1)) && ...
        all(cfg_bb.frequency_grid_hz <= cfg_bb.frequency_band_hz(2));
    cfg_bb.validation.subcarrier_spacing_consistent = ...
        abs(cfg_bb.fs_hz/cfg_bb.nfft - cfg_bb.frequency_spacing_hz) <= ...
        10*eps(cfg_bb.frequency_spacing_hz);
    cfg_bb.validation.active_subcarriers_in_band = ...
        cfg_bb.validation.frequency_grid_valid;
    cfg_bb.validation.physical_delay_available = false;
    cfg_bb.validation.max_physical_path_delay_s = NaN;
    cfg_bb.validation.cp_coverage_evaluable = false;
    cfg_bb.validation.ready_for_dual_band_experiment = false;
    cfg_bb.validation.reason = ['Sampled CFR has no physical time origin; ' ...
        'CP versus maximum path delay must be audited after a physical channel ' ...
        'time reference is supplied.'];

    meta = struct();
    meta.generated_by = mfilename;
    meta.shared_model = common.model_equation;
    meta.nb_requires_protocol_confirmation = true;
    meta.bb_is_existing_project_assumption = true;
    meta.no_numerical_experiment_run = true;
    meta.notes = ['This configuration layer is intentionally separate from ' ...
        'default_config and stage3a_config.'];
end
