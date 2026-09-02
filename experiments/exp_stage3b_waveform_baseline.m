function result = exp_stage3b_waveform_baseline(root_dir)
%EXP_STAGE3B_WAVEFORM_BASELINE Run isolated waveform closure diagnostics.
%   Outputs only stage3b_waveform_* files.  This is not a PHY conformance,
%   hardware measurement, nor a topology-identification performance claim.
    if nargin<1 || isempty(root_dir), root_dir=fileparts(fileparts(mfilename('fullpath'))); end
    addpath(fullfile(root_dir,'src')); addpath(fullfile(root_dir,'config'));
    cfg=stage3b_waveform_config(root_dir);
    ensure_dir(cfg.output.data_dir); ensure_dir(cfg.output.figure_dir);
    tx=stage3b_waveform_tx(cfg,1,17);
    h=[1 0.25-0.1i -0.05+0.03i]; Hfull=fft(h,cfg.nfft); Hpos=Hfull(cfg.carrier.positive_bins);
    cases={ ...
        'clean',struct(),struct('kind','none','snr_db',Inf); ...
        'integer_timing_2',struct('integer_timing_offset_samples',2),struct('kind','none','snr_db',Inf); ...
        'cfo_5kHz',struct('cfo_hz',5000),struct('kind','none','snr_db',Inf); ...
        'sco_100ppm',struct('sco_ppm',100),struct('kind','none','snr_db',Inf); ...
        'colored_20dB',struct(),noise_cfg(cfg,'colored_gaussian',20); ...
        'impulsive_20dB',struct(),noise_cfg(cfg,'impulsive',20)};
    case_name=cell(size(cases,1),1); cfr_nmse=zeros(size(cases,1),1); cp_covered=false(size(cases,1),1);
    for k=1:size(cases,1)
        ch=stage3b_waveform_channel(tx,Hpos,cfg,cases{k,2},cases{k,3},100+k,h);
        rx=stage3b_waveform_rx(ch.rx_waveform,tx,cfg,Hpos);
        case_name{k}=cases{k,1}; cfr_nmse(k)=rx.cfr_nmse; cp_covered(k)=ch.cp_audit.mathematically_covered;
    end
    closure=table(case_name,cfr_nmse,cp_covered,'VariableNames',{'case_name','cfr_nmse','cp_mathematically_covered'});
    writetable(closure,fullfile(cfg.output.data_dir,'stage3b_waveform_cfr_closure.csv'));

    % Network-CFR IFFT diagnostic: it deliberately reports CP support and
    % does not convert the result to topology accuracy or physical ToA.
    base=cfg.base_network_config; candidates=topology_candidates(base);
    candidates=candidates(cfg.topology.candidate_indices);
    refs=topology_reference_cfr(cfg.carrier.positive_frequency_hz,candidates,base);
    n=numel(refs); ids=cell(n,1); nmse=zeros(n,1); covered=false(n,1); support=zeros(n,1);
    views=cell(1,n);
    for k=1:n
        ch=stage3b_waveform_channel(tx,refs(k).reference_H,cfg,struct(),struct('kind','none','snr_db',Inf),200+k);
        rx=stage3b_waveform_rx(ch.rx_waveform,tx,cfg,ch.H_positive_effective);
        ids{k}=refs(k).id; nmse(k)=rx.cfr_nmse; covered(k)=ch.cp_audit.mathematically_covered;
        support(k)=ch.cp_audit.effective_support_samples; views{k}={refs(k).reference_H};
    end
    network_diag=table(ids,nmse,covered,support,'VariableNames', ...
        {'topology_id','sampled_cfr_waveform_nmse','cp_mathematically_covered','effective_support_samples'});
    writetable(network_diag,fullfile(cfg.output.data_dir,'stage3b_waveform_network_sampled_cfr_diagnostic.csv'));
    audit=topology_observability_classes(views,refs,struct(),cfg.topology.tie_tolerance);
    class_label=audit.class_labels(:); class_size=audit.class_sizes(audit.class_index(:)).';
    equiv=table(ids,class_label,class_size,'VariableNames',{'topology_id','siso_equivalence_class','class_size'});
    writetable(equiv,fullfile(cfg.output.data_dir,'stage3b_waveform_t3_t5_equivalence.csv'));

    fig=figure('Visible','off'); semilogy(1:height(closure),max(closure.cfr_nmse,realmin),'o-','LineWidth',1.2);
    grid on; xticks(1:height(closure)); xticklabels(closure.case_name); xtickangle(25);
    ylabel('known-training CFR NMSE'); title('Stage 3B waveform abstract closure/impairment diagnostic');
    exportgraphics(fig,fullfile(cfg.output.figure_dir,'stage3b_waveform_cfr_nmse.png'),'Resolution',160); close(fig);
    result=struct('config',cfg,'closure',closure,'network_diagnostic',network_diag, ...
        'equivalence',equiv,'audit',audit,'status',['abstract waveform-level model; ' ...
        'not hardware PHY or topology-identification validation']);
    save(fullfile(cfg.output.data_dir,'stage3b_waveform_baseline_result.mat'),'result','-v7');
end

function n=noise_cfg(cfg,kind,snr)
    n=cfg.noise; n.kind=kind; n.snr_db=snr;
end
function ensure_dir(p), if ~exist(p,'dir'), mkdir(p); end, end
