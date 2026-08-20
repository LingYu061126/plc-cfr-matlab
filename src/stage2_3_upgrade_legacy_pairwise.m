function output=stage2_3_upgrade_legacy_pairwise(source_file,target_file,cfg)
%STAGE2_3_UPGRADE_LEGACY_PAIRWISE Add the audited raw CFR pairwise field.
%   The Stage-2.3 formal MAT batches in the private research tree predate
%   the raw pairwise column. This adapter does not alter their trials,
%   summaries, confusion matrices, or source files. It recomputes only the
%   nominal pairwise raw CFR distances with the current complete-network
%   model, then writes the small sealed schema consumed by the compiler.
    if nargin<3||isempty(cfg),cfg=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if ~(ischar(source_file)||isstring(source_file))|| ...
            ~(ischar(target_file)||isstring(target_file))
        error('stage2_3_upgrade_legacy_pairwise:InvalidPath','Source and target paths must be text.');
    end
    source_file=char(source_file);target_file=char(target_file);
    x=load(source_file,'pairwise','summary','confusion','config','elapsed','mode','sc');
    if ~isfield(x,'mode')||~strcmpi(char(x.mode),'formal')
        error('stage2_3_upgrade_legacy_pairwise:ModeMismatch', ...
            'Legacy source %s is not a formal batch.',source_file);
    end
    if ~isfield(x,'sc')||~isstruct(x.sc)||~isfield(x.sc,'measurement_kinds')|| ...
            numel(x.sc.measurement_kinds)~=1
        error('stage2_3_upgrade_legacy_pairwise:InvalidConfiguration', ...
            'Legacy source %s lacks one measurement_kind.',source_file);
    end
    kind=char(x.sc.measurement_kinds{1});
    if ~isfield(x,'pairwise')||~isstruct(x.pairwise)|| ...
            ~isfield(x.pairwise,'measurement_kind')
        error('stage2_3_upgrade_legacy_pairwise:InvalidPairwise', ...
            'Legacy source %s lacks pairwise records.',source_file);
    end
    candidates_all=topology_candidates(cfg);
    candidates=candidates_all(cfg.stage2_3.candidate_indices);
    theta=nominal_theta(kind,x.sc);
    f=cfg.ofdm.pilot_frequency_hz;
    refs=cell(1,numel(candidates));
    for k=1:numel(candidates)
        bundle=plc_measurement_bundle(kind,candidates(k).network,theta,cfg);
        refs{k}=plc_multiview_response(f,candidates(k).network,bundle,cfg);
    end
    audit=topology_observability_classes(refs,candidates,cfg.ofdm,x.sc.tie_tolerance);
    pairwise=x.pairwise(:);
    for k=1:numel(pairwise)
        i=find(strcmp({candidates.id},pairwise(k).topology_i),1);
        j=find(strcmp({candidates.id},pairwise(k).topology_j),1);
        if isempty(i)||isempty(j)||~strcmp(pairwise(k).measurement_kind,kind)
            error('stage2_3_upgrade_legacy_pairwise:PairMismatch', ...
                'Legacy pairwise record does not match candidate/configuration in %s.',source_file);
        end
        pairwise(k).complex_distance_raw=audit.pairwise_complex_distance_raw(i,j);
    end
    mode=x.mode;sc=x.sc;summary=x.summary;confusion=x.confusion;config=x.config;elapsed=x.elapsed; %#ok<NASGU>
    save(target_file,'pairwise','summary','confusion','config','elapsed','mode','sc','-v7');
    output=struct('source_file',source_file,'target_file',target_file, ...
        'measurement_kind',kind,'pairwise_count',numel(pairwise), ...
        'raw_distance_definition','current complete-network nominal raw CFR RMS');
end

function theta=nominal_theta(kind,sc)
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'kG_scale',1,'source_impedance_ohm',50, ...
        'receiver_impedance_ohm',50);
    asymmetric={'siso_forward_asymmetric','siso_reverse_role_fixed', ...
        'siso_reverse_endpoint_fixed','bidirectional_endpoint_fixed'};
    if ismember(kind,asymmetric)
        theta.source_impedance_ohm=sc.asymmetric_Zs;
        theta.receiver_impedance_ohm=sc.asymmetric_Zr;
    end
end
