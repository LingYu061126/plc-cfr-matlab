function [grid,bounds] = stage3a_parameter_grid(base_cfg,s3_cfg)
%STAGE3A_PARAMETER_GRID Frozen nuisance-parameter grid for Stage 3A.1.
%   The grid contains nominal plus one-factor-at-a-time perturbations. It
%   is a bounded, interpretable baseline rather than a field-calibrated
%   posterior. Each item is accepted by stage3a_apply_parameters.
    if nargin<2||isempty(s3_cfg),s3_cfg=stage3a_config();end
    nominal=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'kG_scale',1,'source_impedance_ohm',base_cfg.Zs, ...
        'receiver_impedance_ohm',base_cfg.Zr,'R_scale',1,'L_scale',1, ...
        'G_scale',1,'C_scale',1,'coupler_gain',1,'regularization',0, ...
        'perturbation_label','nominal');
    bounds=struct('main_length_scale',[0.98,1.02], ...
        'branch_length_scale',[0.98,1.02],'branch_load_scale',[0.90,1.10], ...
        'kG_scale',[0.98,1.02],'source_impedance_ohm',[49,51], ...
        'receiver_impedance_ohm',[49,51],'R_scale',[0.98,1.02], ...
        'L_scale',[0.98,1.02],'G_scale',[0.98,1.02],'C_scale',[0.98,1.02], ...
        'rlgc_scale',[0.98,1.02], ...
        'coupler_amplitude',[0.98,1.02],'coupler_phase_rad',[-pi/36,pi/36]);
    if isfield(s3_cfg,'audit_parameter_scales')
        sc=s3_cfg.audit_parameter_scales;
        bounds.main_length_scale=sc.main_length;
        bounds.branch_length_scale=sc.branch_length;
        bounds.branch_load_scale=sc.branch_load;
        bounds.R_scale=sc.rlgc; bounds.L_scale=sc.rlgc;
        bounds.G_scale=sc.rlgc; bounds.C_scale=sc.rlgc;
        bounds.rlgc_scale=sc.rlgc;
        bounds.source_impedance_ohm=sc.source_impedance;
        bounds.receiver_impedance_ohm=sc.receiver_impedance;
        bounds.coupler_amplitude=sc.coupler_amplitude;
        bounds.coupler_phase_rad=sc.coupler_phase;
    end
    grid=nominal;
    grid=append_scale(grid,nominal,'main_length_scale',bounds.main_length_scale);
    grid=append_scale(grid,nominal,'branch_length_scale',bounds.branch_length_scale);
    grid=append_scale(grid,nominal,'branch_load_scale',bounds.branch_load_scale);
    grid=append_scale(grid,nominal,'kG_scale',bounds.kG_scale);
    grid=append_scale(grid,nominal,'source_impedance_ohm',bounds.source_impedance_ohm);
    grid=append_scale(grid,nominal,'receiver_impedance_ohm',bounds.receiver_impedance_ohm);
    grid=append_rlgc(grid,nominal,bounds.rlgc_scale,'R_scale');
    grid=append_rlgc(grid,nominal,bounds.rlgc_scale,'L_scale');
    grid=append_rlgc(grid,nominal,bounds.rlgc_scale,'G_scale');
    grid=append_rlgc(grid,nominal,bounds.rlgc_scale,'C_scale');
    for a=bounds.coupler_amplitude(:).'
        if a==1,continue;end
        t=nominal;t.coupler_gain=a;t.perturbation_label='coupler_amplitude';
        t.regularization=parameter_regularization(t,bounds,base_cfg);grid(end+1)=t; %#ok<AGROW>
    end
    for p=bounds.coupler_phase_rad(:).'
        if p==0,continue;end
        t=nominal;t.coupler_gain=exp(1i*p);t.perturbation_label='coupler_phase';
        t.regularization=parameter_regularization(t,bounds,base_cfg);grid(end+1)=t; %#ok<AGROW>
    end
    for k=1:numel(grid),grid(k).regularization=parameter_regularization(grid(k),bounds,base_cfg);end
end

function grid=append_scale(grid,nominal,name,values)
    for value=values(:).'
        if value==1,continue;end
        t=nominal;t.(name)=value;t.perturbation_label=name;
        grid(end+1)=t; %#ok<AGROW>
    end
end

function grid=append_rlgc(grid,nominal,values,name)
    for value=values(:).'
        if value==1,continue;end
        t=nominal;t.(name)=value;t.perturbation_label=name;
        grid(end+1)=t; %#ok<AGROW>
    end
end

function r=parameter_regularization(t,bounds,base_cfg)
    amp=abs(t.coupler_gain);phase=angle(t.coupler_gain);
    nominal=[1,1,1,1,base_cfg.Zs,base_cfg.Zr,1,1,1,1,1,0];
    values=[t.main_length_scale,t.branch_length_scale,t.branch_load_scale,t.kG_scale, ...
        t.source_impedance_ohm,t.receiver_impedance_ohm,t.R_scale,t.L_scale, ...
        t.G_scale,t.C_scale,amp,phase];
    spans=[range_span(bounds.main_length_scale,1),range_span(bounds.branch_length_scale,1), ...
        range_span(bounds.branch_load_scale,1),range_span(bounds.kG_scale,1), ...
        range_span(bounds.source_impedance_ohm,base_cfg.Zs),range_span(bounds.receiver_impedance_ohm,base_cfg.Zr), ...
        range_span(bounds.rlgc_scale,1),range_span(bounds.rlgc_scale,1),range_span(bounds.rlgc_scale,1), ...
        range_span(bounds.rlgc_scale,1),range_span(bounds.coupler_amplitude,1), ...
        range_span(bounds.coupler_phase_rad,0)];
    spans(spans<=0)=1;
    r=mean(((values-nominal)./spans).^2);
end

function s=range_span(x,nominal),s=max(abs(x(:).'-nominal));if s==0,s=1;end,end
