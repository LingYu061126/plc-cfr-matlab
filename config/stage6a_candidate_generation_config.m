function sc = stage6a_candidate_generation_config(base, mode)
%STAGE6A_CANDIDATE_GENERATION_CONFIG Controlled partial-prior baseline.
%   The prior is synthetic and exists only to verify the candidate-generation
%   interface. It is not a field GIS/asset ledger.
    if nargin < 1 || isempty(base)
        base = default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin < 2 || isempty(mode), mode = 'formal'; end
    mode = lower(char(mode));
    assert(ismember(mode,{'smoke','formal'}),'stage6a:Mode', ...
        'Mode must be smoke or formal.');

    legacy = stage4a1_config(base);
    sc = struct();
    sc.stage_name = 'Stage 6A';
    sc.version = 'stage6a_partial_prior_candidate_generation_v1';
    sc.mode = mode;
    sc.output_root = fullfile(base.root_dir,'results','data','stage6a');
    sc.frequency_hz = linspace(2e6,30e6,61);
    sc.measurement_kind = 'siso_forward';
    sc.legacy_grammar = legacy.generator;
    sc.truth_branch_nodes = 2;
    sc.alpha = 0.05;
    sc.calibration_snr_db = 35;
    sc.test_snr_db = [Inf 30 15];
    sc.calibration_per_candidate = 20;
    sc.test_replicates_per_snr = 3;
    sc.seed = 20264001;
    sc.domain_quantile = 0.99;
    sc.parameter_search = compact_parameter_search(base);
    sc.evidence_calibration = struct('margin_quantile',0.05, ...
        'confidence_quantile',0.05,'entropy_quantile',0.95, ...
        'temperature_target_odds',9,'minimum_reference_count',3);
    sc.rank = struct('branch_penalty',1,'prior_cost_weight',1);
    sc.export = struct('id_prefix','S6A','require_forward_compatible',true);
    sc.partial_prior_cases = build_cases();
    sc.prior_semantics = ['controlled synthetic partial prior; unknown branch ', ...
        'presence, explicit node-count/length/degree/branch/switch constraints; not field data'];

    if strcmp(mode,'smoke')
        sc.alpha = 0.20;
        sc.calibration_per_candidate = 4;
        sc.test_snr_db = Inf;
        sc.test_replicates_per_snr = 1;
        sc.evidence_calibration.minimum_reference_count = 2;
    end
end

function search = compact_parameter_search(base)
    search = base.stage2_2.search;
    search.main_length_scale = [0.98 1 1.02];
    search.branch_length_scale = 1;
    search.branch_load_scale = 1;
    search.source_impedance_ohm = search.nominal_source_impedance_ohm;
    search.receiver_impedance_ohm = search.nominal_receiver_impedance_ohm;
    search.couple_line_scales = false;
end

function cases = build_cases()
    broad = base_prior();
    broad.case_id = 'broad_unknown_switches';
    broad.switch_state = switch_rows({'M1','B1','unknown'; ...
        'M2','B2','unknown';'M3','B3','unknown'});

    informative = broad;
    informative.case_id = 'informative_switch_prior';
    informative.switch_state = switch_rows({'M1','B1','unknown'; ...
        'M2','B2','closed';'M3','B3','open'});

    stale = broad;
    stale.case_id = 'stale_switch_prior';
    stale.switch_state = switch_rows({'M1','B1','unknown'; ...
        'M2','B2','open';'M3','B3','unknown'});

    cases = [broad informative stale];
end

function p = base_prior()
    edges = edge_rows();
    p = struct('case_id','','node_ids',{{'TX','M1','M2','M3','RX','B1','B2','B3'}}, ...
        'required_node_ids',{{'TX','M1','M2','M3','RX'}}, ...
        'optional_node_ids',{{'B1','B2','B3'}},'node_count_range',[5 7], ...
        'source_node_id','TX','receiver_node_id','RX','allowed_edges',edges, ...
        'required_edges',edges(1:4),'forbidden_edges',edges([]), ...
        'switch_state',struct([]),'maximum_degree',3,'maximum_branch_count',2, ...
        'total_length_range_m',[80 110],'radial_only',true, ...
        'require_connected',true,'maximum_candidate_count',64, ...
        'maximum_node_subsets',16,'edge_prior_cost',[edges.prior_cost].', ...
        'prior_source','synthetic_stage6a_partial_prior_not_field_data', ...
        'prior_config_hash','');
end

function edges = edge_rows()
    t = edge_template(); edges = repmat(t,1,7);
    edges(1)=edge('E_TX_M1','TX','M1','main',20,0,NaN,18,22,0);
    edges(2)=edge('E_M1_M2','M1','M2','main',20,0,NaN,18,22,0);
    edges(3)=edge('E_M2_M3','M2','M3','main',20,0,NaN,18,22,0);
    edges(4)=edge('E_M3_RX','M3','RX','main',20,0,NaN,18,22,0);
    edges(5)=edge('E_M1_B1','M1','B1','branch',15,1,50,12,18,1);
    edges(6)=edge('E_M2_B2','M2','B2','branch',15,1,50,12,18,1);
    edges(7)=edge('E_M3_B3','M3','B3','branch',15,1,50,12,18,1);
end

function e = edge(id,from,to,kind,length_m,cable,load,zmin,zmax,cost)
    e = struct('id',id,'from',from,'to',to,'kind',kind, ...
        'length_m',length_m,'cable_type',cable,'load',load, ...
        'length_min_m',zmin,'length_max_m',zmax,'prior_cost',cost);
end
function e = edge_template()
    e = edge('','','','line',NaN,NaN,NaN,0,Inf,0);
end
function rows = switch_rows(x)
    rows = repmat(struct('from','','to','','state',''),size(x,1),1);
    for k=1:size(x,1)
        rows(k)=struct('from',char(x{k,1}),'to',char(x{k,2}),'state',char(x{k,3}));
    end
end
