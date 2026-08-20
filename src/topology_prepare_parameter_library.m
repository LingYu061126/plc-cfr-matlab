function cache = topology_prepare_parameter_library(library)
%TOPOLOGY_PREPARE_PARAMETER_LIBRARY Matrix cache for repeated grid matching.
%   The cached representations are algebraically identical to the scalar
%   feature definitions but avoid rebuilding every template feature for each
%   Monte Carlo observation.

    if isempty(library)
        error('topology_prepare_parameter_library:EmptyLibrary', ...
            'A nonempty parameter library is required.');
    end
    nview=numel(library(1).views); ntemplate=numel(library);
    H=cell(1,nview);amp=cell(1,nview);amp_norm=cell(1,nview);
    complex_norm=cell(1,nview);phase_unwrapped=cell(1,nview);
    for v=1:nview
        nf=numel(library(1).views{v}); H{v}=complex(zeros(ntemplate,nf));
        for k=1:ntemplate
            if numel(library(k).views)~=nview||numel(library(k).views{v})~=nf
                error('topology_prepare_parameter_library:ViewSizeMismatch', ...
                    'All parameter templates must have equal view dimensions.');
            end
            H{v}(k,:)=library(k).views{v}(:).';
        end
        amp{v}=abs(H{v});
        scale=sqrt(sum(amp{v}.^2,2));scale(scale<=realmin)=1;
        amp_norm{v}=amp{v}./scale;
        cscale=sqrt(sum(abs(H{v}).^2,2));cscale(cscale<=realmin)=1;
        complex_norm{v}=H{v}./cscale;
        phase_unwrapped{v}=unwrap(angle(H{v}),[],2);
    end
    cache=struct('is_prepared_parameter_library',true,'items',library, ...
        'topology_indices',[library.topology_index], ...
        'regularization',[library.regularization], ...
        'theta',{{library.theta}},'view_count',nview,'H',{H},'amp',{amp}, ...
        'amp_norm',{amp_norm},'complex_norm',{complex_norm}, ...
        'phase_unwrapped',{phase_unwrapped});
end
