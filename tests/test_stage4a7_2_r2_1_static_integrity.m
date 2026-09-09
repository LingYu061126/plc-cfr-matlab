function test_stage4a7_2_r2_1_static_integrity()
%TEST_STAGE4A7_2_R2_1_STATIC_INTEGRITY Lightweight protocol regression checks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));base=default_config(root);
    f1=[tempname '.bin'];f2=[tempname '.bin'];fid=fopen(f1,'wb');fclose(fid);fid=fopen(f2,'wb');fwrite(fid,uint8('abc'),'uint8');fclose(fid);
    c=onCleanup(@()cleanup_files({f1,f2})); %#ok<NASGU>
    assert(strcmp(stage4a7_2_r2_sha256_file(f1),'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    assert(strcmp(stage4a7_2_r2_sha256_file(f2),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
    p=fullfile(root,'data','derived','enwl_uncertain_prior','stage4a7_2_r1_selected_public_subnetwork.csv');
    assert(strcmp(stage4a7_2_r2_sha256_file(p),'b1796a9a0cf7ae94f66b58a9e12de2ff21debd371f68e2fe2085e7b42a057f20'));
    assert(stage4a7_2_r2_compare_text('A','B')<0 && stage4a7_2_r2_compare_text('B','A')>0 && stage4a7_2_r2_compare_text('A','A')==0);
    assert(stage4a7_2_r2_1_stable_case_seed(11,'x')==stage4a7_2_r2_1_stable_case_seed(11,'x'));
    assert(stage4a7_2_r2_1_stable_case_seed(11,'x')~=stage4a7_2_r2_1_stable_case_seed(11,'y'));
    smoke=stage4a7_2_r2_1_protocol_config(base,'smoke');formal=stage4a7_2_r2_1_protocol_config(base,'formal');
    assert(~strcmp(stage4a4_scientific_config_hash(smoke),stage4a4_scientific_config_hash(formal)));
    f=stage4a7_2_r1_profile_score_families([1 2 3],[],NaN);assert(all(isfinite(f.absolute_I(:)))&&f.resolution==eps);
    e=struct('id',{'a','b'},'from',{'N1','N2'},'to',{'N2','N1'},'kind',{'line','line'},'length_m',{1,2},'cable_type',{0,0},'load',{50,50},'prior_cost',{1,1});
    s=struct('node_ids',{{'N1','N2'}},'allowed_edges',e);assert(throws_id(@()normalize_engineering_candidate_spec(s),'stage4a7_2:ConflictingDuplicateEdgeAttributes'));
    [led,a]=stage4a7_2_r2_1_build_benchmark_ledger(struct('edges',e(1),'source_node_id','N1','receiver_node_id','N2','source_table',struct('source_dataset','test','source_network_id','n','source_feeder_id','f')),smoke,'nominal',1); %#ok<ASGLU>
    [~,da]=stage4a7_2_r2_1_build_deployment_spec(led,smoke);assert(~da.truth_input_received);
    d=repmat(struct('empty',false,'hit',false,'set_size',1,'calibration_hash','h'),3,1);d(1).hit=true;d(2).empty=true;d(2).set_size=0;d(3).set_size=2;
    pm=stage4a7_2_r2_1_evaluate_pilot_metrics(d,'e');ix=find(strcmp({pm.metric_id},'topology_selective_risk'),1);assert(pm(ix).numerator==1&&pm(ix).denominator==2);
    fprintf('  PASS Stage 4A.7.2-R.2.1 SHA, identity, comparator, seed, resolution and deployment isolation checks\n');
end
function tf=throws_id(fun,id),tf=false;try,fun();catch ME,tf=strcmp(ME.identifier,id);end,end
function cleanup_files(ps),for k=1:numel(ps),if exist(ps{k},'file'),delete(ps{k});end,end,end
