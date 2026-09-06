function out = aggregate_stage4a6_2_shards(case_manifest, context, varargin)
%AGGREGATE_STAGE4A6_2_SHARDS Validate and aggregate completed shards.
    p=inputParser;p.addParameter('allow_failed',false);p.parse(varargin{:});
    ids={case_manifest.case_id};if numel(unique(ids))~=numel(ids),error('stage4a6_2:DuplicateCase','Duplicate case_id.');end
    out=struct('total',numel(case_manifest),'completed',0,'failed',0,'pending',0,'duplicate',0,'missing',0,'shards',struct([]));
    shards=repmat(struct(),0,1);
    for k=1:numel(case_manifest)
        c=case_manifest(k);path=c.expected_output_path;expected=struct('case_id',c.case_id,'scientific_hash',context.scientific_hash,'source_tree_hash',context.source_tree_hash,'parameter_name',getfield_default(c,'parameter_name',''));
        if ~exist(path,'file'),out.missing=out.missing+1;continue;end
        z=load(path,'shard');if ~isfield(z,'shard'),out.failed=out.failed+1;continue;end
        [ok,reason]=validate_stage4a6_2_shard(z.shard,expected);if ok,out.completed=out.completed+1;shards(end+1)=z.shard; %#ok<AGROW>
        else,out.failed=out.failed+1;if ~p.Results.allow_failed,error('stage4a6_2:InvalidShard','%s: %s',c.case_id,reason);end,end
    end
    out.pending=out.missing+out.failed;out.shards=shards;
end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
