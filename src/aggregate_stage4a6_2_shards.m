function out = aggregate_stage4a6_2_shards(case_manifest, context, varargin)
%AGGREGATE_STAGE4A6_2_SHARDS Validate and aggregate completed shards.
    p=inputParser;p.addParameter('allow_failed',false);p.parse(varargin{:});
    ids={case_manifest.case_id};if numel(unique(ids))~=numel(ids),error('stage4a6_2:DuplicateCase','Duplicate case_id.');end
    out=struct('total',numel(case_manifest),'completed',0,'failed',0,'pending',0,'duplicate',0,'missing',0,'shards',struct([]));
    shards=repmat(struct(),0,1);
    for k=1:numel(case_manifest)
        c=case_manifest(k);path=resolve_path(c.expected_output_path,context);expected=struct('case_id',c.case_id,'scientific_hash',context.scientific_hash,'source_tree_hash',context.source_tree_hash,'parameter_name',getfield_default(c,'parameter_name',''));
        if ~exist(path,'file'),out.missing=out.missing+1;continue;end
        z=load(path,'shard');if ~isfield(z,'shard'),out.failed=out.failed+1;continue;end
        [ok,reason]=validate_stage4a6_2_shard(z.shard,expected,'allow_failed',true);
        if ok && strcmp(z.shard.status,'completed'),out.completed=out.completed+1;if isempty(shards),shards=repmat(z.shard,0,1);end;shards(end+1)=z.shard; %#ok<AGROW>
        elseif ok && strcmp(z.shard.status,'failed'),out.failed=out.failed+1;if ~p.Results.allow_failed,error('stage4a6_2:FailedShard','%s: failed shard',c.case_id);end
        else,out.failed=out.failed+1;if ~p.Results.allow_failed,error('stage4a6_2:InvalidShard','%s: %s',c.case_id,reason);end,end
    end
    out.pending=out.missing+out.failed;out.shards=shards;
end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
function path=resolve_path(path,context),if ~isempty(regexp(char(path),'^(\/|[A-Za-z]:[\\/])','once')),return;end;path=fullfile(context.root_dir,char(path));end
