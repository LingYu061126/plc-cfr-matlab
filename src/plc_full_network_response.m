function [H, details] = plc_full_network_response(f_hz, network, measurement, cfg)
%PLC_FULL_NETWORK_RESPONSE Solve voltages on one complete branched PLC tree.
%   Every main-line and branch segment remains in the nodal network. Each
%   distributed line contributes its exact two-node admittance matrix. The
%   Thevenin source is represented by its Norton equivalent; receiver loads
%   and branch-terminal loads are shunts at their physical nodes.
%
%   measurement fields (node indices refer to details.node_labels):
%     source_node, source_impedance_ohm, receiver_nodes,
%     receiver_loads_ohm, optional source_voltage_v and port_reference_ohm.
%   Loads may be scalar, one value per receiver, or cells containing scalar
%   or frequency-vector impedances. Inf is open and zero is an exact grounded
%   node. A zero-length distributed edge is rejected explicitly because it
%   requires node contraction rather than a finite admittance matrix.

    f_hz = f_hz(:).';
    if isempty(f_hz) || any(~isfinite(f_hz)) || any(f_hz <= 0)
        error('plc_full_network_response:InvalidFrequency', ...
            'f_hz must contain finite strictly positive values in Hz.');
    end
    [edges, node_labels, terminal_loads, branch_meta] = network_graph(network);
    nnode = numel(node_labels); nf = numel(f_hz);
    required = {'source_node','source_impedance_ohm','receiver_nodes','receiver_loads_ohm'};
    for k = 1:numel(required)
        if ~isfield(measurement, required{k})
            error('plc_full_network_response:MissingMeasurementField', ...
                'measurement.%s is required.', required{k});
        end
    end
    source_node = validate_nodes(measurement.source_node, nnode, 'source_node');
    if numel(source_node) ~= 1
        error('plc_full_network_response:InvalidSourceNode', ...
            'source_node must select exactly one node.');
    end
    receiver_nodes = validate_nodes(measurement.receiver_nodes, nnode, 'receiver_nodes');
    if isempty(receiver_nodes) || any(receiver_nodes == source_node)
        error('plc_full_network_response:InvalidReceiverNodes', ...
            'receiver_nodes must be nonempty and different from source_node.');
    end
    Zs = measurement.source_impedance_ohm;
    if ~(isnumeric(Zs) && isscalar(Zs) && isfinite(Zs) && Zs ~= 0 && real(Zs) >= 0)
        error('plc_full_network_response:InvalidSourceImpedance', ...
            'source_impedance_ohm must be a nonzero finite passive scalar.');
    end
    Vs = get_field(measurement, 'source_voltage_v', 1);
    Zref = get_field(measurement, 'port_reference_ohm', cfg.port_reference_ohm);
    if ~(isscalar(Vs) && isfinite(Vs) && Vs ~= 0) || ...
            ~(isscalar(Zref) && isreal(Zref) && isfinite(Zref) && Zref > 0)
        error('plc_full_network_response:InvalidNormalization', ...
            'source_voltage_v and port_reference_ohm must be valid nonzero scalars.');
    end
    receiver_loads = normalize_receiver_loads(measurement.receiver_loads_ohm, ...
        numel(receiver_nodes), nf);

    Y = complex(zeros(nnode, nnode, nf));
    for e = 1:numel(edges)
        if edges(e).length_m == 0
            error('plc_full_network_response:ZeroLengthEdge', ...
                'Zero-length distributed edges require node contraction.');
        end
        cable = cable_parameters(edges(e).cable_type);
        [~,~,~,~,gamma,Zc] = cable_rlgc(f_hz, cable, cfg.kG, cfg.lossless);
        x = gamma .* edges(e).length_m;
        em = exp(-x); em2 = exp(-2*x); den = 1-em2;
        if any(abs(den) <= 100*eps)
            error('plc_full_network_response:SingularLineAdmittance', ...
                'A line admittance is singular at one or more frequencies.');
        end
        ydiag = (1+em2) ./ (Zc.*den);
        yoff = -2*em ./ (Zc.*den);
        a = edges(e).from; b = edges(e).to;
        Y(a,a,:) = Y(a,a,:) + reshape(ydiag,1,1,nf);
        Y(b,b,:) = Y(b,b,:) + reshape(ydiag,1,1,nf);
        Y(a,b,:) = Y(a,b,:) + reshape(yoff,1,1,nf);
        Y(b,a,:) = Y(b,a,:) + reshape(yoff,1,1,nf);
    end

    grounded = false(nnode,nf);
    for k = 1:numel(terminal_loads)
        [Y, grounded] = add_shunt_load(Y, grounded, terminal_loads(k).node, ...
            terminal_loads(k).impedance, nf);
    end
    for k = 1:numel(receiver_nodes)
        [Y, grounded] = add_shunt_load(Y, grounded, receiver_nodes(k), ...
            receiver_loads{k}, nf);
    end
    Ys = 1/Zs;
    Y(source_node,source_node,:) = Y(source_node,source_node,:) + Ys;
    current = complex(zeros(nnode,1,nf));
    current(source_node,1,:) = Vs/Zs;
    if any(grounded(source_node,:))
        error('plc_full_network_response:GroundedSource', ...
            'The source node is short-circuited by a zero-ohm load.');
    end

    voltage = complex(zeros(nnode,1,nf));
    if ~any(grounded(:)) && exist('pagemldivide','builtin') == 5
        voltage = pagemldivide(Y,current);
    else
        for q = 1:nf
            active = ~grounded(:,q);
            if rcond(Y(active,active,q)) < 1e-14
                error('plc_full_network_response:SingularNetwork', ...
                    'The complete nodal network is singular at %.9g Hz.', f_hz(q));
            end
            voltage(active,1,q) = Y(active,active,q) \ current(active,1,q);
        end
    end
    V = reshape(voltage(:,1,:),nnode,nf);
    if any(~isfinite(V(:)))
        error('plc_full_network_response:NonfiniteVoltage', ...
            'The complete-network solve produced nonfinite node voltages.');
    end
    H_V = V(receiver_nodes,:) / Vs;
    H_port = ((Zs+Zref)/Zref) .* H_V;

    branch_input_admittance = cell(1,numel(branch_meta));
    for b = 1:numel(branch_meta)
        cable = cable_parameters(branch_meta(b).cable_type);
        [~,~,~,~,gamma,Zc] = cable_rlgc(f_hz,cable,cfg.kG,cfg.lossless);
        Zin = branch_input_impedance(gamma,Zc,branch_meta(b).length_m,branch_meta(b).load);
        branch_input_admittance{b} = impedance_to_admittance(Zin);
    end
    H = struct('H_V',H_V,'H_port',H_port);
    details = struct('full_network',true,'frequency_hz',f_hz, ...
        'node_labels',{node_labels},'node_voltage_v',V, ...
        'source_node',source_node,'source_node_label',node_labels{source_node}, ...
        'receiver_nodes',receiver_nodes,'receiver_node_labels',{node_labels(receiver_nodes)}, ...
        'source_impedance_ohm',Zs,'receiver_loads_ohm',{receiver_loads}, ...
        'port_reference_ohm',Zref,'edges',edges, ...
        'branch_input_admittance_siemens',{branch_input_admittance}, ...
        'grounded_node_mask',grounded,'model_name', ...
        'complete-tree distributed-line nodal-admittance model');
end

function [edges, labels, terminal_loads, branch_meta] = network_graph(network)
    if ~isstruct(network) || ~isfield(network,'main_lengths')
        error('plc_full_network_response:InvalidNetwork','network.main_lengths is required.');
    end
    lengths = network.main_lengths(:).'; nseg = numel(lengths);
    if nseg < 1 || any(~isfinite(lengths)) || any(lengths < 0)
        error('plc_full_network_response:InvalidLengths', ...
            'main_lengths must be finite nonnegative metres.');
    end
    types = get_field(network,'main_cable_type',0);
    if isscalar(types), types = repmat(types,1,nseg); else, types = types(:).'; end
    if numel(types) ~= nseg
        error('plc_full_network_response:InvalidCableTypes', ...
            'main_cable_type must be scalar or match main_lengths.');
    end
    branches = get_field(network,'branches',struct('node',{},'length',{},'cable_type',{},'load',{}));
    nmain = nseg+1;
    labels = arrayfun(@(k)sprintf('M%d',k-1),1:nmain,'UniformOutput',false);
    edge0 = struct('from',0,'to',0,'length_m',0,'cable_type',0,'kind','','id','');
    edges = repmat(edge0,1,nseg+numel(branches));
    for k = 1:nseg
        edges(k) = struct('from',k,'to',k+1,'length_m',lengths(k), ...
            'cable_type',types(k),'kind','main','id',sprintf('main_%d_%d',k,k+1));
    end
    terminal_loads = repmat(struct('node',0,'impedance',[]),1,numel(branches));
    branch_meta = repmat(struct('node',0,'length_m',0,'cable_type',0,'load',[]),1,numel(branches));
    for b = 1:numel(branches)
        required = {'node','length','cable_type','load'};
        for q = 1:numel(required)
            if ~isfield(branches(b),required{q})
                error('plc_full_network_response:BranchField', ...
                    'Every branch needs node, length, cable_type and load.');
            end
        end
        if ~(isscalar(branches(b).node) && branches(b).node == fix(branches(b).node) && ...
                branches(b).node >= 1 && branches(b).node < nseg)
            error('plc_full_network_response:BranchNode', ...
                'Branch node must be an internal main-line junction.');
        end
        terminal = nmain+b; labels{terminal} = sprintf('B%d_LOAD',b);
        edges(nseg+b) = struct('from',branches(b).node+1,'to',terminal, ...
            'length_m',branches(b).length,'cable_type',branches(b).cable_type, ...
            'kind','branch','id',sprintf('branch_%d',b));
        terminal_loads(b) = struct('node',terminal,'impedance',branches(b).load);
        branch_meta(b) = struct('node',branches(b).node+1, ...
            'length_m',branches(b).length,'cable_type',branches(b).cable_type, ...
            'load',branches(b).load);
    end
end

function nodes = validate_nodes(nodes,nnode,name)
    nodes = nodes(:).';
    if isempty(nodes) || any(~isfinite(nodes)) || any(nodes ~= fix(nodes)) || ...
            any(nodes < 1) || any(nodes > nnode) || numel(unique(nodes)) ~= numel(nodes)
        error('plc_full_network_response:InvalidNodeIndex', ...
            '%s must contain unique valid integer node indices.',name);
    end
end

function loads = normalize_receiver_loads(value,nreceiver,nf)
    if iscell(value)
        if numel(value) ~= nreceiver
            error('plc_full_network_response:ReceiverLoadCount', ...
                'receiver_loads_ohm must match receiver_nodes.');
        end
        loads = value(:).';
    elseif nreceiver == 1
        loads = {value};
    elseif isnumeric(value) && isvector(value) && numel(value) == nreceiver
        loads = num2cell(value(:).');
    else
        error('plc_full_network_response:ReceiverLoadCount', ...
            'Use one scalar per receiver or a cell array for frequency-dependent loads.');
    end
    for k = 1:numel(loads), expand_impedance(loads{k},nf); end
end

function [Y,grounded] = add_shunt_load(Y,grounded,node,Z,nf)
    Z = expand_impedance(Z,nf);
    zero = (Z == 0); grounded(node,zero) = true;
    finite = isfinite(Z) & ~zero;
    addition = zeros(1,nf); addition(finite) = 1./Z(finite);
    Y(node,node,:) = Y(node,node,:) + reshape(addition,1,1,nf);
end

function Z = expand_impedance(Z,nf)
    if isscalar(Z), Z = repmat(Z,1,nf); else, Z = Z(:).'; end
    if numel(Z) ~= nf || any(isnan(Z)) || any(~(isfinite(Z)|isinf(Z)))
        error('plc_full_network_response:InvalidLoad', ...
            'Loads must be scalar or match frequency, with finite values or Inf.');
    end
end

function Y = impedance_to_admittance(Z)
    Y = zeros(size(Z)); hit = isfinite(Z) & Z ~= 0; Y(hit)=1./Z(hit); Y(Z==0)=Inf;
end

function value = get_field(s,name,default_value)
    if isfield(s,name) && ~isempty(s.(name)), value=s.(name); else, value=default_value; end
end
