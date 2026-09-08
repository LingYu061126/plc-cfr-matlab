function rows=build_stage4a7_2_near_symmetry(candidates,cfg,seed,delta_grid,replicates,tau_exact)
%BUILD_STAGE4A7_2_NEAR_SYMMETRY Sweep frozen symmetry-breaking perturbations.
    if nargin<3||isempty(seed),seed=20262761;end
    if nargin<4||isempty(delta_grid),delta_grid=[.001 .005 .01 .02 .05];end
    if nargin<5||isempty(replicates),replicates=10;end
    if nargin<6||isempty(tau_exact),tau_exact=1e-10;end
    pair=find_pair(candidates,{'G004','G007'});
    if isempty(pair),error('stage4a7_2:NoSymmetryPair','No G004/G007 pair.');end
    f=linspace(2e6,30e6,61);stream=RandStream('mt19937ar','Seed',seed);
    empty=struct('perturbation_fraction',NaN,'replicate',0,'same_theta_distance',NaN, ...
        'same_theta_equivalent',false,'tau_exact',tau_exact,'parameter_hash','', ...
        'observation_hash','','seed',0);
    rows=repmat(empty,0,1);q0=0;
    for d=delta_grid
        for q=1:replicates
            q0=q0+1;t=struct('main_length_scale',.97+.06*rand(stream), ...
                'branch_length_scale',.96+.08*rand(stream), ...
                'branch_load_scale',.85+.30*rand(stream), ...
                'source_impedance_ohm',45+10*rand(stream), ...
                'receiver_impedance_ohm',45+10*rand(stream),'regularization',NaN);
            t.receiver_impedance_ohm=t.source_impedance_ohm*(1+d);
            h=cell(1,2);
            for z=1:2
                [n,l]=topology_apply_parameters(candidates(pair(z)).network,cfg,t);
                [m,~]=plc_measurement_bundle('siso_forward',n,t,l);
                [v,~]=plc_multiview_response(f,n,m,l);h{z}=v{1};
            end
            dist=sqrt(mean(abs(h{1}-h{2}).^2));r=empty;
            r.perturbation_fraction=d;r.replicate=q;r.same_theta_distance=dist;
            r.same_theta_equivalent=dist<=tau_exact;r.tau_exact=tau_exact;
            r.parameter_hash=stage4a4_scientific_config_hash(t);
            r.observation_hash=stage4a4_scientific_config_hash(h{1});r.seed=seed+q0;
            rows(end+1)=r; %#ok<AGROW>
        end
    end
end
function p=find_pair(c,ids)
    keys=cell(1,numel(c));
    for k=1:numel(c)
        if isfield(c,'id')&&~isempty(c(k).id),keys{k}=c(k).id;
        elseif isfield(c,'graph_candidate_id'),keys{k}=c(k).graph_candidate_id;
        else,keys{k}='';end
    end
    p=zeros(1,2);for k=1:2,p(k)=find(strcmp(keys,ids{k}),1);end
    if any(p==0),p=[];end
end
