function out = analyze_parameter_identifiability(jacobian)
%ANALYZE_PARAMETER_IDENTIFIABILITY Local practical-identifiability audit.
    J=jacobian.J;[~,S,V]=svd(J,'econ');sv=diag(S);tol=max(size(J))*eps(max(sv));rank_eff=sum(sv>tol);condv=Inf;if ~isempty(sv)&&sv(end)>tol,condv=sv(1)/sv(end);end
    norms=sqrt(sum(abs(J).^2,1));C=corrcoef(real(J));if any(~isfinite(C(:))),C=eye(size(J,2));end
    out=struct('singular_values',sv(:).','condition_number',condv,'effective_rank',rank_eff,'right_singular_vectors',V,'parameter_correlation',C,'sensitivity_norms',norms,'low_sensitivity',norms<0.05*max(norms),'interpretation','local normalized finite-difference audit; not global identifiability proof');
end
