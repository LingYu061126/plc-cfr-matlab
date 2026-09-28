function cfg=stage7a10r1_config(base,mode)
%STAGE7A10R1_CONFIG Paired audit configuration; no scientific threshold edits.
%   Length is m, frequency Hz, receiver impedances ohm; serial execution.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='smoke';end
    cfg=stage7a10_config(base,mode);
    cfg.stage='Stage 7A.10-R.1';cfg.version='stage7a10r1_protocol_v1';
    cfg.audit_baseline_commit='b76972dceb17e46710afcd8b10b8e3f19b9f0a31';
    cfg.seed_T=950000000;
    if strcmp(mode,'smoke'),cfg.seed_T=960000000;end
    cfg.node_port_bias_fraction=0.01;
    cfg.node_acquisition_load_drift_fraction=0.02;
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_10_r1',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_10_r1');
    cfg.use_parallel=false;cfg.worker_count=0;
end
