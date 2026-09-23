function [rows,distance_matrix]=exp_stage6b_identifiability(root,mode)
%EXP_STAGE6B_IDENTIFIABILITY Two/three-topology CFR-close positive controls.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6b_robustness_config(base,mode);[out,figdir]=output_dirs(sc);ensure_dir(out);ensure_dir(figdir);
    assert(exist(sc.identifiability.stage5b1_model_file,'file')==2,'stage6b:MissingEvidenceModel','Stage 5B.1 evidence model is missing.');
    saved=load(sc.identifiability.stage5b1_model_file,'evidence_model');model=saved.evidence_model;
    all_candidates=topology_candidates(base);t3=all_candidates(strcmp({all_candidates.id},'T3'));
    t5=all_candidates(strcmp({all_candidates.id},'T5'));t4=all_candidates(strcmp({all_candidates.id},'T4'));
    t4.id='T4_NEAR_T3';t4.network.branches(1).length=sc.identifiability.near_invisible_branch_length_m;
    t4.network.branches(1).load=sc.identifiability.near_invisible_branch_load_ohm;
    candidates=[t3 t5 t4];ids={candidates.id};theta=matched_theta(sc);
    H=complex(zeros(3,numel(sc.frequency_hz)));
    for k=1:3,H(k,:)=stage6b_forward_cfr(candidates(k).network,theta,base,sc.frequency_hz,sc.measurement_kind);end
    distance_matrix=zeros(3);
    for i=1:3,for j=1:3,distance_matrix(i,j)=sqrt(mean(abs(H(i,:)-H(j,:)).^2));end,end
    scenarios=struct('name',{'two_topology_T3_T5','three_topology_close'},'indices',{[1 2],[1 2 3]});
    rows=repmat(result_row(),2,1);
    for q=1:2
        ix=scenarios(q).indices;d=sqrt(mean(abs(H(ix,:)-H(1,:)).^2,2)).';
        margin=compute_candidate_margin(d,ids(ix));confidence=compute_candidate_confidence(d,model.beta,ids(ix));
        frozen=struct('candidate_set_size',numel(ix),'domain_accepted',true,'best_candidate_in_set',true);
        decision=classify_stage5b1_decision_state(frozen,struct('margin',margin.margin), ...
            struct('top1_confidence',confidence.top1_confidence,'normalized_entropy',confidence.normalized_entropy),model);
        local_matrix=distance_matrix(ix,ix);
        rows(q)=struct('scenario',scenarios(q).name,'candidate_count',numel(ix), ...
            'candidate_gap',max(d)-min(d),'margin',margin.margin,'entropy',confidence.normalized_entropy, ...
            'top1_confidence',confidence.top1_confidence,'decision_state',decision.enhanced_decision_state, ...
            'maximum_pairwise_distance',max(local_matrix(:)),'distance_matrix',matrix_text(local_matrix), ...
            'construction',construction_text(q),'normalized_score_semantics','not_a_Bayesian_posterior');
    end
    writetable(struct2table(rows),fullfile(out,'stage6b_identifiability.csv'));
    writematrix(distance_matrix,fullfile(out,'stage6b_identifiability_distance_matrix.csv'));
    make_plot(distance_matrix,ids,figdir);
end

function theta=matched_theta(sc)
    z=sc.identifiability.matched_impedance_ohm;
    theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1, ...
        'source_impedance_ohm',z,'receiver_impedance_ohm',z,'regularization',0);
end
function text=matrix_text(x)
    rows=cell(1,size(x,1));for k=1:size(x,1),rows{k}=strjoin(arrayfun(@(v)sprintf('%.16g',v),x(k,:),'UniformOutput',false),',');end
    text=strjoin(rows,';');
end
function text=construction_text(q)
    if q==1,text='matched-end SISO mirror-equivalent T3/T5';else,text='T3/T5 plus T4 with a near-electrically-invisible extra branch';end
end
function make_plot(D,ids,figdir)
    f=figure('Visible','off','Color','w','Position',[100 100 680 540]);imagesc(D);axis image;colorbar;title('Pairwise CFR RMS distance');
    xticks(1:3);yticks(1:3);xticklabels(ids);yticklabels(ids);xlabel('Candidate');ylabel('Candidate');
    ax=gca;ax.TickLabelInterpreter='none';
    for i=1:3,for j=1:3,text(j,i,sprintf('%.2g',D(i,j)),'HorizontalAlignment','center','Color','k');end,end
    exportgraphics(f,fullfile(figdir,'stage6b_identifiability.png'),'Resolution',160);close(f);
end
function [out,figdir]=output_dirs(sc),if strcmp(sc.mode,'formal'),out=sc.output_root;figdir=sc.figure_root;else,out=fullfile(sc.output_root,sc.mode);figdir=fullfile(sc.figure_root,sc.mode);end,end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=result_row(),r=struct('scenario','','candidate_count',0,'candidate_gap',NaN,'margin',NaN,'entropy',NaN,'top1_confidence',NaN,'decision_state','','maximum_pairwise_distance',NaN,'distance_matrix','','construction','','normalized_score_semantics','');end
