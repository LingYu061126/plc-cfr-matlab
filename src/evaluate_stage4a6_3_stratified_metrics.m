function rows = evaluate_stage4a6_3_stratified_metrics(decisions, labels)
%EVALUATE_STAGE4A6_3_STRATIFIED_METRICS Parameter/severity/direction audit.
%   This is an offline scorer. It joins truth labels only after the
%   truth-free decisions have been produced and does not alter decisions.
    methods = unique({decisions.method_id}, 'stable');
    keys = cell(numel(labels), 1);
    for ik = 1:numel(labels)
        keys{ik} = sprintf('%s\t%s\t%s\t%s', labels(ik).category, ...
            labels(ik).outlier_dimension, labels(ik).outlier_severity, ...
            labels(ik).outlier_direction);
    end
    groups = unique(keys, 'stable');
    rows = repmat(template(), 0, 1);
    for im = 1:numel(methods)
        for ig = 1:numel(groups)
            qg = find(strcmp(keys, groups{ig}), 1);
            g = labels(qg);
            lidx = strcmp({labels.category}, g.category) & strcmp({labels.outlier_dimension}, g.outlier_dimension) & ...
                strcmp({labels.outlier_severity}, g.outlier_severity) & strcmp({labels.outlier_direction}, g.outlier_direction);
            ids = {labels(lidx).sample_id};
            didx = strcmp({decisions.method_id}, methods{im}) & ismember({decisions.sample_id}, ids);
            d = decisions(didx);
            if isempty(d), continue; end
            truth_domain = cell(numel(d), 1);
            for k = 1:numel(d)
                q = find(strcmp({labels.sample_id}, d(k).sample_id), 1);
                truth_domain{k} = labels(q).truth_parameter_domain;
            end
            ood = strcmp(truth_domain, 'out_of_domain');
            out = strcmp({d.parameter_domain_status}, 'parameter_out_suspected').';
            in = strcmp({d.parameter_domain_status}, 'parameter_in_domain').';
            ind = strcmp({d.parameter_domain_status}, 'parameter_domain_indeterminate').' | ...
                strcmp({d.parameter_domain_status}, 'parameter_not_evaluated').';
            r = template();
            r.method_id = methods{im}; r.category = g.category; r.outlier_dimension = g.outlier_dimension;
            r.outlier_severity = g.outlier_severity; r.outlier_direction = g.outlier_direction; r.sample_count = numel(d);
            [r.ood_recall, ci] = rate_ci(sum(ood & out), sum(ood));
            r.ood_out_numerator = sum(ood & out); r.ood_denominator = sum(ood);
            r.ood_ci_low = ci(1); r.ood_ci_high = ci(2);
            [r.ood_false_accept_rate, ci] = rate_ci(sum(ood & in), sum(ood));
            r.ood_false_accept_numerator = sum(ood & in);
            r.ood_false_accept_ci_low = ci(1); r.ood_false_accept_ci_high = ci(2);
            [r.in_domain_false_alarm_rate, ci] = rate_ci(sum(~ood & out), sum(~ood));
            r.in_domain_false_alarm_numerator = sum(~ood & out); r.in_domain_denominator = sum(~ood);
            r.in_domain_ci_low = ci(1); r.in_domain_ci_high = ci(2);
            [r.indeterminate_rate, ci] = rate_ci(sum(ind), numel(d));
            r.indeterminate_numerator = sum(ind); r.indeterminate_ci_low = ci(1); r.indeterminate_ci_high = ci(2);
            [r.decision_coverage, ci] = rate_ci(sum(~ind), numel(d));
            r.decision_coverage_numerator = sum(~ind); r.coverage_ci_low = ci(1); r.coverage_ci_high = ci(2);
            rows(end+1) = r; %#ok<AGROW>
        end
    end
end

function r = template()
    r = struct('method_id', '', 'category', '', 'outlier_dimension', '', ...
        'outlier_severity', '', 'outlier_direction', '', 'sample_count', 0, ...
        'ood_out_numerator', 0, 'ood_denominator', 0, 'ood_recall', NaN, ...
        'ood_ci_low', NaN, 'ood_ci_high', NaN, 'ood_false_accept_numerator', 0, ...
        'ood_false_accept_rate', NaN, 'ood_false_accept_ci_low', NaN, ...
        'ood_false_accept_ci_high', NaN, 'in_domain_false_alarm_numerator', 0, ...
        'in_domain_denominator', 0, 'in_domain_false_alarm_rate', NaN, ...
        'in_domain_ci_low', NaN, 'in_domain_ci_high', NaN, ...
        'indeterminate_numerator', 0, 'indeterminate_rate', NaN, ...
        'indeterminate_ci_low', NaN, 'indeterminate_ci_high', NaN, ...
        'decision_coverage_numerator', 0, 'decision_coverage', NaN, ...
        'coverage_ci_low', NaN, 'coverage_ci_high', NaN);
end

function [p, ci] = rate_ci(a, b)
    if b == 0
        p = NaN; ci = [NaN, NaN];
    else
        p = a / b; ci = stage4a6_3_wilson_interval(a, b);
    end
end
