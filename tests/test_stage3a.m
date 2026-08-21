function test_stage3a()
%TEST_STAGE3A Tests for the communication-OFDM Stage-3A wrapper.
    root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    s3=stage3a_config(root); base=s3.base_config; candidates=topology_candidates(base);
    f=s3.ofdm.active_frequency_hz; full_cfg=s3.ofdm;full_cfg.pilot_bin_1based=full_cfg.active_bin_1based;
    symbol=stage3a_generate_symbol(s3.ofdm,1,17);
    H=exp(-1i*2*pi*(0:numel(f)-1)/numel(f)*0.01);
    [rx,d]=stage3a_apply_ofdm_channel(symbol,H,s3.ofdm,struct('kind','none','snr_db',Inf),struct(),7); %#ok<ASGLU>
    [~,Hhat,~]=stage3a_receive_ofdm(rx,symbol,s3.ofdm,struct());
    assert(max(abs(Hhat-H))<1e-12,'Dense CP/FFT/LS chain failed.');
    fprintf('  PASS Stage3A dense OFDM CP/FFT/LS noiseless chain\n');
    sparse=stage3a_generate_symbol(s3.ofdm,4,17);
    [rx,~]=stage3a_apply_ofdm_channel(sparse,H,s3.ofdm,struct('kind','white_awgn','snr_db',20),struct(),8);
    [Hp,Hi,~]=stage3a_receive_ofdm(rx,sparse,s3.ofdm,struct());
    assert(numel(Hp)==numel(sparse.pilot_bin_1based)&&numel(Hi)==numel(f)&&all(isfinite(Hi)), ...
        'Sparse interpolation dimensions/nonfinite output failed.');
    fprintf('  PASS Stage3A sparse-pilot interpolation dimensions and finite output\n');
    kinds={'none','white_awgn','colored_gaussian','impulsive'};
    for k=1:numel(kinds)
        [n1,d1]=stage3a_apply_ofdm_channel(symbol,H,s3.ofdm,struct('kind',kinds{k},'snr_db',20),struct(),100+k); %#ok<ASGLU>
        [n2,d2]=stage3a_apply_ofdm_channel(symbol,H,s3.ofdm,struct('kind',kinds{k},'snr_db',20),struct(),100+k); %#ok<ASGLU>
        assert(all(isfinite(n1))&&max(abs(n1-n2))==0&&isfinite(d1.noise_details.actual_noise_power), ...
            'Noise mode %s is not finite/repeatable.',kinds{k});
    end
    fprintf('  PASS Stage3A white/colored/impulsive noise repeatability\n');
    [~,~,~]=stage3a_receive_ofdm(rx,sparse,s3.ofdm,struct('timing_offset_samples',2, ...
        'sample_clock_offset_ppm',50));
    fprintf('  PASS Stage3A timing and sample-clock impairment interface\n');
    info1=stage3a_observation_config('siso_forward');info2=stage3a_observation_config('fdr_tfdr_reflection_proxy');
    info3=stage3a_observation_config('input_admittance_proxy');
    info4=stage3a_observation_config('dual_receiver_highz_complete');
    assert(strcmp(info1.O,'ordinary_ofdm_cfr')&&info2.is_proxy&&info3.is_proxy&& ...
        info4.view_count==2&&~info4.is_proxy&& ...
        ~strcmp(info1.physical_quantity,info2.physical_quantity), ...
        'Observation O labels conflate ordinary CFR and proxy observables.');
    fprintf('  PASS Stage3A observation O labels separate CFR/FDR/input-admittance proxies\n');
    [loaded_views,~]=stage3a_compute_observations(f,candidates(2),base,struct(),'dual_receiver_complete');
    [highz_views,~]=stage3a_compute_observations(f,candidates(2),base,struct(),'dual_receiver_highz_complete');
    assert(numel(loaded_views)==2&&numel(highz_views)==2&& ...
        max(abs(loaded_views{2}-highz_views{2}))>1e-12, ...
        'High-impedance receiver did not produce a distinct complete-network view.');
    [theta_grid,bounds]=stage3a_parameter_grid(base,s3); %#ok<ASGLU>
    assert(numel(theta_grid)>=15&&theta_grid(1).regularization==0&& ...
        isfield(theta_grid,'R_scale')&&isfield(bounds,'source_impedance_ohm'), ...
        'Stage3A.1 bounded nuisance-parameter grid is incomplete.');
    fprintf('  PASS Stage3A.1 high-Z receiver and bounded parameter grid interfaces\n');
    theta=struct('R_scale',1.02,'L_scale',0.98,'G_scale',1.01,'C_scale',0.99, ...
        'source_impedance_ohm',50*1.02,'receiver_impedance_ohm',50/1.02, ...
        'coupler_gain',0.98*exp(1i*pi/36));
    [net,cfg2,~]=stage3a_apply_parameters(candidates(2).network,base,theta); %#ok<ASGLU>
    [views,meta]=stage3a_compute_observations(f,candidates(2),base,theta,'siso_forward'); %#ok<ASGLU>
    [nominal_views,~]=stage3a_compute_observations(f,candidates(2),base,struct(),'siso_forward');
    assert(isfield(net,'rlgc_scale')&&cfg2.Zs~=base.Zs&&meta.network_complete&&numel(views)==1&& ...
        all(isfinite(views{1}))&&max(abs(views{1}-nominal_views{1}))>1e-9, ...
        'Stage3A RLGC perturbation/complete-network observation failed.');
    fprintf('  PASS Stage3A explicit RLGC perturbation uses complete network\n');
    refs=cell(1,4);for k=1:4,[refs{k},~]=stage3a_compute_observations(f,candidates(k+1),base,struct(),'siso_forward');end
    audit=topology_observability_classes(refs,candidates(2:5),full_cfg,1e-10);
    assert(any(audit.class_sizes==2),'Stage3A SISO T3/T5 equivalence class missing.');
    refs3=cell(1,4);for k=1:4,[refs3{k},~]=stage3a_compute_observations(f,candidates(k+1),base,struct(),'three_view_complete');end
    audit3=topology_observability_classes(refs3,candidates(2:5),full_cfg,1e-10);
    assert(all(audit3.class_sizes==1),'Stage3A complete three-view class should be singleton in this model.');
    fprintf('  PASS Stage3A SISO equivalence and complete multiview observability audit\n');
    [dly,dd]=stage3a_toa_feature(H,full_cfg);assert(isfinite(dly)&&~dd.is_physical_toa, ...
        'Circular delay proxy metadata failed.');
    fprintf('  PASS Stage3A circular delay is explicitly nonphysical ToA\n');
    Hfull=zeros(1,s3.ofdm.nfft);Hfull(s3.ofdm.active_bin_1based)=H;
    h=ifft(Hfull,s3.ofdm.nfft);
    y_explicit=stage3a_explicit_circular_convolution(symbol.payload,h);
    [~,channel_details]=stage3a_apply_ofdm_channel(symbol,H,s3.ofdm, ...
        struct('kind','none','snr_db',Inf),struct(),7);
    explicit_frame=[y_explicit(end-symbol.cyclic_prefix_samples+1:end),y_explicit];
    assert(max(abs(explicit_frame-channel_details.ideal_frame))<1e-10, ...
        'Explicit circular time-domain convolution does not match CFR filtering.');
    cp_audit=stage3a_cp_coverage(h,s3.ofdm.cyclic_prefix_samples,-40);
    assert(isfinite(cp_audit.energy_fraction)&&~cp_audit.is_physical_delay, ...
        'CP coverage audit returned invalid physical-delay metadata.');
    fprintf('  PASS explicit circular convolution equivalence (max %.3g, CP coverage %.3f, threshold support %d samples)\n', ...
        max(abs(explicit_frame-channel_details.ideal_frame)),cp_audit.energy_fraction,cp_audit.effective_delay_samples);
    fprintf('ALL STAGE-3A TESTS PASSED\n');
end
