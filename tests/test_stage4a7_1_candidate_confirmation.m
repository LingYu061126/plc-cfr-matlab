function test_stage4a7_1_candidate_confirmation()
%TEST_STAGE4A7_1_CANDIDATE_CONFIRMATION Weighted residual and set evidence.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    r=score_candidate_weighted_residual([1+1i;2],[1;2+1i],diag([1,4]),struct());
    expected=real(([1i;-1i]'*(diag([1,4])\[1i;-1i])));
    assert(abs(r.weighted_squared_residual-expected)<1e-12&&strcmp(r.noise_model_interpretation,'weighted_residual_only'),'Weighted residual hand check failed.');
    assert_throws(@()score_candidate_weighted_residual([1;2],[1;2],eye(3),struct()),'stage4a7_1:CovarianceDimension');
    singular=score_candidate_weighted_residual([1;2],[0;0],[1 1;1 1],struct());assert(strcmp(singular.covariance_status,'regularized_covariance')&&isfinite(singular.weighted_residual),'Covariance regularization failed.');
    fprintf('  PASS weighted residual, dimension validation and covariance regularization\n');

    if ~is_octave()
        rows=repmat(struct('candidate_id','','score',NaN),1,40);q=0;for k=1:2,for j=1:20,q=q+1;rows(q)=struct('candidate_id',sprintf('G%03d',k),'score',j/100);end,end
        m=calibrate_candidate_set_predictor(rows,0.05,struct('minimum_per_candidate',20,'compatibility_hash','c'));assert(strcmp(m.status,'calibrated')&&min([m.classes.minimum_attainable_p])==1/21,'Empirical calibration failed.');
        out=apply_candidate_set_predictor(struct('candidate_id','G001','score',0.01),m,0.05);assert(out.p_values(1)>0&&strcmp(out.calibration_hash,m.calibration_hash),'Candidate-set p-value application failed.');
        low=calibrate_candidate_set_predictor(rows(1:10),0.05,struct('minimum_per_candidate',20));assert(strcmp(low.status,'insufficient_calibration'),'Insufficient calibration was not reported.');
        fprintf('  PASS calibrated candidate-set p-values, ties and insufficiency\n');
    else
        fprintf('  SKIP SHA-256-dependent candidate-set identity checks in Octave fallback\n');
    end

    g=build_candidate_indistinguishability_graph({'G1','G2','G3'},[1,1.0001,2],1e-3);assert(numel(g.components)==2&&numel(g.components{1})==2,'Indistinguishability components incorrect.');
    f=score_candidate_set_metrics({'G1'},{'G1'},'G1',{'G1','G2'});assert(f.false_unique,'Nonunique truth with singleton output was not scored.');
    f=score_candidate_set_metrics({'G1'},{'G1'},'G1',{'G1'});assert(~f.false_unique,'Unique truth was mis-scored as false-unique.');
    fprintf('  PASS calibrated indistinguishability graph and offline false-unique separation\n');

    y=[1+2i,3-1i];X=[y;0,0;2*y];fast=score_candidate_library_fast(y,X,{'A','B','C'},struct());
    exact=sqrt(mean(abs(X-y).^2,2));
    assert(max(abs(fast.scores-exact))<1e-14&&strcmp(fast.best_candidate_id,'A'), ...
        'Vectorized exact scoring changed the candidate residual or optimum.');
    fprintf('  PASS vectorized scoring is exact relative to direct residual evaluation\n');

    d=repmat(decision_row(),2,1);l=repmat(label_row(),2,1);
    d(1)=decision_row('s1','M','unique_topology','G1');d(2)=decision_row('s2','M','equivalence_class','G1,G2');
    l(1)=label_row('s1','G1','G1,G2',2);l(2)=label_row('s2','G1','G1,G2',2);
    z=evaluate_stage4a7_1_pilot_metrics(d,l);
    fu=z(strcmp({z.metric_name},'false_unique_conditional')&strcmp({z.category},'all'));
    assert(fu.numerator==1&&fu.denominator==2&&abs(fu.rate-0.5)<eps,'False-unique denominator is not based on evaluable nonunique physical scenarios.');
    acc=z(strcmp({z.metric_name},'topology_set_accuracy')&strcmp({z.category},'all'));assert(acc.numerator==2&&acc.denominator==2,'Topology set metric denominator is incorrect.');
    fprintf('  PASS independent-scenario denominators and Wilson metric records\n');
end
function assert_throws(fun,id),hit=false;try,fun();catch ME,hit=true;assert(strcmp(ME.identifier,id),'Expected %s got %s.',id,ME.identifier);end;assert(hit,'Expected %s.',id);end
function tf=is_octave(),tf=exist('OCTAVE_VERSION','builtin')==5;end
function r=decision_row(id,method,decision,set)
    if nargin==0,id='';method='';decision='';set='';end
    r=struct('sample_id',id,'method_id',method,'decision',decision,'accepted_candidate_set',set);
end
function r=label_row(id,truth,set,n)
    if nargin==0,id='';truth='';set='';n=0;end
    r=struct('sample_id',id,'category','in_domain_interior','truth_topology_id',truth, ...
        'truth_equivalence_set',set,'truth_equivalence_member_count',n,'equivalence_evaluable',true, ...
        'parameter_domain_truth','in_domain');
end
