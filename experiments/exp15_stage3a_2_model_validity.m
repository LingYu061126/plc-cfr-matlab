function result = exp15_stage3a_2_model_validity(root)
%EXP15_STAGE3A_2_MODEL_VALIDITY Audit CP and linear/circular sampled CFR.
%   The same active CFR is used for both channel modes. The circular mode is
%   the existing Stage-3A baseline. The linear mode convolves the transmitted
%   CP frame with the finite sampled-CFR impulse response and truncates only
%   at the receiver frame boundary. Neither mode is a calibrated physical
%   PLC time-domain channel.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    s3=stage3a_config(root);base=s3.base_config;ensure_result_dirs(base);
    started=tic;seed=s3.random_seed+73000;
    candidates=topology_candidates(base);candidate=candidates(s3.candidate_indices(1));
    f=s3.ofdm.active_frequency_hz(:).';
    [views,~]=stage3a_compute_observations(f,candidate,base,struct(),'siso_forward');
    H_active=views{1};H_full=zeros(1,s3.ofdm.nfft);
    H_full(s3.ofdm.active_bin_1based)=H_active;h=ifft(H_full,s3.ofdm.nfft);
    cp_values=[0,64,128,256,512,1024];threshold_db=-40;
    row_template=struct('mode','stage3a_2','topology_id',candidate.id,'cp_samples',0, ...
        'nfft',s3.ofdm.nfft,'sample_rate_hz',s3.ofdm.sample_rate_hz, ...
        'frequency_start_hz',f(1),'frequency_end_hz',f(end),'frequency_count',numel(f), ...
        'threshold_db',threshold_db,'physical_delay_support_samples',NaN, ...
        'physical_delay_support_s',NaN,'physical_delay_available',false, ...
        'energy_99_support_samples',NaN,'threshold_support_samples',NaN, ...
        'cp_energy_fraction',NaN,'cp_covers_threshold_support',false, ...
        'linear_circular_max_abs',NaN,'linear_circular_rms',NaN, ...
        'linear_circular_relative_rms',NaN,'linear_tail_samples',0, ...
        'circular_output_samples',0,'linear_output_samples',0,'seed',seed,'runtime_s',NaN);
    rows=repmat(row_template,0,1);
    for cp=cp_values
        cfg=s3.ofdm;cfg.cyclic_prefix_samples=cp;
        symbol=stage3a_generate_symbol(cfg,1,seed);
        [~,dc]=stage3a_apply_ofdm_channel(symbol,H_active,cfg, ...
            struct('kind','none','snr_db',Inf),struct('channel_mode','circular_sampled_cfr'),seed);
        [~,dl]=stage3a_apply_ofdm_channel(symbol,H_active,cfg, ...
            struct('kind','none','snr_db',Inf),struct('channel_mode','linear_sampled_cfr'),seed);
        diff=dl.ideal_frame-dc.ideal_frame;
        rms=sqrt(mean(abs(diff).^2));ref=sqrt(mean(abs(dc.ideal_frame).^2));
        coverage=stage3a_cp_coverage(h,cp,threshold_db);
        rec=row_template;rec.cp_samples=cp;
        rec.physical_delay_support_samples=coverage.physical_delay_support_samples;
        rec.physical_delay_support_s=coverage.physical_delay_support_s;
        rec.physical_delay_available=coverage.physical_delay_available;
        rec.energy_99_support_samples=coverage.energy_99_support_samples;
        rec.threshold_support_samples=coverage.threshold_support_samples;
        rec.cp_energy_fraction=coverage.energy_fraction;
        rec.cp_covers_threshold_support=coverage.covered;
        rec.linear_circular_max_abs=max(abs(diff));rec.linear_circular_rms=rms;
        rec.linear_circular_relative_rms=rms/max(ref,realmin);
        rec.linear_tail_samples=dl.linear_tail_samples;
        rec.circular_output_samples=numel(dc.ideal_frame);rec.linear_output_samples=numel(dl.ideal_frame);
        rec.runtime_s=toc(started);rows(end+1)=rec; %#ok<AGROW>
    end
    prefix='stage3a_2_model_validity';
    writetable(struct2table(rows),fullfile(base.results_data,[prefix '_cp_metrics.csv']));
    example=table(f(:),real(H_active(:)),imag(H_active(:)), ...
        'VariableNames',{'frequency_hz','H_true_real','H_true_imag'});
    writetable(example,fullfile(base.results_data,[prefix '_example_cfr.csv']));
    impulse=table((0:s3.ofdm.nfft-1).',real(h(:)),imag(h(:)), ...
        'VariableNames',{'sample_index','h_sampled_real','h_sampled_imag'});
    writetable(impulse,fullfile(base.results_data,[prefix '_sampled_impulse.csv']));
    config=table({'stage3a_2';'stage3a_2';'stage3a_2'}, ...
        {'circular_sampled_cfr';'linear_sampled_cfr';'cp_coverage'}, ...
        [s3.ofdm.nfft;s3.ofdm.nfft;s3.ofdm.nfft], ...
        [s3.ofdm.sample_rate_hz;s3.ofdm.sample_rate_hz;s3.ofdm.sample_rate_hz], ...
        [s3.ofdm.cyclic_prefix_samples;s3.ofdm.cyclic_prefix_samples;s3.ofdm.cyclic_prefix_samples], ...
        [seed;seed;seed], ...
        'VariableNames',{'mode','component','nfft','sample_rate_hz','baseline_cp_samples','random_seed'});
    writetable(config,fullfile(base.results_data,[prefix '_config.csv']));
    save(fullfile(base.results_data,[prefix '_raw.mat']),'rows','example','config','f','H_active','H_full','h','candidate','-v7');
    figure('Visible','off');
    subplot(2,1,1);semilogy([rows.cp_samples],[rows.linear_circular_relative_rms],'-o');grid on;
    xlabel('CP samples');ylabel('linear/circular relative RMS');title('Stage 3A.2 sampled-CFR convolution audit');
    subplot(2,1,2);plot([rows.cp_samples],[rows.cp_energy_fraction],'-o','DisplayName','CP energy fraction');hold on;
    plot([rows.cp_samples],[rows.threshold_support_samples],'--s','DisplayName','threshold support');
    plot([rows.cp_samples],[rows.energy_99_support_samples],'-.d','DisplayName','99% energy support');
    grid on;legend('Location','best');xlabel('CP samples');ylabel('samples / fraction');
    print(gcf,fullfile(base.results_figures,[prefix '_cp_audit.png']),'-dpng','-r120');close(gcf);
    result=struct('mode',prefix,'rows',numel(rows),'elapsed_s',toc(started), ...
        'baseline_cp',s3.ofdm.cyclic_prefix_samples,'topology_id',candidate.id);
    fprintf('EXP15 Stage 3A.2 model validity completed: rows=%d elapsed=%.3f s\n', ...
        result.rows,result.elapsed_s);
end
