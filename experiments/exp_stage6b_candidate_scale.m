function [rows,samples]=exp_stage6b_candidate_scale(root,mode)
%EXP_STAGE6B_CANDIDATE_SCALE Candidate count versus runtime/decision study.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6b_robustness_config(base,mode);[out,figdir]=output_dirs(sc);ensure_dir(out);ensure_dir(figdir);
    grammars=sc.scale.grammars;libraries=cell(1,numel(grammars));models=cell(1,numel(grammars));times=cell(1,numel(grammars));
    for q=1:numel(grammars)
        [libraries{q},times{q}]=stage6b_build_candidate_library('radial_grammar',grammars(q),base,struct());
        generate_radial_topology_candidates(grammars(q));generation_samples=zeros(1,sc.scale.runtime_repetitions);
        for z=1:sc.scale.runtime_repetitions,t=tic;generate_radial_topology_candidates(grammars(q));generation_samples(z)=toc(t);end
        times{q}.generation_time_s=median(generation_samples);
        [models{q},~]=stage6b_calibrate_candidate_library(libraries{q},base,sc,['scale_' grammars(q).scale_id],q*100000);
    end
    medium=find(strcmp({grammars.scale_id},'medium'),1);truth_idx=find(arrayfun(@(x)is_truth(x.network,sc.truth_branch_nodes),libraries{medium}),1);
    truth_network=libraries{medium}(truth_idx).network;reps=sc.scale.replicates;
    samples=repmat(sample_row(),numel(grammars)*reps,1);cursor=0;
    observations=cell(1,reps);
    for r=1:reps
        rs=RandStream('mt19937ar','Seed',sc.seed+500000+r);theta=nominal_theta(sc.parameter_search);v=sc.parameter_search.main_length_scale;
        theta.main_length_scale=min(v)+(max(v)-min(v))*rand(rs);
        clean=stage6b_forward_cfr(truth_network,theta,base,sc.frequency_hz,sc.measurement_kind);observations{r}=add_noise(clean,sc.scale.snr_db,rs);
    end
    rows=repmat(scale_row(),numel(grammars),1);
    for q=1:numel(grammars)
        stage6b_evaluate_observation(observations{1},models{q},truth_network);
        for r=1:reps
            cursor=cursor+1;z=stage6b_evaluate_observation(observations{r},models{q},truth_network);
            samples(cursor)=struct('scale_id',grammars(q).scale_id,'replicate',r,'candidate_number',z.candidate_count, ...
                'scoring_time_s',z.scoring_time_s,'decision_state',z.decision_state,'false_unique',z.false_unique, ...
                'distance',z.distance,'margin',z.margin,'confidence',z.top1_confidence,'entropy',z.normalized_entropy);
        end
        x=samples(strcmp({samples.scale_id},grammars(q).scale_id));states={x.decision_state};
        u=nnz(strcmp(states,'UNIQUE_CONFIDENT'));a=nnz(strcmp(states,'MULTIPLE_AMBIGUOUS'));
        l=nnz(strcmp(states,'LOW_CONFIDENCE'));rj=nnz(strcmp(states,'REJECTED'));
        rows(q)=struct('scale_id',grammars(q).scale_id,'candidate_number',numel(libraries{q}), ...
            'generation_time',times{q}.generation_time_s,'scoring_time',sum([x.scoring_time_s]), ...
            'mean_scoring_time_per_sample',mean([x.scoring_time_s]), ...
            'decision_distribution',sprintf('UNIQUE_CONFIDENT=%d;MULTIPLE_AMBIGUOUS=%d;LOW_CONFIDENCE=%d;REJECTED=%d',u,a,l,rj), ...
            'unique_confident_count',u,'multiple_ambiguous_count',a,'low_confidence_count',l, ...
            'rejected_count',rj,'false_unique_count',nnz([x.false_unique]),'sample_count',numel(x));
    end
    writetable(struct2table(rows),fullfile(out,'stage6b_candidate_scale.csv'));
    writetable(struct2table(samples),fullfile(out,'stage6b_candidate_scale_samples.csv'));make_plot(rows,figdir);
end

function make_plot(rows,figdir)
    f=figure('Visible','off','Color','w','Position',[100 100 1050 420]);tiledlayout(1,2);
    nexttile;yyaxis left;plot([rows.candidate_number],[rows.generation_time],'-o','LineWidth',1.5);ylabel('Generation time (s)');
    yyaxis right;plot([rows.candidate_number],[rows.mean_scoring_time_per_sample],'-s','LineWidth',1.5);ylabel('Mean scoring time (s)');
    xlabel('Candidate number');grid on;title('Runtime scaling');
    nexttile;values=[[rows.unique_confident_count].' [rows.multiple_ambiguous_count].' [rows.low_confidence_count].' [rows.rejected_count].'];
    bar(1:numel(rows),values,'stacked');xticks(1:numel(rows));xticklabels({rows.scale_id});ylabel('Sample count');title('Decision distribution');
    legend('Unique confident','Multiple ambiguous','Low confidence','Rejected','Location','bestoutside');grid on;
    exportgraphics(f,fullfile(figdir,'stage6b_candidate_scale.png'),'Resolution',160);close(f);
end
function tf=is_truth(network,nodes),tf=isequal(sort([network.branches.node]),sort(nodes));end
function theta=nominal_theta(search),theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',search.source_impedance_ohm(1),'receiver_impedance_ohm',search.receiver_impedance_ohm(1),'regularization',0);end
function y=add_noise(x,snr,rs),s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));end
function [out,figdir]=output_dirs(sc),if strcmp(sc.mode,'formal'),out=sc.output_root;figdir=sc.figure_root;else,out=fullfile(sc.output_root,sc.mode);figdir=fullfile(sc.figure_root,sc.mode);end,end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=scale_row(),r=struct('scale_id','','candidate_number',0,'generation_time',NaN,'scoring_time',NaN,'mean_scoring_time_per_sample',NaN,'decision_distribution','','unique_confident_count',0,'multiple_ambiguous_count',0,'low_confidence_count',0,'rejected_count',0,'false_unique_count',0,'sample_count',0);end
function r=sample_row(),r=struct('scale_id','','replicate',0,'candidate_number',0,'scoring_time_s',NaN,'decision_state','','false_unique',false,'distance',NaN,'margin',NaN,'confidence',NaN,'entropy',NaN);end
