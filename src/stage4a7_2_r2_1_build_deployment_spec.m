function [spec,audit] = stage4a7_2_r2_1_build_deployment_spec(observed_ledger,sc)
%STAGE4A7_2_R2_1_BUILD_DEPLOYMENT_SPEC Build candidates from observed data only.
%   This deployment-facing interface has no reference graph or truth-label
%   input.  Hidden reference construction belongs to the offline benchmark.
    if nargin<2 || ~isstruct(observed_ledger), error('stage4a7_2_r2_1:MissingLedger','Observed ledger is required.'); end
    required={'node_id','from_node','to_node','edge_id','edge_status','prior_cost'};
    for k=1:numel(required)
        if ~isfield(observed_ledger,required{k}), error('stage4a7_2_r2_1:LedgerField','Missing observed ledger field %s.',required{k}); end
    end
    node_ids=unique([{observed_ledger.node_id} {observed_ledger.from_node} {observed_ledger.to_node}],'stable');
    edge0=struct('id','','from','','to','','kind','line','length_m',NaN,'cable_type',NaN,'load',NaN,'prior_cost',NaN);
    allowed=repmat(edge0,0,1);req=repmat(edge0,0,1);forb=req;
    for k=1:numel(observed_ledger)
        e=edge0;e.id=char(observed_ledger(k).edge_id);e.from=char(observed_ledger(k).from_node);e.to=char(observed_ledger(k).to_node);
        e.length_m=double(observed_ledger(k).length_nominal_m);e.cable_type=observed_ledger(k).cable_type_nominal;
        e.load=getf(observed_ledger(k),'load_nominal',NaN);e.prior_cost=double(observed_ledger(k).prior_cost);
        status=lower(char(observed_ledger(k).edge_status));
        if ~ismember(status,{'required','forbidden','optional','unknown_switch','synthetic_ambiguity'})
            error('stage4a7_2_r2_1:InvalidEdgeStatus','Unsupported edge status %s.',status);
        end
        if ~strcmp(status,'forbidden'),allowed(end+1)=e;end %#ok<AGROW>
        if strcmp(status,'required'),req(end+1)=e;end %#ok<AGROW>
        if strcmp(status,'forbidden'),forb(end+1)=e;end %#ok<AGROW>
    end
    spec=struct('node_ids',{node_ids},'source_node_id',getf(sc,'source_node_id',''), ...
        'receiver_node_id',getf(sc,'receiver_node_id',''),'allowed_edges',allowed, ...
        'required_edges',req,'forbidden_edges',forb,'maximum_degree',getf(sc,'maximum_degree',Inf), ...
        'maximum_candidate_count',getf(sc,'maximum_candidate_count',1e5),'radial_only',true, ...
        'require_connected',true,'prior_source',getf(sc,'prior_source','observed_engineering_ledger'), ...
        'prior_config_hash',stage4a4_scientific_config_hash(struct('ledger',observed_ledger,'constraints',sc_constraint_fields(sc))));
    audit=struct('input_kind','observed_engineering_ledger_only','truth_input_received',false, ...
        'allowed_edge_count',numel(allowed),'required_edge_count',numel(req),'forbidden_edge_count',numel(forb), ...
        'prior_config_hash',spec.prior_config_hash,'status','deployment_spec_ready');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=sc_constraint_fields(sc)
    names={'source_node_id','receiver_node_id','maximum_degree','maximum_candidate_count','prior_source'};x=struct();
    for k=1:numel(names),x.(names{k})=getf(sc,names{k},[]);end
end
