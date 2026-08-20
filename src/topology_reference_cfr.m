function references = topology_reference_cfr(f_hz, candidates, cfg)
%TOPOLOGY_REFERENCE_CFR Generate stable reference CFR for each candidate.
%   The stage-1.5 cascade_network_stable function is the only physical
%   channel evaluator used here. No OFDM-specific transmission-line model
%   is duplicated.

    if isempty(candidates)
        references = candidates;
        return;
    end
    references = candidates;
    for k = 1:numel(candidates)
        [H, details] = cascade_network_stable(f_hz, candidates(k).network, cfg);
        references(k).reference_H = H.H_port(:).';
        references(k).reference_details = details;
    end
end
