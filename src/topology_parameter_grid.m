function grid = topology_parameter_grid(search)
%TOPOLOGY_PARAMETER_GRID Cartesian nuisance-parameter grid with regularizer.
%   Search ranges are configuration inputs, not inferred field statistics.
%   The regularizer is the mean squared normalized deviation from nominal.

    names = {'main_length_scale','branch_length_scale','branch_load_scale', ...
        'source_impedance_ohm','receiver_impedance_ohm'};
    for k=1:numel(names)
        if ~isfield(search,names{k}) || isempty(search.(names{k})) || ...
                any(~isfinite(search.(names{k})))
            error('topology_parameter_grid:InvalidRange','Missing/invalid %s.',names{k});
        end
    end
    vectors=cell(1,numel(names));
    for k=1:numel(names)
        value=search.(names{k}); vectors{k}=value(:).';
    end
    [a,b,c,d,e]=ndgrid(vectors{1},vectors{2},vectors{3},vectors{4},vectors{5});
    keep=true(size(a));
    if isfield(search,'couple_line_scales') && logical(search.couple_line_scales)
        keep=abs(a-b)<=10*eps(max(abs([a(:);b(:);1])));
    end
    a=a(keep);b=b(keep);c=c(keep);d=d(keep);e=e(keep);
    count=numel(a);
    template=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'source_impedance_ohm',50, ...
        'receiver_impedance_ohm',50,'regularization',0);
    grid=repmat(template,1,count);
    nominal=[1,1,1,search.nominal_source_impedance_ohm,search.nominal_receiver_impedance_ohm];
    span=[max(abs(vectors{1}-1)),max(abs(vectors{2}-1)),max(abs(vectors{3}-1)), ...
        max(abs(vectors{4}-nominal(4))),max(abs(vectors{5}-nominal(5)))];
    span(span==0)=1;
    for k=1:count
        values=[a(k),b(k),c(k),d(k),e(k)];
        grid(k)=struct('main_length_scale',a(k),'branch_length_scale',b(k), ...
            'branch_load_scale',c(k),'source_impedance_ohm',d(k), ...
            'receiver_impedance_ohm',e(k),'regularization', ...
            mean(((values-nominal)./span).^2));
    end
end
