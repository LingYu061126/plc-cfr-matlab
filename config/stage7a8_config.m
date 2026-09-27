function cfg=stage7a8_config(base,mode)
%STAGE7A8_CONFIG Frozen nominal C37 paired-efficiency audit configuration.
    if nargin<1||isempty(base)
        base=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin<2||isempty(mode),mode='smoke';end
    assert(ismember(mode,{'smoke','formal'}),'stage7a8:Mode');
    cfg=stage7a7_config(base,mode,'nominal');
    cfg.stage='Stage 7A.8';
    % Keep the frozen Stage 7A.7 scientific condition identity intact.
    cfg.stage7a8_experiment_version='stage7a8_protocol_v1';
    cfg.verification_baseline_commit='31082ad056dac7dbc8a8f74f9c8453cc39a258f5';
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_8',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_8');
    cfg.use_parallel=false;cfg.worker_count=0;
end
