function out=exp_stage7a4_continuous_dense_audit(root)
%EXP_STAGE7A4_CONTINUOUS_DENSE_AUDIT Audit local basins on independent D.
%   Uses first D scenario per truth/domain/length. This diagnostic is run
%   after formal T, but does not change its source, thresholds or results.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_continuous_fit_config(base,'formal');
    source=readtable(fullfile(cfg.output_dir, ...
        'continuous_clean_diagnostics.csv'),'TextType','string');
    selected=source(mod(source.diagnostic_seed,1000)==1,:);
    assert(height(selected)==numel(cfg.branch_lengths_m)*2*2);
    opts=optimset('TolX',cfg.optimizer_tol_x, ...
        'MaxFunEvals',cfg.optimizer_max_fun_evals,'Display','off');
    mgrid=linspace(cfg.main_scale_bounds(1), ...
        cfg.main_scale_bounds(2),401);
    out=repmat(struct('domain','','branch_length_m',NaN, ...
        'diagnostic_seed',0,'truth_id','','candidate_id','', ...
        'local_fit_rms_ohm',NaN,'dense_multistart_rms_ohm',NaN, ...
        'missed_improvement_ohm',NaN,'number_of_local_basins',0, ...
        'dense_load_values',4,'dense_main_points',401, ...
        'dense_best_main_scale',NaN,'dense_best_load_scale',NaN),0,1);
    started=tic;
    for li=1:numel(cfg.branch_lengths_m)
        [pair,bank]=weak_pair(base,cfg,cfg.branch_lengths_m(li));
        ix=find(selected.branch_length_m==cfg.branch_lengths_m(li));
        for row=ix(:).'
            x=selected(row,:);
            truth=find(strcmp(bank.candidate_ids,char(x.truth_id)));
            assert(numel(truth)==1);
            theta=theta_at(x.truth_main_scale,x.truth_load_scale);
            z=stage7a4_forward_state(pair(truth).network,theta,base, ...
                cfg.frequency_hz,cfg.state);
            y=z.Zin;
            fit=stage7a4_continuous_profile_zin(y,pair,bank,base,cfg,1);
            for k=1:2
                load_values=unique([cfg.load_scale_bounds(1),1, ...
                    cfg.load_scale_bounds(2),fit.continuous_params(k,2)]);
                best=fit.continuous_distances(k)^2;
                best_main=fit.continuous_params(k,1);
                best_load=fit.continuous_params(k,2);basins=0;
                for j=1:numel(load_values)
                    load=load_values(j);f=zeros(size(mgrid));
                    for m=1:numel(mgrid)
                        f(m)=residual_sq(mgrid(m),load,y, ...
                            pair(k).network,base,cfg);
                    end
                    local=[1,find(f(2:end-1)<=f(1:end-2)& ...
                        f(2:end-1)<=f(3:end))+1,numel(mgrid)];
                    for p=unique(local)
                        lo=mgrid(max(1,p-1));hi=mgrid(min(numel(mgrid),p+1));
                        if lo==hi,main=lo;val=f(p);
                        else
                            [main,val]=fminbnd(@(m)residual_sq(m,load,y, ...
                                pair(k).network,base,cfg),lo,hi,opts);
                        end
                        basins=basins+1;
                        if val<best,best=val;best_main=main;best_load=load;end
                    end
                end
                q=out_row(x,bank.candidate_ids{k},fit.continuous_distances(k), ...
                    sqrt(best),basins,best_main,best_load);
                out(end+1)=q; %#ok<AGROW>
            end
            fprintf('Dense D seed %d: %.2f s elapsed.\n', ...
                x.diagnostic_seed,toc(started));
        end
    end
    writetable(struct2table(out),fullfile(cfg.output_dir, ...
        'continuous_dense_audit.csv'));
    assert(all([out.missed_improvement_ohm]>=-1e-10));
    fprintf('Dense audit complete: %d candidate fits, maximum missed improvement %.6g ohm, %.2f s.\n', ...
        numel(out),max([out.missed_improvement_ohm]),toc(started));
end

function r=out_row(x,candidate_id,local,best,basins,main,load)
    r=struct('domain',char(x.domain), ...
        'branch_length_m',x.branch_length_m, ...
        'diagnostic_seed',x.diagnostic_seed, ...
        'truth_id',char(x.truth_id),'candidate_id',candidate_id, ...
        'local_fit_rms_ohm',local, ...
        'dense_multistart_rms_ohm',best, ...
        'missed_improvement_ohm',local-best, ...
        'number_of_local_basins',basins, ...
        'dense_load_values',4,'dense_main_points',401, ...
        'dense_best_main_scale',main, ...
        'dense_best_load_scale',load);
end

function [pair,bank]=weak_pair(base,cfg,length_m)
    [all4,~,~]=stage7a4_fixed_topologies(base);
    pair=all4([3 4]);pair(1).topology_id='WEAK_M1';
    pair(2).topology_id='WEAK_M3';
    for k=1:2
        pair(k).network.branches.length=length_m;
        pair(k).network.branches.load=cfg.branch_load_ohm;
    end
    [m,l]=ndgrid(cfg.main_scale_grid,cfg.branch_load_grid);
    params=[m(:),l(:),ones(numel(m),1)];
    templates=cell(2,1);
    for k=1:2
        templates{k}=complex(zeros(size(params,1),numel(cfg.frequency_hz)));
        for p=1:size(params,1)
            z=stage7a4_forward_state(pair(k).network, ...
                theta_at(params(p,1),params(p,2)),base, ...
                cfg.frequency_hz,cfg.state);
            templates{k}(p,:)=z.Zin;
        end
    end
    bank=struct('templates',{templates},'params',params, ...
        'candidate_ids',{{'WEAK_M1','WEAK_M3'}}, ...
        'view_names',{{'Zin50'}},'frequency_hz',cfg.frequency_hz, ...
        'identity','dense_D');
end

function theta=theta_at(main,load)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
end

function value=residual_sq(main,load,y,network,base,cfg)
    z=stage7a4_forward_state(network,theta_at(main,load),base, ...
        cfg.frequency_hz,cfg.state);
    value=mean(abs(z.Zin-y).^2);
end
