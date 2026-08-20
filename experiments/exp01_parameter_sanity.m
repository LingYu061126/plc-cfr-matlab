function exp01_parameter_sanity(cfg)
%EXP01_PARAMETER_SANITY Check units, nominal impedances and 10 MHz RLGC.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    f10 = 10e6;
    c0 = cable_parameters(0);
    c1 = cable_parameters(1);
    [R0, ~, G0] = cable_rlgc(f10, c0, 5, false);
    [R1, ~, G1] = cable_rlgc(f10, c1, 5, false);
    zcalc0 = sqrt(c0.L_uH_per_m*1e-6/(c0.C_pF_per_m*1e-12));
    zcalc1 = sqrt(c1.L_uH_per_m*1e-6/(c1.C_pF_per_m*1e-12));
    fprintf('EXP01 参数自检 / parameter sanity\n');
    fprintf('  cable 0 sqrt(L/C)=%.8f ohm (nominal %.2f)\n', zcalc0, c0.Z0_nominal_ohm);
    fprintf('  cable 1 sqrt(L/C)=%.8f ohm (nominal %.2f)\n', zcalc1, c1.Z0_nominal_ohm);
    fprintf('  10 MHz, kG=5: cable 0 R=%.8g ohm/m, G=%.8g S/m\n', R0, G0);
    fprintf('  10 MHz, kG=5: cable 1 R=%.8g ohm/m, G=%.8g S/m\n', R1, G1);
    rows = [zcalc0, c0.Z0_nominal_ohm, R0, G0; zcalc1, c1.Z0_nominal_ohm, R1, G1];
    fid = fopen(fullfile(cfg.results_data, 'exp01_parameter_sanity.csv'), 'w');
    fprintf(fid, 'cable_type,sqrt_L_over_C_ohm,Z0_nominal_ohm,R_10MHz_ohm_per_m,G_10MHz_S_per_m\n');
    fprintf(fid, '0,%.17g,%.17g,%.17g,%.17g\n', rows(1,:));
    fprintf(fid, '1,%.17g,%.17g,%.17g,%.17g\n', rows(2,:));
    fclose(fid);
end
