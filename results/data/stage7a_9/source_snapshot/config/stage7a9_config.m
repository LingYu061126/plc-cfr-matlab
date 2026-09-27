function cfg=stage7a9_config(base,mode)
%STAGE7A9_CONFIG Frozen nominal C37 paired computation-reuse condition.
    if nargin<1||isempty(base)
        base=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin<2||isempty(mode),mode='smoke';end
    cfg=stage7a8_config(base,mode);
    cfg.stage='Stage 7A.9';
    cfg.stage7a9_experiment_version='stage7a9_protocol_v1';
    cfg.verification_baseline_commit='1801416699fe858a53be03a976633fed71da9b19';
    cfg.output_dir=fullfile(base.root_dir,'results','data','stage7a_9',mode);
    cfg.log_dir=fullfile(base.root_dir,'results','logs','stage7a_9');
    cfg.use_parallel=false;cfg.worker_count=0;
end
