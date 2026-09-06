function seed = stage4a6_2_case_seed(master_seed, varargin)
%STAGE4A6_2_CASE_SEED Deterministic seed independent of execution order.
    text = sprintf('%d|Stage4A6.2', master_seed);
    for k = 1:numel(varargin)
        value = varargin{k};
        if isnumeric(value)
            text = [text '|' mat2str(value)]; %#ok<AGROW>
        else
            text = [text '|' char(value)]; %#ok<AGROW>
        end
    end
    bytes = uint8(text);
    acc = uint64(2166136261);
    for k = 1:numel(bytes)
        acc = bitxor(acc, uint64(bytes(k)));
        acc = mod(acc * uint64(16777619), uint64(2^32));
    end
    seed = double(mod(acc, uint64(2^31-2))) + 1;
end
