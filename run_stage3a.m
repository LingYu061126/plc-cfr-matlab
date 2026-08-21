function result = run_stage3a(mode)
%RUN_STAGE3A Run the new communication-OFDM topology-awareness baseline.
%   Existing stage-1.5 through stage-2.3 experiments are not rerun here.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    ensure_result_dirs(default_config(root));
    test_stage3a();
    test_stage3a_1();
    test_stage3a_2();
    if strcmpi(mode,'audit')
        result=exp13_stage3a_1_audit(root);
    elseif strcmpi(mode,'audit_smoke')
        result=exp13_stage3a_1_audit(root,2);
    elseif strcmpi(mode,'parameter_aware')
        result=exp14_stage3a_1_parameter_aware(root);
    elseif strcmpi(mode,'model_validity')
        result=exp15_stage3a_2_model_validity(root);
    elseif strcmpi(mode,'protocol_audit')
        result=exp16_stage3a_2_protocol_audit(root);
    else
        result=exp12_stage3a_communication_baseline(mode);
    end
end
