function bank = generate_stage4a6_1_trial_bank(sc, split_kind)
%GENERATE_STAGE4A6_1_TRIAL_BANK Stable wrapper for the split protocol.
    if nargin < 2, split_kind = 'all'; end
    bank = generate_stage4a6_trial_bank(sc, split_kind);
    ids = {bank.sample_id};
    if numel(unique(ids)) ~= numel(ids)
        error('stage4a6_1:DuplicateSampleID','Trial-bank sample IDs are not unique.');
    end
end
