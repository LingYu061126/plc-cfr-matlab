function test_stage4a6_2_resume()
%TEST_STAGE4A6_2_RESUME A completed shard is accepted only with matching hashes.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    folder=tempname;mkdir(folder);path=fullfile(folder,'case001.mat');
    shard=struct('case_id','case001','scientific_hash','science','source_tree_hash','source', ...
        'status','completed','exit_status',0,'parameter_name','main_length_scale', ...
        'profile_summary',struct([]),'started_at','','finished_at','','runtime_s',0, ...
        'optimizer_state',struct(),'error_identifier','','error_message','','checksum','');
    save_stage4a6_2_shard_atomic(shard,path,struct('case_id','case001','scientific_hash','science','source_tree_hash','source','parameter_name','main_length_scale'));
    z=load(path,'shard');[ok,reason]=validate_stage4a6_2_shard(z.shard,struct('case_id','case001','scientific_hash','science','source_tree_hash','source','parameter_name','main_length_scale'));
    assert(ok,['Saved shard failed validation: ' reason]);
    [bad,~]=validate_stage4a6_2_shard(z.shard,struct('case_id','case001','scientific_hash','other','source_tree_hash','source','parameter_name','main_length_scale'));
    assert(~bad,'Mismatched scientific hash was accepted.');
    fprintf('ALL STAGE-4A.6.2 RESUME/HASH TESTS PASSED\n');
end
