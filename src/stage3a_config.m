function cfg = stage3a_config(root_dir)
%STAGE3A_CONFIG Configuration for the communication-OFDM awareness baseline.
%   Frequencies are Hz, time is s, lengths are m, and RLGC values are SI.
%   This is a new configuration layer; it does not alter the stage-1.5/2
%   configurations or their saved results.
    if nargin < 1 || isempty(root_dir)
        root_dir = fileparts(fileparts(mfilename('fullpath')));
    end
    base = default_config(root_dir);
    ofdm = base.ofdm;
    ofdm.cyclic_prefix_samples = 256;
    ofdm.pilot_spacings = [1, 4];
    ofdm.full_grid_bin_1based = ofdm.active_bin_1based;
    ofdm.full_grid_frequency_hz = ofdm.active_frequency_hz;
    ofdm.full_grid_count = numel(ofdm.active_bin_1based);
    cfg = struct();
    cfg.root_dir = root_dir;
    cfg.base_config = base;
    cfg.ofdm = ofdm;
    cfg.random_seed = 20260821;
    cfg.candidate_indices = [2, 3, 4, 5];
    cfg.measurement_kinds = {'siso_forward','bidirectional_endpoint_fixed', ...
        'dual_receiver_complete','three_view_complete'};
    cfg.audit_measurement_kinds = {'siso_forward','bidirectional_endpoint_fixed', ...
        'dual_receiver_complete','dual_receiver_highz_complete','three_view_complete'};
    cfg.observation_modes = {'ordinary_ofdm_cfr','fdr_tfdr_reflection_proxy', ...
        'input_admittance_proxy'};
    cfg.features = {'amplitude','amp_phase_joint_weighted','cir','toa'};
    cfg.input_modes = {'ideal_true_cfr','ofdm_dense_ls','ofdm_sparse_interp'};
    cfg.noise_kinds = {'none','white_awgn','colored_gaussian','impulsive'};
    cfg.snr_db = [Inf, 20, 10, 0];
    cfg.cp_timing_offsets_samples = [0, 2];
    cfg.sample_clock_offsets_ppm = [0, 50];
    cfg.pilot_phase_rotations_rad = [0, pi/12];
    cfg.load_scales = [0.8, 1.2];
    cfg.length_error_scales = [0.98, 1.02];
    cfg.rlgc_error_scales = [0.98, 1.02];
    cfg.coupler_amplitude_scales = [0.98, 1.02];
    cfg.coupler_phase_errors_rad = [0, pi/36];
    cfg.impulsive_burst_length_samples = 8;
    cfg.impulsive_burst_factor = 100;
    cfg.colored_noise_tilt = 0.8;
    cfg.formal_trials_per_case = 2;
    cfg.smoke_trials_per_case = 1;
    cfg.audit_trials_per_condition = 50;
    cfg.audit_snr_db = [5,10,15,20,30];
    cfg.audit_pilot_spacings = [1,2,4,8];
    cfg.audit_noise_kind = 'white_awgn';
    cfg.audit_parameter_trials = 20;
    cfg.audit_parameter_snr_db = 20;
    cfg.audit_parameter_feature = 'amp_phase_joint_weighted';
    cfg.audit_parameter_lambda = 0.01;
    cfg.audit_parameter_scales = struct('main_length',[0.98,1,1.02], ...
        'branch_length',[0.98,1,1.02],'branch_load',[0.90,1,1.10], ...
        'rlgc',[0.98,1,1.02],'source_impedance',[49,50,51], ...
        'receiver_impedance',[49,50,51],'coupler_amplitude',[0.98,1,1.02], ...
        'coupler_phase',[0,-pi/36,pi/36]);
    cfg.tie_tolerance = 1e-10;
    cfg.results_data = fullfile(root_dir,'results','data');
    cfg.results_figures = fullfile(root_dir,'results','figures');
    cfg.results_logs = fullfile(root_dir,'results','logs');
    cfg.note = ['Stage 3A is a communication-OFDM baseline with IFFT/CP ' ...
        'and equivalent complete-network propagation; it is not a field modem.'];
end
