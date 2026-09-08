function [selected,rows,manifest]=stage4a7_2_r1_method_selection(distances,truth_sets,ids,sc,compatibility_hash)
%STAGE4A7_2_R1_METHOD_SELECTION Freeze a method using development only.
    ids=stage4a7_1_cellstr(ids);truth_sets=stage4a7_1_cellstr(truth_sets);fam=stage4a7_2_r1_profile_score_families(distances,[],[]);
    methods=sc.method_selection.method_ids;rows=repmat(struct('method_id','','truth_set_coverage',NaN,'coverage_num',0,'coverage_den',0,'mean_set_size',NaN,'singleton_correct_rate',NaN,'empty_set_rate',NaN,'gate_pass',false,'rejection_reason',''),1,numel(methods));
    for q=1:numel(methods)
        scores=fam.(methods{q});accepted=cell(size(scores,1),1);setsz=zeros(size(scores,1),1);hit=false(size(scores,1),1);singleton=false(size(scores,1),1);empty=false(size(scores,1),1);
        for i=1:size(scores,1)
            [~,ord]=sort(scores(i,:),'ascend');m=max(1,min(numel(ord),getfield_default(sc,'top_k',7)));accepted{i}=ids(ord(1:m));setsz(i)=numel(accepted{i});hit(i)=any(ismember(accepted{i},strsplit(truth_sets{i},',')));singleton(i)=numel(accepted{i})==1&&strcmp(accepted{i}{1},truth_sets{i});empty(i)=isempty(accepted{i});
        end
        rows(q).method_id=methods{q};rows(q).coverage_num=nnz(hit);rows(q).coverage_den=numel(hit);rows(q).truth_set_coverage=mean(hit);rows(q).mean_set_size=mean(setsz);rows(q).singleton_correct_rate=mean(singleton);rows(q).empty_set_rate=mean(empty);rows(q).gate_pass=rows(q).truth_set_coverage>=sc.method_selection.candidate_coverage_gate;rows(q).rejection_reason=ternary(rows(q).gate_pass,'','coverage_gate_not_met');
    end
    pass=find([rows.gate_pass]);if isempty(pass),selected='no_method_meets_gate';else,mat=[-arrayfun(@(x)x.truth_set_coverage,rows(pass));arrayfun(@(x)x.mean_set_size,rows(pass));-arrayfun(@(x)x.singleton_correct_rate,rows(pass));arrayfun(@(x)x.empty_set_rate,rows(pass))].';[~,j]=sortrows(mat,[1 2 3 4]);selected=rows(pass(j(1))).method_id;end
    manifest=struct('selected_method',selected,'selection_rule','development coverage gate; then mean set size; then singleton accuracy; then empty-set rate','selected_hyperparameters',struct('alpha',sc.alpha,'top_k',sc.top_k),'compatibility_hash',compatibility_hash,'frozen_method_hash',stage4a4_scientific_config_hash(struct('selected_method',selected,'rows',rows,'compatibility_hash',compatibility_hash)),'status',ternary(strcmp(selected,'no_method_meets_gate'),'no_method_meets_gate','frozen_from_development_only'));
end
function x=getfield_default(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
