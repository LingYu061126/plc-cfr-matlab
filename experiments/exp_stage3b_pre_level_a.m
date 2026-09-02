function result = exp_stage3b_pre_level_a(root_dir)
%EXP_STAGE3B_PRE_LEVEL_A Run isolated analytic NB/BB extrapolation diagnostic.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    cfg=stage3b_pre_config(root_dir);ensure_dirs(cfg);base=default_config(root_dir);
    all_candidates=topology_candidates(base);candidates=all_candidates(cfg.candidate_indices);
    rows=struct([]);r=0;
    for li=1:numel(cfg.levels)
        for bi={'BB','NB'}
            band=stage3b_pre_band_selector(bi{1},cfg.levels{li});placeholder=stage3b_pre_fair_sampling(band);
            for ci=1:numel(cfg.theta_cases)
                theta=theta_case(cfg.theta_cases{ci});
                for si=1:numel(cfg.snr_db)
                    out=stage3b_pre_level_a_match(band.frequency_hz,candidates,base,theta,cfg.snr_db(si), ...
                        cfg.random_seed+10000*li+1000*(bi{1}(1)=='N')+100*ci+si,cfg);
                    r=r+1; candidate_row=summarize(band,placeholder,cfg,theta,cfg.snr_db(si),out);
                    if r==1
                        rows=candidate_row;
                    else
                        assert(isequal(fieldnames(rows),fieldnames(candidate_row)), ...
                            'exp_stage3b_pre_level_a:SummarySchema','Summary row schema changed.');
                        rows(r)=orderfields(candidate_row,rows); %#ok<AGROW>
                    end
                end
            end
        end
    end
    T=struct2table(rows);writetable(T,fullfile(cfg.results_data,'stage3b_pre_summary.csv'));
    A=applicability_table();writetable(struct2table(A),fullfile(cfg.results_data,'stage3b_pre_applicability.csv'));
    make_figure(T,cfg.results_figures);save(fullfile(cfg.results_data,'stage3b_pre_results.mat'),'cfg','T','A','-v7');
    result=struct('config',cfg,'summary',T,'applicability',A);
    fprintf('Stage3B-pre analytic extrapolation diagnostic complete: %d summary rows.\n',height(T));
end

function theta=theta_case(name)
    theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'kG_scale',1);
    if strcmp(name,'length_plus_2pct'),theta.main_length_scale=1.02;theta.branch_length_scale=1.02;end
    if strcmp(name,'load_minus_10pct'),theta.branch_load_scale=.9;end
end
function row=summarize(band,placeholder,cfg,theta,snr,out)
    m=out.metrics;labels=out.classes.class_labels;members=out.classes.class_members;
    pair='';for k=1:numel(members),ids=labels{members{k}(1)};if contains(ids,'T3')&&contains(ids,'T5'),pair=ids;end,end
    nearest_summary=strjoin(unique(out.nearest_competitor,'stable'),';');
    row=struct('analysis_kind',cfg.analysis_kind,'measurement_model','ideal_CFR_plus_receiver_sample_noise', ...
        'reference_library','nominal_library','level',band.level,'band',band.name, ...
        'rlgc_status',band.rlgc_status,'point_count',band.active_point_count, ...
        'frequency_low_hz',band.frequency_hz(1),'frequency_high_hz',band.frequency_hz(end), ...
        'snr_db',snr,'main_length_scale',theta.main_length_scale,'branch_load_scale',theta.branch_load_scale, ...
        'future_waveform_fairness_placeholder',placeholder.status,'strict_accuracy',m.strict_topology_accuracy, ...
        'equivalence_class_accuracy',m.equivalence_class_accuracy,'ambiguity_rate',m.ambiguity_rate, ...
        'false_unique_rate',m.false_unique_rate,'class_intra_distance',m.mean_class_intra_distance, ...
        'nearest_class_inter_distance',m.mean_nearest_class_inter_distance, ...
        'intra_inter_ratio',m.class_intra_inter_ratio,'nearest_competing_topology',nearest_summary, ...
        't3_t5_equivalence_class',pair, ...
        'cfr_sampling_nmse_ideal_input',out.cfr_sampling_nmse_ideal_input);
end
function A=applicability_table()
    A=struct('item',{'RLGC frequency applicability';'load model';'source_receiver_impedance';'frequency_grid';'noise definition';'observation port'}, ...
        'BB',{'2--30 MHz existing project model window';'scalar/complex model interface';'50 ohm mathematical assumption';'G.hn-derived 2--30 MHz indices';'receiver-domain controlled diagnostic';'SISO forward model'}, ...
        'NB',{'below existing evidence: analytic frequency extrapolation';'same mathematical interface; no field calibration';'same mathematical assumption; no hardware calibration';'G3 CENELEC-A derived 36-tone grid';'same controlled diagnostic definition';'same SISO forward model'}, ...
        'evidence_level',{'code/history model boundary';'code interface only';'project assumption';'standard-derived reference';'simulation definition';'model observation definition'}, ...
        'formal_level_a_allowed',{true;true;true;true;true;true});
    for q=1:numel(A), A(q).formal_level_a_allowed=false; end
end
function ensure_dirs(cfg),if ~exist(cfg.results_data,'dir'),mkdir(cfg.results_data);end;if ~exist(cfg.results_figures,'dir'),mkdir(cfg.results_figures);end;if ~exist(cfg.results_logs,'dir'),mkdir(cfg.results_logs);end,end
function make_figure(T,dir_out)
    z=T(isinf(T.snr_db)&T.main_length_scale==1&T.branch_load_scale==1,:);figure('Visible','off');
    bar(categorical(strcat(string(z.level),' ',string(z.band))),[z.strict_accuracy,z.equivalence_class_accuracy]);grid on;ylim([0 1]);ylabel('Accuracy');legend('strict','equivalence class','Location','best');title('Stage3B-pre ideal-CFR sampling diagnostic (not waveform-energy/time fair)');
    print(gcf,fullfile(dir_out,'stage3b_pre_accuracy.png'),'-dpng','-r150');close(gcf);
end
