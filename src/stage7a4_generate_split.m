function [samples,elapsed_s]=stage7a4_generate_split(candidates,truth_indices,base,cfg, ...
        seed_base,repetitions,snr_db,condition)
%STAGE7A4_GENERATE_SPLIT Independent labelled synthetic observation batch.
%   Labels/true theta stay in this experiment layer. Scoring only receives
%   samples(i).observed and fixed candidate templates/calibration models.
    if nargin<8||isempty(condition),condition='standard';end
    nv=numel(cfg.view_names);
    proto=struct('truth_global_index',0,'parameter_seed',0,'noise_seed',0, ...
        'theta',struct(),'modifiers',struct(),'clean',{cell(1,nv)}, ...
        'observed',{cell(1,nv)},'condition',condition);
    samples=repmat(proto,numel(truth_indices)*repetitions,1);cursor=0;t=tic;
    for i=1:numel(truth_indices)
        truth=truth_indices(i);
        for r=1:repetitions
            cursor=cursor+1;seed=seed_base+truth*100000+r;
            rs=RandStream('mt19937ar','Seed',seed);
            main=cfg.true_main_bounds(1)+diff(cfg.true_main_bounds)*rand(rs);
            theta=struct('main_length_scale',main,'branch_length_scale',1, ...
                'branch_load_scale',cfg.true_branch_load_scale, ...
                'first_segment_scale',1,'source_impedance_ohm',50, ...
                'receiver_impedance_ohm',50);
            mods=struct();
            switch char(condition)
                case 'standard'
                case 'first_segment_asymmetry'
                    theta.first_segment_scale=1.03;
                case 'termination_error'
                    mods.second_termination_error_fraction= ...
                        cfg.termination_error_fraction*(2*rand(rs)-1);
                case 'load_drift'
                    mods.second_branch_load_drift_fraction= ...
                        cfg.branch_load_drift_fraction*(2*rand(rs)-1);
                case 'node_port_error'
                    mods.node_port_error_fraction= ...
                        cfg.node_port_error_fraction*(2*rand(rs)-1);
                otherwise
                    error('stage7a4:UnknownCondition','Unknown test condition %s.',condition);
            end
            noise_seed=seed+1000000000;
            [clean,observed]=stage7a4_measure_views(candidates(truth).network, ...
                theta,base,cfg,noise_seed,snr_db,mods);
            samples(cursor)=struct('truth_global_index',truth, ...
                'parameter_seed',seed,'noise_seed',noise_seed,'theta',theta, ...
                'modifiers',mods,'clean',{clean},'observed',{observed}, ...
                'condition',condition);
        end
    end
    elapsed_s=toc(t);
end
