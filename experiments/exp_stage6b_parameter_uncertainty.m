function [rows,summary]=exp_stage6b_parameter_uncertainty(root,mode)
%EXP_STAGE6B_PARAMETER_UNCERTAINTY Length/load mismatch robustness study.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6b_robustness_config(base,mode);[out,figdir]=output_dirs(sc);ensure_dir(out);ensure_dir(figdir);
    [library,~]=stage6b_build_candidate_library('radial_grammar',sc.parameter.grammar,base,struct());
    [model,~]=stage6b_calibrate_candidate_library(library,base,sc,'parameter_uncertainty',700000);
    truth_idx=find(arrayfun(@(x)is_truth(x.network,sc.truth_branch_nodes),library),1);truth_network=library(truth_idx).network;
    errors=sc.parameter.length_errors;reps=sc.parameter.replicates_per_error;
    rows=repmat(parameter_row(),numel(errors)*reps,1);cursor=0;
    for q=1:numel(errors)
        for r=1:reps
            cursor=cursor+1;rs=RandStream('mt19937ar','Seed',sc.seed+7000000+q*1000+r);
            load_error=sc.parameter.load_perturbation_fraction*(2*rand(rs)-1);
            theta=nominal_theta(sc.parameter_search);theta.main_length_scale=1+errors(q);theta.branch_load_scale=1+load_error;
            clean=stage6b_forward_cfr(truth_network,theta,base,sc.frequency_hz,sc.measurement_kind);
            observation=add_noise(clean,sc.parameter.snr_db,rs);z=stage6b_evaluate_observation(observation,model,truth_network);
            rows(cursor)=struct('sample',sprintf('length_%+03g_load_%+06.2f_r%02d',100*errors(q),100*load_error,r), ...
                'parameter_error',100*errors(q),'length_error_percent',100*errors(q), ...
                'load_error_percent',100*load_error,'distance',z.distance, ...
                'relative_distance',z.domain_relative_distance,'margin',z.margin, ...
                'confidence',z.top1_confidence,'entropy',z.normalized_entropy, ...
                'candidate_set_size',z.candidate_set_size,'decision_state',z.decision_state, ...
                'best_is_truth',z.best_is_truth,'false_unique',z.false_unique);
        end
    end
    summary=aggregate(rows,errors);writetable(struct2table(rows),fullfile(out,'stage6b_parameter_uncertainty.csv'));
    writetable(struct2table(summary),fullfile(out,'stage6b_parameter_uncertainty_summary.csv'));make_plot(summary,figdir);
end

function s=aggregate(rows,errors)
    s=repmat(summary_row(),numel(errors),1);
    for q=1:numel(errors)
        x=rows([rows.parameter_error]==100*errors(q));states={x.decision_state};
        s(q)=struct('parameter_error',100*errors(q),'sample_count',numel(x), ...
            'mean_distance',mean([x.distance]),'mean_relative_distance',mean([x.relative_distance]), ...
            'mean_margin',mean([x.margin]),'mean_confidence',mean([x.confidence]),'mean_entropy',mean([x.entropy]), ...
            'unique_confident_count',nnz(strcmp(states,'UNIQUE_CONFIDENT')), ...
            'multiple_ambiguous_count',nnz(strcmp(states,'MULTIPLE_AMBIGUOUS')), ...
            'low_confidence_count',nnz(strcmp(states,'LOW_CONFIDENCE')), ...
            'rejected_count',nnz(strcmp(states,'REJECTED')),'false_unique_count',nnz([x.false_unique]));
    end
end
function make_plot(s,figdir)
    f=figure('Visible','off','Color','w','Position',[100 100 1050 420]);tiledlayout(1,2);
    nexttile;plot([s.parameter_error],[s.mean_distance],'-o','LineWidth',1.5);hold on;
    plot([s.parameter_error],[s.mean_margin],'-s','LineWidth',1.5);plot([s.parameter_error],[s.mean_confidence],'-^','LineWidth',1.5);
    xlabel('Main-line length error (%)');grid on;title('Evidence metrics');legend('Distance','Margin','Top-1 confidence','Location','best');
    nexttile;values=[[s.unique_confident_count].' [s.multiple_ambiguous_count].' [s.low_confidence_count].' [s.rejected_count].'];
    bar(1:numel(s),values,'stacked');xticks(1:numel(s));xticklabels(string([s.parameter_error]));xlabel('Length error (%)');ylabel('Sample count');title('Decision distribution');
    legend('Unique confident','Multiple ambiguous','Low confidence','Rejected','Location','bestoutside');grid on;
    exportgraphics(f,fullfile(figdir,'stage6b_parameter_uncertainty.png'),'Resolution',160);close(f);
end
function tf=is_truth(network,nodes),tf=isequal(sort([network.branches.node]),sort(nodes));end
function theta=nominal_theta(search),theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',search.source_impedance_ohm(1),'receiver_impedance_ohm',search.receiver_impedance_ohm(1),'regularization',0);end
function y=add_noise(x,snr,rs),s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));end
function [out,figdir]=output_dirs(sc),if strcmp(sc.mode,'formal'),out=sc.output_root;figdir=sc.figure_root;else,out=fullfile(sc.output_root,sc.mode);figdir=fullfile(sc.figure_root,sc.mode);end,end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=parameter_row(),r=struct('sample','','parameter_error',NaN,'length_error_percent',NaN,'load_error_percent',NaN,'distance',NaN,'relative_distance',NaN,'margin',NaN,'confidence',NaN,'entropy',NaN,'candidate_set_size',0,'decision_state','','best_is_truth',false,'false_unique',false);end
function r=summary_row(),r=struct('parameter_error',NaN,'sample_count',0,'mean_distance',NaN,'mean_relative_distance',NaN,'mean_margin',NaN,'mean_confidence',NaN,'mean_entropy',NaN,'unique_confident_count',0,'multiple_ambiguous_count',0,'low_confidence_count',0,'rejected_count',0,'false_unique_count',0);end
