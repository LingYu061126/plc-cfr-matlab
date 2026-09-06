function summary = run_stage4a6_2_batch(case_manifest, context, execution)
%RUN_STAGE4A6_2_BATCH Unified serial checkpoint/resume runner.
%   Manifest paths are repository-relative and resolved with context.root_dir.
%   Both successful and failed attempts are atomically persisted.
    if nargin<3||isempty(execution),execution=struct();end
    if isempty(case_manifest),summary=empty_summary();return;end
    ids={case_manifest.case_id};
    if numel(unique(ids))~=numel(ids),error('stage4a6_2:DuplicateCase','Duplicate case_id in manifest.');end
    summary=empty_summary();summary.total=numel(case_manifest);
    results=repmat(struct('case_id','','status','','path','','reason',''),numel(case_manifest),1);
    for k=1:numel(case_manifest)
        c=case_manifest(k);path=resolve_path(c.expected_output_path,context);expected=expected_identity(c,context);
        prior=load_existing(path,expected);
        if getfield_default(execution,'resume',true) && ~getfield_default(execution,'overwrite_completed',false) && prior.valid && strcmp(prior.shard.status,'completed')
            summary.resumed=summary.resumed+1;results(k)=row(c.case_id,'resumed',path,'');continue;
        end
        if prior.valid && strcmp(prior.shard.status,'failed') && ~getfield_default(execution,'retry_failed',false) && ~getfield_default(execution,'overwrite_completed',false)
            summary.failed=summary.failed+1;results(k)=row(c.case_id,'failed_existing',path,'retry_disabled');continue;
        end
        if prior.exists && ~prior.valid && getfield_default(execution,'resume',true),summary.hash_mismatch=summary.hash_mismatch+1;end
        attempt=1;history=struct([]);
        if prior.valid
            attempt=getfield_default(prior.shard,'attempt_count',0)+1;
            history=getfield_default(prior.shard,'attempt_history',struct([]));
            history_entry=attempt_record(prior.shard);
            if isempty(history),history=history_entry;else,history(end+1)=history_entry;end %#ok<AGROW>
        end
        c.attempt_count=attempt;c.retry_count=max(attempt-1,0);c.attempt_history=history;
        case_context=context;
        if isfield(context,'case_contexts') && numel(context.case_contexts)>=k,case_context=context.case_contexts{k};end
        shard=run_stage4a6_2_case(c,case_context);summary.attempted=summary.attempted+1;summary.retry_count=summary.retry_count+(attempt>1);
        save_stage4a6_2_shard_atomic(shard,path,expected);
        if shard.exit_status==0
            summary.completed=summary.completed+1;results(k)=row(c.case_id,'completed',path,'');
        else
            summary.failed=summary.failed+1;results(k)=row(c.case_id,'failed',path,shard.error_identifier);
        end
    end
    summary.pending=summary.total-summary.completed-summary.failed-summary.resumed;summary.results=results;
end
function summary=empty_summary(),summary=struct('total',0,'attempted',0,'completed',0,'failed',0,'pending',0,'resumed',0,'retry_count',0,'hash_mismatch',0,'results',struct([]));end
function r=row(id,status,path,reason),r=struct('case_id',id,'status',status,'path',path,'reason',reason);end
function expected=expected_identity(c,context),expected=struct('case_id',c.case_id,'scientific_hash',context.scientific_hash,'source_tree_hash',context.source_tree_hash,'parameter_name',getfield_default(c,'parameter_name',''));end
function path=resolve_path(path,context),if isempty(path),error('stage4a6_2:MissingOutputPath','Manifest output path is empty.');end;if is_absolute_path(path),path=char(path);else,path=fullfile(context.root_dir,char(path));end,end
function tf=is_absolute_path(path),tf=~isempty(regexp(char(path),'^(\/|[A-Za-z]:[\\/])','once'));end
function loaded=load_existing(path,expected)
    loaded=struct('exists',exist(path,'file')==2,'valid',false,'shard',struct(),'reason','');if ~loaded.exists,return;end
    try,z=load(path,'shard');if ~isfield(z,'shard'),loaded.reason='missing_shard_variable';return;end;loaded.shard=z.shard;[loaded.valid,loaded.reason]=validate_stage4a6_2_shard(z.shard,expected,'allow_failed',true);catch err,loaded.reason=err.identifier;end
end
function h=attempt_record(s),h=struct('status',getfield_default(s,'status',''),'exit_status',getfield_default(s,'exit_status',NaN),'started_at',getfield_default(s,'started_at',''),'finished_at',getfield_default(s,'finished_at',''),'runtime_s',getfield_default(s,'runtime_s',NaN),'error_identifier',getfield_default(s,'error_identifier',''),'error_message',getfield_default(s,'error_message',''));end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
