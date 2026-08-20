function save_cfr_data(filename_base, f_hz, series)
%SAVE_CFR_DATA Save frequency response series as MAT and CSV.
%   series is a struct array with fields name, H_V and H_port. The CSV
%   contains frequency plus magnitude dB and unwrapped phase (degrees) for
%   both normalizations. Complex responses remain available in MAT.

    save([filename_base '.mat'], 'f_hz', 'series');
    fid = fopen([filename_base '.csv'], 'w');
    if fid < 0, error('save_cfr_data:OpenFailed', 'Cannot open CSV output.'); end
    fprintf(fid, 'frequency_hz');
    for k = 1:numel(series)
        safe_name = series(k).name;
        fprintf(fid, ',%s_HV_mag_dB,%s_HV_phase_deg,%s_Hport_mag_dB,%s_Hport_phase_deg', ...
            safe_name, safe_name, safe_name, safe_name);
    end
    fprintf(fid, '\n');
    phase_hv = cell(1, numel(series));
    phase_hp = cell(1, numel(series));
    for k = 1:numel(series)
        phase_hv{k} = unwrap(angle(series(k).H_V)) * 180/pi;
        phase_hp{k} = unwrap(angle(series(k).H_port)) * 180/pi;
    end
    n = numel(f_hz);
    for i = 1:n
        fprintf(fid, '%.17g', f_hz(i));
        for k = 1:numel(series)
            hv = series(k).H_V(i);
            hp = series(k).H_port(i);
            fprintf(fid, ',%.17g,%.17g,%.17g,%.17g', ...
                20*log10(abs(hv)), phase_hv{k}(i), ...
                20*log10(abs(hp)), phase_hp{k}(i));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end
