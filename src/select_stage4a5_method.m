function selected = select_stage4a5_method(validation_metrics, specs, sc)
%SELECT_STAGE4A5_METHOD Select a method using development validation only.
%   The selection objective is worst-case structure/parameter false accept
%   after a micro-averaged in-library set-accuracy constraint.
    selected=repmat(selection_template(),0,1);if isempty(validation_metrics),error('stage4a5:EmptyValidation','Validation metrics are required.');end
    ids=stable_unique({specs.method_id});
    aggregate=repmat(aggregate_template(),0,1);
    for k=1:numel(ids)
        spec=specs(strcmp({specs.method_id},ids{k}));m=validation_metrics(strcmp({validation_metrics.method_id},ids{k}) & strcmp({validation_metrics.scenario_id},'P0_no_prior') & strcmp({validation_metrics.metric_scope},'detail'));
        in=m(ismember({m.category},{'in_library_continuous','in_library_grid'}));st=m(strcmp({m.category},'structure_out'));pa=m(strcmp({m.category},'parameter_out'));
        if isempty(in),continue;end
        a=aggregate_template();a.method_id=ids{k};a.family=spec.family;a.M=spec.M;a.q=spec.q;a.K=spec.K;a.stability_threshold=spec.stability_threshold;a.set_num=sum([in.set_accuracy_num]);a.set_den=sum([in.set_accuracy_den]);a.set_micro=a.set_num/max(1,a.set_den);a.set_macro=mean([in.set_accuracy_given_covered],'omitnan');a.false_unique_num=sum([in.false_unique_num]);a.false_unique_den=sum([in.false_unique_den]);a.false_unique=a.false_unique_num/max(1,a.false_unique_den);a.struct_num=sum([st.structure_out_false_accept_num]);a.struct_den=sum([st.structure_out_false_accept_den]);a.struct_far=a.struct_num/max(1,a.struct_den);a.param_num=sum([pa.parameter_out_false_accept_num]);a.param_den=sum([pa.parameter_out_false_accept_den]);a.param_far=a.param_num/max(1,a.param_den);a.worst_far=max(a.struct_far,a.param_far);a.reject_rate=1-a.set_micro;aggregate(end+1)=a; %#ok<AGROW>
    end
    m0=aggregate(strcmp({aggregate.family},'M0'));if isempty(m0),error('stage4a5:MissingBaseline','M0 validation result is required.');end;max_fu=m0(1).false_unique;
    families={'M1','M2','M3'};
    for f=1:numel(families)
        family_aggregate=aggregate(strcmp({aggregate.family},families{f}));
        if isempty(family_aggregate),error('stage4a5:MissingFamily','No validation result for method family %s.',families{f});end
        eligible=[family_aggregate.set_micro]>=sc.selection_policy.minimum_inlibrary_micro_set_accuracy & ...
            [family_aggregate.false_unique]<=max_fu+1e-12;
        if ~any(eligible),eligible=true(size(eligible));basis='no candidate met micro set-accuracy constraint; development fallback';
        else,basis='development validation micro set accuracy and worst-case OOL objective';end
        a=family_aggregate(eligible);[~,ix]=min([a.worst_far]);a=a(ix);
        tie=a([a.worst_far]==a(1).worst_far);
        if numel(tie)>1,[~,ix]=max([tie.set_micro]);a=tie(ix);end
        s=selection_template();s.method_id=a.method_id;s.family=a.family;s.M=a.M;s.q=a.q;s.K=a.K;s.stability_threshold=a.stability_threshold;s.selection_basis=basis;s.validation_set_micro=a.set_micro;s.validation_set_macro=a.set_macro;s.validation_worst_ool_false_accept=a.worst_far;s.validation_false_unique=a.false_unique;s.validation_structure_false_accept=a.struct_far;s.validation_parameter_false_accept=a.param_far;s.candidate_count=numel(family_aggregate);selected(end+1)=s; %#ok<AGROW>
    end
end
function s=selection_template(),s=struct('method_id','','family','','M',0,'q',0,'K',0,'stability_threshold',0,'selection_basis','','validation_set_micro',NaN,'validation_set_macro',NaN,'validation_worst_ool_false_accept',NaN,'validation_false_unique',NaN,'validation_structure_false_accept',NaN,'validation_parameter_false_accept',NaN,'candidate_count',0);end
function s=aggregate_template(),s=struct('method_id','','family','','M',0,'q',0,'K',0,'stability_threshold',0,'set_num',0,'set_den',0,'set_micro',NaN,'set_macro',NaN,'false_unique_num',0,'false_unique_den',0,'false_unique',NaN,'struct_num',0,'struct_den',0,'struct_far',NaN,'param_num',0,'param_den',0,'param_far',NaN,'worst_far',NaN,'reject_rate',NaN);end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
