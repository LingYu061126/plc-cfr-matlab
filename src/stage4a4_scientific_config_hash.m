function [digest, canonical_text] = stage4a4_scientific_config_hash(value)
%STAGE4A4_SCIENTIFIC_CONFIG_HASH SHA-256 hash without machine paths.
%   Runtime locations are deliberately removed before canonicalization so
%   the scientific configuration is portable across checkout directories.
    cleaned = strip_runtime_fields(value);
    [digest, canonical_text] = stage4a2_config_hash(cleaned);
    if numel(digest) ~= 64 || ~isempty(regexp(digest,'[^0-9a-f]','once'))
        error('stage4a4:InvalidScientificHash','SHA-256 digest was not produced.');
    end
end

function out = strip_runtime_fields(value)
    runtime_names = {'root_dir','results_data','results_figures','results_logs', ...
        'cache_dir','cache_file','absolute_path','log_file','output_dir'};
    if isstruct(value)
        out = value;
        fields = fieldnames(value);
        for i = 1:numel(value)
            for k = 1:numel(fields)
                name = fields{k};
                if any(strcmpi(name,runtime_names))
                    out(i).(name) = '<runtime-location-omitted>';
                else
                    out(i).(name) = strip_runtime_fields(value(i).(name));
                end
            end
        end
    elseif iscell(value)
        out = value;
        for k = 1:numel(value), out{k} = strip_runtime_fields(value{k}); end
    else
        out = value;
    end
end
