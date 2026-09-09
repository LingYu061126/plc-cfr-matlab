function test_stage4a7_2_r2_1_1_static_integrity()
%TEST_STAGE4A7_2_R2_1_1_STATIC_INTEGRITY Corrective closure tests.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    tmp=[tempname '.bin'];fid=fopen(tmp,'wb');fclose(fid);cleanup=onCleanup(@()delete_if_exists(tmp));
    assert(strcmp(stage4a7_2_r2_sha256_file(tmp),'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),'Empty SHA-256 vector failed.');
    fid=fopen(tmp,'wb');fwrite(fid,uint8('abc'),'uint8');fclose(fid);
    assert(strcmp(stage4a7_2_r2_sha256_file(tmp),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),'abc SHA-256 vector failed.');
    csv=fullfile(root,'data','derived','enwl_uncertain_prior','stage4a7_2_r1_selected_public_subnetwork.csv');
    if exist(csv,'file')
        assert(strcmp(stage4a7_2_r2_sha256_file(csv),'b1796a9a0cf7ae94f66b58a9e12de2ff21debd371f68e2fe2085e7b42a057f20'),'Derived CSV SHA-256 mismatch.');
        [st,out]=system(['/usr/bin/sha256sum ' shell_quote(csv)]);assert(st==0&&startsWith(strtrim(out),'b1796a9a0cf7ae94f66b58a9e12de2ff21debd371f68e2fe2085e7b42a057f20'),'System and MATLAB digest differ.');
    else
        error('stage4a7_2_r2_1_1:MissingDerivedCSV','Expected derived CSV is missing.');
    end
    assert(stage4a7_2_r2_compare_text('a','b')<0&&stage4a7_2_r2_compare_text('b','a')>0&&stage4a7_2_r2_compare_text('a','a')==0,'Text comparator is not three-way.');

    ref=synthetic_reference();sc=struct('synthetic_ambiguity_edges',{{'J1','J2'}},'add_controlled_ambiguity_edges',true,'synthetic_ambiguity_prior_cost',1,'observed_default_prior_cost',1,'forward_model_default_terminal_load_ohm',50);
    [ledger,audit]=stage4a7_2_r2_1_build_benchmark_ledger(ref,sc,'incorrect_required_edge',17);
    ix=find(strcmp({ledger.edge_confidence},'independently_observed_required_but_incorrect'),1);
    assert(~isempty(ix)&&strcmp(ledger(ix).edge_status,'required'),'Incorrect required edge was not generated.');
    assert(~any(strcmp({ref.edges.id},ledger(ix).edge_id))&&~audit.incorrect_required_edge_is_reference,'Incorrect required edge leaked reference edge.');
    [sp,da]=stage4a7_2_r2_1_build_deployment_spec(ledger,struct('source_node_id','TX','receiver_node_id','RX','maximum_degree',4,'maximum_candidate_count',100));
    assert(~da.truth_input_received&&isfield(sp,'prior_config_hash'),'Deployment adapter received truth or missed prior hash.');

    sc2=struct('alpha',.05,'method_selection',struct('method_ids',{{'absolute','scaled','ratio','margin','absolute_I'}},'coverage_gate',0,'tie_tolerance',1e-12,'bootstrap_replicates',200,'bootstrap_seed',20262941,'bootstrap_pair_ids',{{'margin','ratio'}}),'scenario_design',struct('calibration_per_candidate',2),'profile',struct('resolution_floor',1e-10));
    d=[0.1 0.2;0.2 0.1;0.3 0.4;0.4 0.3;0.2 0.3;0.3 0.2;0.5 0.6;0.6 0.5];ids={'G1','G2'};truth={'G1';'G2';'G1';'G2';'G1';'G2';'G1';'G2'};
    [~,rows,~,manifest]=stage4a7_2_r2_calibrated_method_selection(d,truth,d,truth,ids,sc2,'compat-test');
    assert(isfield(manifest,'bootstrap_comparisons')&&~isempty(manifest.bootstrap_comparisons),'Bootstrap comparison was not produced.');
    assert(isfield(rows,'deterministic_development_winner')&&isfield(rows,'statistically_distinguishable_winner'),'Method identity fields missing.');
    assert(~manifest.scientifically_unique_winner || manifest.statistically_distinguishable_winner,'Scientific uniqueness bypassed bootstrap gate.');
    fprintf('  PASS Stage 4A.7.2-R.2.1.1 static integrity, SHA vectors, ledger isolation, comparator and method bootstrap\n');
end

function r=synthetic_reference()
e(1)=struct('id','E1','from','TX','to','J1','length_m',10,'cable_type',0);e(2)=struct('id','E2','from','J1','to','RX','length_m',12,'cable_type',0);r=struct('edges',e,'node_ids',{{'TX','J1','RX'}},'source_node_id','TX','receiver_node_id','RX','source_table',struct('source_dataset','test','source_network_id','N','source_feeder_id','F'));
end
function q=shell_quote(x),sq=char(39);q=[sq strrep(x,sq,[sq '"' sq '"' sq]) sq];end
function delete_if_exists(p),if exist(p,'file'),delete(p);end,end
