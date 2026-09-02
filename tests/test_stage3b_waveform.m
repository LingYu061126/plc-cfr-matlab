function test_stage3b_waveform()
%TEST_STAGE3B_WAVEFORM Isolated mathematical tests for waveform baseline.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src')); addpath(fullfile(root,'config'));
    cfg=stage3b_waveform_config(root); legacy_before=default_config(root);
    assert(cfg.nfft==4096 && cfg.fs_hz==100e6 && abs(cfg.delta_f_hz-24414.0625)<eps, ...
        'Standard-derived grid is wrong.');
    assert(cfg.gi.ncp_samples==1536 && cfg.gi.ncp_samples~=256, ...
        'Stage-3A CP must not be reused.');
    assert(isequal(legacy_before,default_config(root)), 'Waveform config changed legacy configuration.');
    assert(numel(cfg.carrier.positive_bins)==1147 && ...
        all(cfg.carrier.positive_frequency_hz>=2e6 & cfg.carrier.positive_frequency_hz<=30e6), ...
        'Research carrier mask is wrong.');

    tx=stage3b_waveform_tx(cfg,1,11);
    assert(max(abs(imag(tx.payload)))==0 && max(abs(fft(tx.payload)-tx.X_full))<1e-10, ...
        'IFFT/FFT Hermitian closure failed.');
    assert(max(abs(tx.frame(cfg.gi.ncp_samples+1:end)-tx.payload_windowed))==0, ...
        'CP removal indexing is wrong.');
    assert(all(tx.X_full(~cfg.carrier.research_mask_full)==0), 'Mask leaked disabled carriers.');

    % A causal synthetic FIR supplies a valid mathematical CP test. It is
    % intentionally distinct from the sampled PLC CFR IFFT representation.
    h=[1 zeros(1,1022) 0.6];
    Hfull=fft(h,cfg.nfft); Hpos=Hfull(cfg.carrier.positive_bins);
    ch=stage3b_waveform_channel(tx,Hpos,cfg,struct(),struct('kind','none','snr_db',Inf),5,h);
    rx=stage3b_waveform_rx(ch.rx_waveform,tx,cfg,Hpos);
    assert(rx.cfr_nmse<1e-20 && ch.cp_audit.mathematically_covered, ...
        'Known training LS or sufficient-CP linear/circular equality failed.');
    cfg_short=cfg; cfg_short.gi.ncp_samples=1;
    tx_short=stage3b_waveform_tx(cfg_short,1,11);
    ch_short=stage3b_waveform_channel(tx_short,Hpos,cfg_short,struct(),struct('kind','none','snr_db',Inf),5,h);
    rx_short=stage3b_waveform_rx(ch_short.rx_waveform,tx_short,cfg_short,Hpos);
    assert(~ch_short.cp_audit.mathematically_covered && rx_short.cfr_nmse>1e-6, ...
        'Insufficient CP did not expose expected ISI/ICI.');

    % Each receiver impairment is independently observable at the nominal
    % CP/FFT receiver; no synchronizer is silently compensating it.
    clean=rx.H_positive_hat;
    specs={struct('integer_timing_offset_samples',2), ...
        struct('fractional_timing_offset_samples',0.25),struct('cfo_hz',5000), ...
        struct('sco_ppm',100),struct('phase_offset_rad',0.2)};
    for k=1:numel(specs)
        ci=stage3b_waveform_channel(tx,Hpos,cfg,specs{k},struct('kind','none','snr_db',Inf),10,h);
        ri=stage3b_waveform_rx(ci.rx_waveform,tx,cfg,Hpos);
        assert(norm(ri.H_positive_hat-clean)/max(norm(clean),realmin)>1e-6, ...
            'Declared synchronization impairment did not affect CFR.');
    end
    modes={'white_awgn','colored_gaussian','impulsive'};
    for k=1:numel(modes)
        ns=cfg.noise; ns.kind=modes{k}; ns.snr_db=20;
        [a,na]=stage3b_waveform_noise(ch.line_output,cfg,ns,99);
        [b,nb]=stage3b_waveform_noise(ch.line_output,cfg,ns,99);
        assert(isequal(a,b) && isequal(na,nb), 'Noise mode %s is not reproducible.',modes{k});
    end

    % Audit structural equivalence on the forward-model CFR, rather than
    % falsely interpreting sampled-IFFT support as physical timing evidence.
    candidates=topology_candidates(legacy_before); candidates=candidates(cfg.topology.candidate_indices);
    refs=topology_reference_cfr(cfg.carrier.positive_frequency_hz,candidates,legacy_before);
    views=cell(1,numel(refs)); for k=1:numel(refs), views{k}={refs(k).reference_H}; end
    audit=topology_observability_classes(views,refs,struct(),cfg.topology.tie_tolerance);
    ids={refs.id}; i3=find(strcmp(ids,'T3')); i5=find(strcmp(ids,'T5'));
    assert(audit.class_index(i3)==audit.class_index(i5) && any(audit.class_sizes>1), ...
        'T3/T5 SISO equivalence audit changed unexpectedly.');
    fprintf('  PASS Stage3B waveform isolated grid, waveform, CP, impairment and equivalence tests\n');
end
