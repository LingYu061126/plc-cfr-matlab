function audit = topology_observability_classes(reference_views, candidates, ofdm_cfg, tie_tolerance)
%TOPOLOGY_OBSERVABILITY_CLASSES Configuration-specific CFR equivalence classes.
%   reference_views{k} is the complete-network CFR-view cell array for
%   candidate k under one fixed measurement configuration and parameter
%   setting.  Equivalence is defined from the full complex CFR, not from a
%   classifier tie-break: candidates joined by a distance no larger than
%   tie_tolerance form a connected observability class.

    if nargin < 4 || isempty(tie_tolerance), tie_tolerance = 1e-10; end
    if ~(isscalar(tie_tolerance) && isreal(tie_tolerance) && ...
            isfinite(tie_tolerance) && tie_tolerance >= 0)
        error('topology_observability_classes:InvalidTolerance', ...
            'tie_tolerance must be a finite nonnegative scalar.');
    end
    if ~iscell(reference_views) || isempty(reference_views) || ...
            numel(reference_views) ~= numel(candidates)
        error('topology_observability_classes:SizeMismatch', ...
            'One nonempty view bundle is required per candidate.');
    end
    n = numel(candidates);
    pairwise = zeros(n);
    for i = 1:n
        assert_view_bundle(reference_views{i}, 'reference_views');
        for j = i+1:n
            assert_view_bundle(reference_views{j}, 'reference_views');
            if numel(reference_views{i}) ~= numel(reference_views{j})
                error('topology_observability_classes:ViewCountMismatch', ...
                    'Every candidate must have the same view count.');
            end
            per_view = zeros(1, numel(reference_views{i}));
            for v = 1:numel(per_view)
                per_view(v) = topology_feature_distance(reference_views{i}{v}, ...
                    reference_views{j}{v}, 'complex', ofdm_cfg, [0.5,0.5]);
            end
            pairwise(i,j) = sqrt(mean(per_view.^2));
            pairwise(j,i) = pairwise(i,j);
        end
    end
    adjacent = pairwise <= tie_tolerance;
    adjacent(1:n+1:end) = true;
    class_index = connected_components(adjacent);
    nclass = max(class_index);
    labels = cell(1,n); members = cell(1,nclass); class_sizes = zeros(1,nclass);
    for c = 1:nclass
        member_index = find(class_index == c);
        members{c} = member_index;
        class_sizes(c) = numel(member_index);
        ids = {candidates(member_index).id};
        label = ['{' strjoin(ids, ',') '}'];
        labels(member_index) = {label};
    end
    audit = struct('pairwise_complex_distance', pairwise, ...
        'equivalent_pair_mask', adjacent & ~eye(n), ...
        'class_index', class_index, 'class_labels', {labels}, ...
        'class_members', {members}, 'class_sizes', class_sizes, ...
        'structural_indistinguishable_group_count', sum(class_sizes > 1), ...
        'tie_tolerance', tie_tolerance, 'view_count', numel(reference_views{1}), ...
        'definition', ['full-complex-CFR distances at fixed physical configuration; ' ...
            'not a numerical classifier tie statistic']);
end

function assert_view_bundle(bundle, name)
    if ~iscell(bundle) || isempty(bundle)
        error('topology_observability_classes:InvalidViews', ...
            '%s must contain a nonempty cell array of CFR views.', name);
    end
    for v = 1:numel(bundle)
        x = bundle{v};
        if ~isnumeric(x) || isempty(x) || any(~isfinite(x(:)))
            error('topology_observability_classes:InvalidViews', ...
                'All CFR views must be nonempty finite numeric vectors.');
        end
    end
end

function component = connected_components(adjacent)
    n = size(adjacent,1); component = zeros(1,n); count = 0;
    for start = 1:n
        if component(start) ~= 0, continue; end
        count = count + 1; stack = start; component(start) = count;
        while ~isempty(stack)
            current = stack(end); stack(end) = [];
            neighbours = find(adjacent(current,:) & component == 0);
            component(neighbours) = count;
            stack = [stack neighbours]; %#ok<AGROW>
        end
    end
end
