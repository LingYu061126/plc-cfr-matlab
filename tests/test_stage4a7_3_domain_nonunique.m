function test_stage4a7_3_domain_nonunique()
%TEST_STAGE4A7_3_DOMAIN_NONUNIQUE Stable-forward T3/T5 positive control.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);cfg.frequency_hz=linspace(2e6,30e6,61);c=topology_candidates(cfg);i3=find(strcmp({c.id},'T3'));i5=find(strcmp({c.id},'T5'));
    h=topology_reference_cfr(cfg.frequency_hz,c([i3 i5]),cfg);
    assert(max(abs(h(1).reference_H-h(2).reference_H))<=1e-10,'T3/T5 positive control is not numerically equivalent.');
    assert(~isequal({c(i3).edge_labels},{c(i5).edge_labels}),'Nonunique control must contain distinct graph structures.');
    sc=stage4a7_3_domain_validation_config(cfg,'smoke');assert(sc.parameter_domain.near_lower<sc.parameter_domain.lower&&sc.parameter_domain.near_upper>sc.parameter_domain.upper,'Two-sided OOD settings are invalid.');
    assert(isinf(sc.nonunique.noise_levels_db(1))&&numel(sc.nonunique.noise_levels_db)>=3,'Nonunique test lacks noiseless plus two noise levels.');
    fprintf('  PASS Stage 4A.7.3 two-sided OOD configuration and T3/T5 numerical-equivalence control\n');
end
