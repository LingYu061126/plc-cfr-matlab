function [ledger,audit] = stage4a7_2_r2_1_build_benchmark_ledger(reference,sc,corruption,seed)
%STAGE4A7_2_R2_1_BUILD_BENCHMARK_LEDGER Offline controlled ledger corruption.
%   This function is an evaluator-side constructor.  Its output is passed to
%   the deployment generator, which never receives this reference argument.
    if nargin<3||isempty(corruption),corruption='nominal';end
    if nargin<4||isempty(seed),seed=1;end
    stream=RandStream('mt19937ar','Seed',seed);ref=reference.edges;
    row=ledger_template();ledger=repmat(row,1,numel(ref)+1);ledger(:)=[];
    for k=1:numel(ref)
        ledger(end+1)=make_row(ref(k),reference,sc,ternary(strcmp(corruption,'missing_edge')&&k==1,'missing','optional'),getf(sc,'observed_default_prior_cost',1.0)); %#ok<AGROW>
    end
    % The ambiguity edges are part of the observed engineering ledger used
    % by the deployment-facing generator.  They are controlled benchmark
    % inputs, not hidden truth labels and not auto-inserted by the generator.
    if getf(sc,'add_controlled_ambiguity_edges',false)
        pairs=getf(sc,'synthetic_ambiguity_edges',{});
        for q=1:size(pairs,1)
            if ~has_endpoint_pair(ledger,pairs{q,1},pairs{q,2})
                e=ref(1);e.id=sprintf('OBS_AMBIG_%02d',q);e.from=char(pairs{q,1});e.to=char(pairs{q,2});
                e.length_m=median([ref.length_m]);e.cable_type=0;
                ledger(end+1)=make_row(e,reference,sc,'synthetic_ambiguity',getf(sc,'synthetic_ambiguity_prior_cost',1.0)); %#ok<AGROW>
                ledger(end).uncertainty_mechanism='controlled_observed_ledger_ambiguity';
                ledger(end).evidence_level='controlled_benchmark_input_not_truth';
            end
        end
    end
    if ismember(corruption,{'false_edge','confidence_inversion','incorrect_required_edge','mixed_corruption'})
        pairs=getf(sc,'synthetic_ambiguity_edges',{}); ix=1+floor(rand(stream)*max(1,size(pairs,1)));
        if ~isempty(pairs)
            e=ref(1);e.id=['OFFLINE_FALSE_' num2str(seed)];e.from=char(pairs{ix,1});e.to=char(pairs{ix,2});e.length_m=median([ref.length_m]);e.cable_type=0;
            cost=1.0;if strcmp(corruption,'confidence_inversion'),cost=0.05;end
            ledger(end+1)=make_row(e,reference,sc,'synthetic_ambiguity',cost); %#ok<AGROW>
        end
    end
    if ismember(corruption,{'confidence_inversion','mixed_corruption'}) && ~isempty(ledger)
        ledger(1).prior_cost=2.0;ledger(1).edge_confidence='low';
    end
    if strcmp(corruption,'incorrect_required_edge')
        % The required edge must be an intentionally wrong observed edge,
        % never a reference edge.  If the selected ambiguity row was already
        % present, select it by provenance; otherwise create one explicitly.
        ix_false=find(strcmp({ledger.uncertainty_mechanism},'controlled_observed_ledger_ambiguity'),1);
        if isempty(ix_false)
            pairs=getf(sc,'synthetic_ambiguity_edges',{});
            if isempty(pairs), error('stage4a7_2_r2_1:NoFalseEdgeForCorruption','Cannot construct incorrect required edge without an ambiguity edge.'); end
            e=ref(1);e.id=['OFFLINE_REQUIRED_FALSE_' num2str(seed)];e.from=char(pairs{1,1});e.to=char(pairs{1,2});e.length_m=median([ref.length_m]);e.cable_type=0;
            ledger(end+1)=make_row(e,reference,sc,'synthetic_ambiguity',1.0); %#ok<AGROW>
            ledger(end).uncertainty_mechanism='controlled_observed_ledger_ambiguity';
            ledger(end).evidence_level='controlled_benchmark_input_not_truth';
            ix_false=numel(ledger);
        end
        ledger(ix_false).edge_status='required';ledger(ix_false).edge_confidence='independently_observed_required_but_incorrect';
    elseif strcmp(corruption,'missing_switch_state') && numel(ledger)>=1
        ledger(1).edge_status='unknown_switch';ledger(1).edge_confidence='switch_state_missing';
    end
    if strcmp(corruption,'mixed_corruption') && numel(ledger)>=2
        ledger(2).edge_status='missing';
    end
    keep=~strcmp({ledger.edge_status},'missing');ledger=ledger(keep);
    audit=struct('corruption',corruption,'seed',seed,'reference_used_offline_only',true, ...
        'truth_edges',numel(ref),'observed_edges',numel(ledger),'status','benchmark_ledger_ready', ...
        'incorrect_required_edge_is_reference',false,'incorrect_required_edge_id','');
    if strcmp(corruption,'incorrect_required_edge')
        ix=find(strcmp({ledger.edge_confidence},'independently_observed_required_but_incorrect'),1);
        if ~isempty(ix)
            audit.incorrect_required_edge_id=ledger(ix).edge_id;
            audit.incorrect_required_edge_is_reference=any(strcmp({ref.id},ledger(ix).edge_id));
            if audit.incorrect_required_edge_is_reference
                error('stage4a7_2_r2_1:ReferenceEdgeRequiredCorruption','Incorrect required edge unexpectedly references truth edge.');
            end
        end
    end
end
function r=make_row(e,ref,sc,status,cost)
    r=ledger_template();r.node_id=char(e.from);r.source_node_id=char(ref.source_node_id);r.receiver_node_id=char(ref.receiver_node_id);
    r.edge_id=char(e.id);r.from_node=char(e.from);r.to_node=char(e.to);r.edge_status=status;r.edge_confidence='processed_public_model_observation';
    r.prior_cost=cost;r.length_nominal_m=e.length_m;r.length_lower_m=.98*e.length_m;r.length_upper_m=1.02*e.length_m;
    default_load=getf(sc,'forward_model_default_terminal_load_ohm',NaN);
    r.cable_type_nominal=e.cable_type;r.cable_type_candidates=num2str(e.cable_type);r.load_nominal=default_load;
    r.terminal_load_status='controlled_model_default_not_ENWL_measurement';
    r.uncertainty_mechanism='controlled_offline_benchmark';r.source_dataset=ref.source_table(1).source_dataset;
    r.source_network_id=ref.source_table(1).source_network_id;r.source_feeder_id=ref.source_table(1).source_feeder_id;r.source_record_id=e.id;r.evidence_level='offline_benchmark_only';
end
function r=ledger_template()
    r=struct('node_id','','source_node_id','','receiver_node_id','','edge_id','','from_node','','to_node','','edge_status','','edge_confidence','', ...
        'prior_cost',NaN,'length_nominal_m',NaN,'length_lower_m',NaN,'length_upper_m',NaN,'cable_type_nominal',NaN, ...
        'cable_type_candidates','','load_nominal',NaN,'terminal_load_status','','uncertainty_mechanism','','source_dataset','', ...
        'source_network_id','','source_feeder_id','','source_record_id','','evidence_level','');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function tf=has_endpoint_pair(rows,a,b)
    tf=false;
    target=sort({char(a),char(b)});
    for k=1:numel(rows)
        p=sort({char(rows(k).from_node),char(rows(k).to_node)});
        if strcmp(p{1},target{1}) && strcmp(p{2},target{2}),tf=true;return;end
    end
end
