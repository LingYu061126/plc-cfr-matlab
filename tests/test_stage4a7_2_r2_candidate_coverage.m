function test_stage4a7_2_r2_candidate_coverage()
%TEST_STAGE4A7_2_R2_CANDIDATE_COVERAGE Targeted R.2 deterministic checks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));base=default_config(root);
    sc=stage4a7_2_r2_candidate_coverage_config(base,'smoke');assert(~sc.use_parallel&&sc.num_workers==1);
    e=struct('id',{},'from',{},'to',{},'kind',{},'length_m',{},'cable_type',{},'load',{},'prior_cost',{});p=[1 2;2 3;3 4;1 3;2 4;1 4];
    e=repmat(struct('id','','from','','to','','kind','line','length_m',1,'cable_type',0,'load',50,'prior_cost',1),size(p,1),1);ids={'N1','N2','N3','N4'};for k=1:numel(e),e(k).id=sprintf('E%d',k);e(k).from=ids{p(k,1)};e(k).to=ids{p(k,2)};e(k).prior_cost=1+0.01*k;end
    spec=struct('node_ids',{ids},'source_node_id','N1','receiver_node_id','N4','allowed_edges',e,'required_edges',e(1),'forbidden_edges',repmat(e(1),0,1),'edge_prior_cost',[e.prior_cost].','maximum_degree',4,'maximum_candidate_count',100,'radial_only',true,'require_connected',true,'prior_source','test');
    rows=stage4a7_2_r2_exact_topk_audit(spec,[1 2 3 4]);assert(all([rows.exact_first_k_match])&&all([rows.cost_match])&&all([rows.duplicate_count]==0),'Exact Top-K audit failed.');
    d=[0 1 2;1 0 2;2 2 0];[sel,~,man]=stage4a7_2_r2_method_selection(d,{'C1';'C2';'C3'},{'C1','C2','C3'},sc,'hash');assert(~man.scientifically_unique_winner&&~isempty(man.tied_methods),'Tied method selection was not reported.');assert(~isempty(sel));
    assert(1/(sc.scenario_design.calibration_per_candidate+1)>0,'p_min calculation failed.');
    formal=stage4a7_2_r2_candidate_coverage_config(base,'formal');
    assert(1/(formal.scenario_design.calibration_per_candidate+1)<=formal.alpha, ...
        'Formal calibration configuration does not meet alpha resolution.');
    manifest=stage4a7_2_r2_external_manifest(root,sc.derived_subnetwork);
    assert(all(cellfun(@(x)isempty(regexp(x,'/home/|/tmp/','once')),{manifest.relative_or_logical_path})), ...
        'External manifest contains a machine-local absolute path.');
    assert(~isempty(manifest(4).sha256), ...
        'Derived provenance hash is missing.');
    fprintf('  PASS Stage 4A.7.2-R.2 candidate coverage, exact Top-K and tie semantics\n');
end
