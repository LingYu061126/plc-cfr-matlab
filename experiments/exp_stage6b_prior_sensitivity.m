function [rows,summary]=exp_stage6b_prior_sensitivity(root,mode)
%EXP_STAGE6B_PRIOR_SENSITIVITY Population-level wrong-open/closed study.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6b_robustness_config(base,mode);[out,figdir]=output_dirs(sc);ensure_dir(out);ensure_dir(figdir);
    correct=sc.prior.base_prior;wrong_open=set_switch(correct,sc.prior.wrong_open_edge,'open');
    wrong_closed=set_switch(correct,sc.prior.wrong_closed_edge,'closed');
    options=struct('rank',sc.rank,'export',sc.export);
    [lib0,time0]=stage6b_build_candidate_library('partial_prior',correct,base,options);
    [lib_open,time_open]=stage6b_build_candidate_library('partial_prior',wrong_open,base,options);
    [lib_closed,time_closed]=stage6b_build_candidate_library('partial_prior',wrong_closed,base,options);
    [model0,~]=stage6b_calibrate_candidate_library(lib0,base,sc,'prior_correct',100000);
    [model_open,~]=stage6b_calibrate_candidate_library(lib_open,base,sc,'prior_wrong_open',200000);
    [model_closed,~]=stage6b_calibrate_candidate_library(lib_closed,base,sc,'prior_wrong_closed',300000);
    truth_idx=find(arrayfun(@(x)is_truth(x.network,sc.truth_branch_nodes),lib0),1);
    assert(~isempty(truth_idx),'stage6b:MissingTruth','Controlled truth is missing from the unperturbed prior library.');
    truth_network=lib0(truth_idx).network;
    types={'wrong_open','wrong_closed'};rates=sc.prior.error_rates;reps=sc.prior.replicates_per_rate;
    rows=repmat(prior_row(),numel(types)*numel(rates)*reps,1);cursor=0;
    for q=1:numel(types)
        if strcmp(types{q},'wrong_open'),bad_model=model_open;bad_time=time_open;else,bad_model=model_closed;bad_time=time_closed;end
        for u=1:numel(rates)
            corrupted_count=round(rates(u)*reps);
            for r=1:reps
                cursor=cursor+1;is_corrupted=r<=corrupted_count;
                if is_corrupted,model=bad_model;generation=bad_time.generation_time_s;else,model=model0;generation=time0.generation_time_s;end
                rs=RandStream('mt19937ar','Seed',sc.seed+q*1000000+u*10000+r);
                theta=nominal_theta(sc.parameter_search);v=sc.parameter_search.main_length_scale;
                theta.main_length_scale=min(v)+(max(v)-min(v))*rand(rs);
                clean=stage6b_forward_cfr(truth_network,theta,base,sc.frequency_hz,sc.measurement_kind);
                observation=add_noise(clean,sc.prior.snr_db,rs);result=stage6b_evaluate_observation(observation,model,truth_network);
                rows(cursor)=struct('sample',sprintf('%s_rate_%02g_r%02d',types{q},100*rates(u),r), ...
                    'error_type',types{q},'prior_error_rate',100*rates(u),'prior_error_applied',is_corrupted, ...
                    'candidate_count',result.candidate_count,'generation_time',generation, ...
                    'coverage',double(result.truth_topology_included),'false_unique',result.false_unique, ...
                    'decision_state',result.decision_state,'best_is_truth',result.best_is_truth, ...
                    'candidate_set_size',result.candidate_set_size,'distance',result.distance, ...
                    'margin',result.margin,'confidence',result.top1_confidence,'entropy',result.normalized_entropy);
            end
        end
    end
    summary=aggregate(rows,types,rates);writetable(struct2table(rows),fullfile(out,'stage6b_prior_sensitivity.csv'));
    writetable(struct2table(summary),fullfile(out,'stage6b_prior_sensitivity_summary.csv'));
    make_plot(summary,figdir);
end

function p=set_switch(p,edge,state)
    for k=1:numel(p.switch_state)
        if same_edge(p.switch_state(k).from,p.switch_state(k).to,edge{1},edge{2}),p.switch_state(k).state=state;return;end
    end
    error('stage6b:SwitchNotFound','Requested switch edge was not found.');
end
function tf=same_edge(a,b,c,d),tf=isequal(sort({char(a),char(b)}),sort({char(c),char(d)}));end
function tf=is_truth(network,nodes),tf=isequal(sort([network.branches.node]),sort(nodes));end
function theta=nominal_theta(search),theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',search.source_impedance_ohm(1),'receiver_impedance_ohm',search.receiver_impedance_ohm(1),'regularization',0);end
function y=add_noise(x,snr,rs),s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));end
function s=aggregate(rows,types,rates)
    s=repmat(summary_row(),numel(types)*numel(rates),1);cursor=0;
    for q=1:numel(types)
        for u=1:numel(rates)
            cursor=cursor+1;idx=strcmp({rows.error_type},types{q})&[rows.prior_error_rate]==100*rates(u);x=rows(idx);states={x.decision_state};
            corrupted=x([x.prior_error_applied]);corrupted_states={corrupted.decision_state};
            s(cursor)=struct('error_type',types{q},'prior_error_rate',100*rates(u),'sample_count',numel(x), ...
                'applied_error_count',nnz([x.prior_error_applied]),'mean_candidate_count',mean([x.candidate_count]), ...
                'coverage_rate',mean([x.coverage]),'false_unique_count',nnz([x.false_unique]), ...
                'corrupted_false_unique_count',nnz([corrupted.false_unique]), ...
                'corrupted_unique_confident_count',nnz(strcmp(corrupted_states,'UNIQUE_CONFIDENT')), ...
                'corrupted_rejected_count',nnz(strcmp(corrupted_states,'REJECTED')), ...
                'unique_confident_count',nnz(strcmp(states,'UNIQUE_CONFIDENT')), ...
                'multiple_ambiguous_count',nnz(strcmp(states,'MULTIPLE_AMBIGUOUS')), ...
                'low_confidence_count',nnz(strcmp(states,'LOW_CONFIDENCE')),'rejected_count',nnz(strcmp(states,'REJECTED')));
        end
    end
end
function make_plot(s,figdir)
    f=figure('Visible','off','Color','w','Position',[100 100 1000 420]);tiledlayout(1,2);types=unique({s.error_type},'stable');
    for q=1:2
        nexttile;idx=strcmp({s.error_type},types{q});x=s(idx);
        plot([x.prior_error_rate],[x.coverage_rate],'-o','LineWidth',1.5);hold on;
        plot([x.prior_error_rate],[x.false_unique_count]./[x.sample_count],'-s','LineWidth',1.5);
        plot([x.prior_error_rate],[x.rejected_count]./[x.sample_count],'-^','LineWidth',1.5);grid on;ylim([0 1]);
        xlabel('Prior error rate (%)');ylabel('Fraction');title(strrep(x(1).error_type,'_',' '));legend('Coverage','False unique','Rejected','Location','best');
    end
    exportgraphics(f,fullfile(figdir,'stage6b_prior_sensitivity.png'),'Resolution',160);close(f);
end
function [out,figdir]=output_dirs(sc),if strcmp(sc.mode,'formal'),out=sc.output_root;figdir=sc.figure_root;else,out=fullfile(sc.output_root,sc.mode);figdir=fullfile(sc.figure_root,sc.mode);end,end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=prior_row(),r=struct('sample','','error_type','','prior_error_rate',NaN,'prior_error_applied',false,'candidate_count',0,'generation_time',NaN,'coverage',NaN,'false_unique',false,'decision_state','','best_is_truth',false,'candidate_set_size',0,'distance',NaN,'margin',NaN,'confidence',NaN,'entropy',NaN);end
function r=summary_row(),r=struct('error_type','','prior_error_rate',NaN,'sample_count',0,'applied_error_count',0,'mean_candidate_count',NaN,'coverage_rate',NaN,'false_unique_count',0,'corrupted_false_unique_count',0,'corrupted_unique_confident_count',0,'corrupted_rejected_count',0,'unique_confident_count',0,'multiple_ambiguous_count',0,'low_confidence_count',0,'rejected_count',0);end
