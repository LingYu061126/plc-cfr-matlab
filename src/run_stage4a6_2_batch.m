function summary = run_stage4a6_2_batch(case_manifest, context, execution)
%RUN_STAGE4A6_2_BATCH Run independent cases with checkpoint/resume.
%   Completed, hash-matching shards are skipped. Incomplete or mismatched
%   shards are never silently counted as completed.

    if nargin < 3, execution=struct(); end
    if isempty(case_manifest), summary=empty_summary();return;end
    ids={case_manifest.case_id};if numel(unique(ids))~=numel(ids),error('stage4a6_2:DuplicateCase','Duplicate case_id in manifest.');end
    summary=empty_summary();summary.total=numel(case_manifest);results=repmat(struct('case_id','','status','','path','','reason',''),numel(case_manifest),1);
    for k=1:numel(case_manifest)
        c=case_manifest(k);path=getfield_default(c,'expected_output_path','');expected=struct('case_id',c.case_id,'scientific_hash',context.scientific_hash,'source_tree_hash',context.source_tree_hash,'parameter_name',getfield_default(c,'parameter_name',''));
        reused=false;
        if getfield_default(execution,'resume',true)&&~getfield_default(execution,'overwrite_completed',false)&&exist(path,'file')
            loaded=load(path,'shard');if isfield(loaded,'shard'),[ok,reason]=validate_stage4a6_2_shard(loaded.shard,expected);else,ok=false;reason='missing_shard_variable';end
            if ok,reused=true;summary.resumed=summary.resumed+1;results(k)=row(c.case_id,'resumed',path,'');else,summary.hash_mismatch=summary.hash_mismatch+strcmp(reason,'identity_mismatch_scientific_hash');end
        end
        if reused,continue;end
        if exist(path,'file')&&~getfield_default(execution,'retry_failed',false)&&~getfield_default(execution,'overwrite_completed',false)
            loaded=load(path,'shard');if isfield(loaded,'shard')&&strcmp(getfield_default(loaded.shard,'status',''),'failed'),summary.failed=summary.failed+1;results(k)=row(c.case_id,'failed_existing',path,'retry_disabled');continue;end
        end
        shard=run_stage4a6_2_case(c,context);summary.attempted=summary.attempted+1;
        if shard.exit_status==0
            save_stage4a6_2_shard_atomic(shard,path,expected);summary.completed=summary.completed+1;results(k)=row(c.case_id,'completed',path,'');
        else
            results(k)=row(c.case_id,'failed',path,shard.error_identifier);summary.failed=summary.failed+1;
        end
    end
    summary.pending=summary.total-summary.completed-summary.failed-summary.resumed;
    summary.results=results;
end
function s=empty_summary(),s=struct('total',0,'attempted',0,'completed',0,'failed',0,'pending',0,'resumed',0,'retry_count',0,'hash_mismatch',0,'results',struct([]));end
function r=row(id,status,path,reason),r=struct('case_id',id,'status',status,'path',path,'reason',reason);end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
