function out=run_stage4a4_candidate_confirmation(mode)
%RUN_STAGE4A4_CANDIDATE_CONFIRMATION Run smoke or formal Stage 4A.4.
    if nargin<1||isempty(mode),mode='formal';end
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));addpath(fullfile(root,'experiments'));
    cfg=default_config(root);sc=stage4a4_candidate_confirmation_config(cfg,mode);ensure_result_dirs(cfg);
    log_file=fullfile(root,'results','logs',sprintf('stage4a4_%s_run.log',lower(char(mode))));
    fid=fopen(log_file,'w');if fid<0,error('stage4a4:LogOpenFailed','Cannot initialize %s.',log_file);end;fclose(fid);
    diary('off');diary(log_file);cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('MATLAB version: %s\n',version);fprintf('Stage 4A.4 mode: %s\n',sc.mode);fprintf('Run entry: run_stage4a4_candidate_confirmation(%s)\n',sc.mode);fprintf('Log file: %s\n',log_file);
    [status,commit]=system('git rev-parse HEAD');fprintf('Git HEAD status=%d, commit=%s\n',status,strtrim(commit));
    [status,tree]=system('git status --short');fprintf('Git status status=%d, text=%s\n',status,strtrim(tree));
    fprintf('Seeds: training=%d calibration=%d validation=%d test=%d\n',sc.training_seed,sc.calibration_seed,sc.validation_seed,sc.test_seed);
    fprintf('Configured methods: %s\n',strjoin(sc.methods,', '));
    started=tic;
    try
        out=exp_stage4a4_candidate_confirmation(cfg,sc);
        fprintf('Stage 4A.4 exit status=0, total runtime %.3f s\n',toc(started));
        fprintf('Generated result prefix: %s\n',sc.output_prefix);
    catch ME
        fprintf('Stage 4A.4 exit status=1 after %.3f s\n',toc(started));
        fprintf('%s\n',getReport(ME,'extended','hyperlinks','off'));
        rethrow(ME);
    end
end
