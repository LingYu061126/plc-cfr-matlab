function [design,manifest] = build_frozen_resampling_masks(grid,replicate_ids,sc,scientific_hash)
%BUILD_FROZEN_RESAMPLING_MASKS Common masks per grid/replicate/bootstrap.
    f=grid.frequency_hz(:).';nf=numel(f);B=sc.bootstrap_repetitions;nb=sc.block_count;len=max(1,min(nf,round(nf*sc.block_fraction)));
    replicate_ids=unique(replicate_ids,'stable');design=repmat(struct('grid_id','','replicate_id','','masks',false(0,nf),'seed',0),numel(replicate_ids),1);manifest=repmat(row(),0,1);
    grid_code=sum(double(grid.id).*(1:numel(grid.id)));old=rng;cleanup=onCleanup(@()rng(old));
    for r=1:numel(replicate_ids)
        seed=sc.resampling_base_seed+grid_code+1000*r;rng(seed,'twister');masks=false(B,nf);
        for b=1:B
            for j=1:nb
                st=1+floor(rand*max(1,nf-len+1));en=min(nf,st+len-1);masks(b,st:en)=true;
                z=row();z.grid_id=grid.id;z.replicate_id=replicate_ids{r};z.bootstrap_index=b;z.block_index=j;z.block_start=st;z.block_end=en;z.frequency_count=en-st+1;z.resampling_seed=seed;z.experiment_scientific_hash=scientific_hash;manifest(end+1)=z; %#ok<AGROW>
            end
        end
        design(r)=struct('grid_id',grid.id,'replicate_id',replicate_ids{r},'masks',masks,'seed',seed);
    end
end
function r=row(),r=struct('grid_id','','replicate_id','','bootstrap_index',0,'block_index',0,'block_start',0,'block_end',0,'frequency_count',0,'resampling_seed',0,'experiment_scientific_hash','');end
