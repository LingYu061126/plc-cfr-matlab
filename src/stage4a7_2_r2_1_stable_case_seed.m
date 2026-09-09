function seed=stage4a7_2_r2_1_stable_case_seed(master_seed,sample_id)
%STAGE4A7_2_R2_1_STABLE_CASE_SEED Order-independent deterministic seed.
    txt=[sprintf('%u|',uint64(master_seed)) char(sample_id)];u=double(uint8(txt));
    h=uint64(2166136261);for k=1:numel(u),h=bitxor(h,uint64(u(k)));h=mod(h*uint64(16777619),uint64(2147483647));end
    seed=double(mod(h,uint64(2147483646))+1);
end
