function [selected_for_execution, rows, manifest] = stage4a7_2_r2_method_selection(distances, truth_ids, candidate_ids, sc, hash)
%STAGE4A7_2_R2_METHOD_SELECTION Select or explicitly report a tie.
%   A deterministic fallback may be used for execution, but it is never
%   labelled a scientifically unique winner when metrics are tied.
    ids = cellstr(candidate_ids(:)); truth_ids = cellstr(truth_ids(:));
    fam = stage4a7_2_r1_profile_score_families(distances,[],[]);
    methods = sc.method_selection.method_ids;
    rows = repmat(row_template(),1,numel(methods));
    set_k = min(sc.method_selection.development_set_size,numel(ids));
    for q=1:numel(methods)
        scores = fam.(methods{q}); n=size(scores,1); hit=false(n,1); sz=zeros(n,1);
        singleton_correct=false(n,1); empty=false(n,1);
        for i=1:n
            [~,ord]=sort(scores(i,:),'ascend'); keep=ord(1:set_k);
            sz(i)=numel(keep); hit(i)=any(strcmp(truth_ids{i},ids(keep)));
            singleton_correct(i)=set_k==1 && hit(i); empty(i)=isempty(keep);
        end
        rows(q).method_id=methods{q}; rows(q).coverage_num=nnz(hit);
        rows(q).coverage_den=n; rows(q).coverage=ratio(rows(q).coverage_num,n);
        rows(q).mean_set_size=mean(sz); rows(q).median_set_size=median(sz);
        rows(q).singleton_correct_num=nnz(singleton_correct); rows(q).singleton_correct_den=n;
        rows(q).singleton_correct_rate=ratio(nnz(singleton_correct),n);
        rows(q).empty_set_num=nnz(empty); rows(q).empty_set_den=n;
        rows(q).empty_set_rate=ratio(nnz(empty),n);
        rows(q).gate_pass=rows(q).coverage>=sc.method_selection.coverage_gate;
        rows(q).rejection_reason=ternary(rows(q).gate_pass,'','coverage_gate_not_met');
    end
    pass=find([rows.gate_pass]);
    if isempty(pass)
        selected_for_execution='no_method_meets_gate'; tied={}; unique_winner=false;
    else
        % Lexicographic rule: coverage, set size, singleton correctness,
        % empty rate. Values within tie_tolerance are treated as tied.
        vals=zeros(numel(pass),4);
        for j=1:numel(pass)
            r=rows(pass(j)); vals(j,:)=[r.coverage,-r.mean_set_size, ...
                r.singleton_correct_rate,-r.empty_set_rate];
        end
        best=pass(1); bestv=vals(1,:);
        for j=2:numel(pass)
            if lex_better(vals(j,:),bestv,sc.method_selection.tie_tolerance)
                best=pass(j); bestv=vals(j,:);
            end
        end
        tied=pass(abs(vals(:,1)-bestv(1))<=sc.method_selection.tie_tolerance & ...
            abs(vals(:,2)-bestv(2))<=sc.method_selection.tie_tolerance & ...
            abs(vals(:,3)-bestv(3))<=sc.method_selection.tie_tolerance & ...
            abs(vals(:,4)-bestv(4))<=sc.method_selection.tie_tolerance);
        unique_winner=numel(tied)==1;
        selected_for_execution=rows(best).method_id;
    end
    if isempty(pass), tied_methods={}; else, tied_methods={rows(tied).method_id}; end
    for q=1:numel(rows)
        rows(q).scientifically_unique_winner=unique_winner;
        is_tied=~isempty(tied_methods)&&any(strcmp(tied_methods,rows(q).method_id));
        rows(q).selection_status=ternary(unique_winner,'unique_winner', ...
            ternary(is_tied,'no_unique_winner','not_selected'));
        rows(q).tied_methods=strjoin(tied_methods,',');
    end
    manifest=struct('selected_method',selected_for_execution, ...
        'selected_for_execution',selected_for_execution, ...
        'scientifically_unique_winner',unique_winner, ...
        'tied_methods',strjoin(tied_methods,','), ...
        'selection_rule','development coverage gate; lexicographic coverage, set size, singleton, empty with tie tolerance', ...
        'selected_hyperparameters',struct('set_k',set_k,'alpha',sc.alpha, ...
        'tie_tolerance',sc.method_selection.tie_tolerance), ...
        'compatibility_hash',hash,'frozen_method_hash', ...
        stage4a4_scientific_config_hash(struct('selected',selected_for_execution, ...
        'tied',{tied_methods},'rows',rows,'hash',hash)), ...
        'status',ternary(strcmp(selected_for_execution,'no_method_meets_gate'), ...
        'no_method_meets_gate',ternary(unique_winner,'unique_winner','no_unique_winner')));
end
function tf=lex_better(a,b,tol)
    tf=false;
    for k=1:numel(a)
        if a(k)>b(k)+tol,tf=true;return;elseif a(k)<b(k)-tol,return;end
    end
end
function r=ratio(a,b),if b==0,r=NaN;else,r=a/b;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function r=row_template()
    r=struct('method_id','','coverage_num',0,'coverage_den',0,'coverage',NaN, ...
        'mean_set_size',NaN,'median_set_size',NaN,'singleton_correct_num',0, ...
        'singleton_correct_den',0,'singleton_correct_rate',NaN,'empty_set_num',0, ...
        'empty_set_den',0,'empty_set_rate',NaN,'gate_pass',false, ...
        'rejection_reason','','scientifically_unique_winner',false, ...
        'selection_status','','tied_methods','');
end
