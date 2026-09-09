function sc=stage4a7_2_r2_1_1_protocol_config(base,mode)
%STAGE4A7_2_R2_1_1_PROTOCOL_CONFIG Independent corrective-closure config.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='formal';end
    output_root=fullfile(base.root_dir,'results','data','stage4a7_2_r2_1_1');
    sc=stage4a7_2_r2_1_protocol_config(base,mode,output_root,'Stage 4A.7.2-R.2.1.1');
    sc.version='4a7_2_r2_1_1_corrective_closure_v1';
    sc.results_logs=fullfile(base.root_dir,'results','logs','stage4a7_2_r2_1_1');
    sc.paired=struct('master_seed',20262961,'replicates',2,'target_parameter','main_length_scale', ...
        'categories',{{'in_domain','boundary_lower','boundary_upper','parameter_ood_near','parameter_ood_medium','parameter_ood_far'}}, ...
        'values',[1.0,0.951,1.049,1.10,1.30,1.60],'noise_snr_db',20, ...
        'transition_bootstrap_replicates',2000,'transition_bootstrap_seed',20262962, ...
        'description','same candidate and nuisance theta/noise base across category pairs; only target parameter changes');
    sc.equivalence=struct('numerical_tolerance',1e-10,'noise_resolution_threshold',NaN,'scope','same_theta_all_pairs_and_cross_theta_nearest_pairs');
    sc.final_reserved.status='manifest_only_not_materialized';
end
