function [selected_for_execution, rows, models, manifest] = stage4a7_2_r2_calibrated_method_selection(dev_distances, dev_truth_ids, cal_distances, cal_truth_ids, candidate_ids, sc, compatibility_hash)
%STAGE4A7_2_R2_CALIBRATED_METHOD_SELECTION Select methods after calibration.
%   Each method gets its own empirical calibration model from CAL_DISTANCES.
%   Development rows are then evaluated with the corresponding calibrated
%   candidate set; no fixed Top-K set is used for selection.
    if nargin < 7, compatibility_hash = ''; end
    candidate_ids = cellstr(candidate_ids(:));
    dev_truth_ids = cellstr(dev_truth_ids(:));
    cal_truth_ids = cellstr(cal_truth_ids(:));
    methods = sc.method_selection.method_ids;
    models = cell(1,numel(methods));
    rows = repmat(row_template(),1,numel(methods));
    cal_index = truth_indices(cal_truth_ids,candidate_ids);
    for q=1:numel(methods)
        models{q}=stage4a7_2_r1_calibrate_profile_method(cal_distances,cal_index,candidate_ids,methods{q},sc.alpha,struct( ...
            'minimum_per_candidate',sc.scenario_design.calibration_per_candidate, ...
            'compatibility_hash',compatibility_hash,'resolution',sc.profile.resolution_floor));
        n=size(dev_distances,1);hit=false(n,1);accepted=false(n,1);empty=false(n,1);set_size=zeros(n,1);
        for i=1:n
            a=stage4a7_2_r1_apply_profile_candidate_set(dev_distances(i,:),models{q},methods{q});
            accepted(i)=~a.empty;empty(i)=a.empty;set_size(i)=a.set_size;
            hit(i)=any(strcmp(a.accepted_candidate_set,dev_truth_ids{i}));
        end
        decided=accepted;
        rows(q).method_id=methods{q};rows(q).coverage_num=nnz(hit);rows(q).coverage_den=n;
        rows(q).coverage=ratio(nnz(hit),n);rows(q).mean_set_size=mean(set_size);rows(q).median_set_size=median(set_size);
        rows(q).singleton_correct_num=nnz(set_size==1 & hit);rows(q).singleton_correct_den=n;
        rows(q).singleton_correct_rate=ratio(rows(q).singleton_correct_num,n);
        rows(q).empty_set_num=nnz(empty);rows(q).empty_set_den=n;rows(q).empty_set_rate=ratio(nnz(empty),n);
        rows(q).selective_risk_num=nnz(decided & ~hit);rows(q).selective_risk_den=nnz(decided);
        rows(q).selective_risk=ratio(rows(q).selective_risk_num,rows(q).selective_risk_den);
        rows(q).gate_pass=isfinite(rows(q).coverage)&&rows(q).coverage>=sc.method_selection.coverage_gate;
        rows(q).rejection_reason=ternary(rows(q).gate_pass,'','coverage_gate_not_met');
    end
    pass=find([rows.gate_pass]);
    unique_winner=false;tied=[];selected_for_execution='no_method_meets_gate';
    if ~isempty(pass)
        vals=zeros(numel(pass),4);
        for j=1:numel(pass)
            r=rows(pass(j));vals(j,:)=[r.coverage,-r.mean_set_size,r.singleton_correct_rate,-r.empty_set_rate];
        end
        best=pass(1);bestv=vals(1,:);
        for j=2:numel(pass)
            if lex_better(vals(j,:),bestv,sc.method_selection.tie_tolerance),best=pass(j);bestv=vals(j,:);end
        end
        tied=pass(all(abs(vals-bestv)<=sc.method_selection.tie_tolerance,2));
        unique_winner=numel(tied)==1;selected_for_execution=rows(best).method_id;
    end
    tied_methods=cell(1,numel(tied));for k=1:numel(tied),tied_methods{k}=rows(tied(k)).method_id;end
    for q=1:numel(rows)
        rows(q).scientifically_unique_winner=unique_winner;rows(q).tied_methods=strjoin(tied_methods,',');
        if unique_winner && strcmp(rows(q).method_id,selected_for_execution),rows(q).selection_status='unique_winner';
        elseif any(strcmp(tied_methods,rows(q).method_id)),rows(q).selection_status='no_unique_winner';
        else,rows(q).selection_status='not_selected';end
    end
    if strcmp(selected_for_execution,'no_method_meets_gate')
        fallback=find(strcmp(methods,'absolute'),1);if isempty(fallback),fallback=1;end
        selected_for_execution=methods{fallback};selected_status='no_method_meets_gate';
    else
        selected_status=ternary(unique_winner,'unique_winner','no_unique_winner');
    end
    manifest=struct('selected_method',selected_for_execution,'selected_for_execution',selected_for_execution, ...
        'scientifically_unique_winner',unique_winner,'tied_methods',strjoin(tied_methods,','), ...
        'selection_status',selected_status,'selection_rule','calibrate each method on calibration; evaluate calibrated sets on development; coverage gate then set size, singleton correctness and empty rate with tie tolerance', ...
        'selected_hyperparameters',struct('alpha',sc.alpha,'coverage_gate',sc.method_selection.coverage_gate,'tie_tolerance',sc.method_selection.tie_tolerance), ...
        'compatibility_hash',compatibility_hash,'frozen_method_hash',stage4a4_scientific_config_hash(struct('selected',selected_for_execution,'tied',{tied_methods},'rows',rows,'hash',compatibility_hash)));
end

function idx=truth_indices(truth_ids,candidate_ids)
    idx=zeros(numel(truth_ids),1);
    for k=1:numel(truth_ids)
        idx(k)=find(strcmp(candidate_ids,truth_ids{k}),1);
        if isempty(idx(k)),error('stage4a7_2_r2:UnknownTruthCandidate','Truth candidate %s is not in the scored library.',truth_ids{k});end
    end
end
function tf=lex_better(a,b,tol)
    tf=false;for k=1:numel(a),if a(k)>b(k)+tol,tf=true;return;elseif a(k)<b(k)-tol,return;end,end
end
function r=ratio(a,b),if b==0,r=NaN;else,r=a/b;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function r=row_template()
    r=struct('method_id','','coverage_num',0,'coverage_den',0,'coverage',NaN,'mean_set_size',NaN,'median_set_size',NaN, ...
        'singleton_correct_num',0,'singleton_correct_den',0,'singleton_correct_rate',NaN,'empty_set_num',0,'empty_set_den',0, ...
        'empty_set_rate',NaN,'selective_risk_num',0,'selective_risk_den',0,'selective_risk',NaN,'gate_pass',false, ...
        'rejection_reason','','scientifically_unique_winner',false,'selection_status','','tied_methods','');
end
