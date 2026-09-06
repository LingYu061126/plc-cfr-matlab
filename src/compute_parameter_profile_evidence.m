function out = compute_parameter_profile_evidence(in_result,ext_result,domain)
%COMPUTE_PARAMETER_PROFILE_EVIDENCE Compare in-domain and extended fits.
    d1=in_result.distance;d2=ext_result.distance;lambda=d1^2-d2^2;relative=(d1-d2)/(d1+1e-12);x=ext_result.theta_vector;
    outside=x<domain.in_lower-1e-10|x>domain.in_upper+1e-10;shift=(x-in_result.theta_vector)./(domain.in_upper-domain.in_lower);
    out=struct('lambda',lambda,'relative_improvement',relative,'extended_theta_outside_original_domain',outside,'any_extended_parameter_outside',any(outside),'normalized_parameter_shift',shift);
end
