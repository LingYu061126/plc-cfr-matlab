function [sets, rows] = stage4a5_make_subbands(frequency_hz, count, grid_id, hash)
%STAGE4A5_MAKE_SUBBANDS Split an ordered frequency grid into contiguous bands.
    f=frequency_hz(:).';n=numel(f);if count<1||count>n||count~=floor(count),error('stage4a5:InvalidSubbandCount','Invalid subband count.');end
    edges=round(linspace(0,n,count+1));sets=cell(1,count);rows=repmat(struct('grid_id','','subband_id',0,'start_index',0,'end_index',0,'start_frequency_hz',NaN,'end_frequency_hz',NaN,'frequency_count',0,'configuration_hash',''),count,1);
    for k=1:count,ix=(edges(k)+1):edges(k+1);sets{k}=ix;rows(k)=struct('grid_id',grid_id,'subband_id',k,'start_index',ix(1),'end_index',ix(end),'start_frequency_hz',f(ix(1)),'end_frequency_hz',f(ix(end)),'frequency_count',numel(ix),'configuration_hash',hash);end
end
