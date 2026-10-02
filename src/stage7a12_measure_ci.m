function out=stage7a12_measure_ci(ci,cfg,seed,condition)
%STAGE7A12_MEASURE_CI Synthetic low-frequency U=R*I+N, N-by-T in V/A.
%   Per-meter voltage time offsets are circular sample shifts. This is
%   deliberately separate from the 2-30 MHz PLC CFR observation.
    if nargin<4||isempty(condition),condition='asynchronous';end
    n=size(ci.R,1);t=cfg.lf_snapshots;
    rs=RandStream('mt19937ar','Seed',seed);
    I=cfg.lf_current_std_a*randn(rs,n,t);
    clean=ci.R*I;
    if strcmp(condition,'ideal')
        U=clean;shifts=zeros(n,1);
    else
        noise_std=cfg.lf_voltage_noise_std_v;
        if strcmp(condition,'high_noise'),noise_std=2*noise_std;end
        U=clean+noise_std*randn(rs,n,t);shifts=zeros(n,1);
        if ismember(condition,{'asynchronous','high_noise'})
            for k=1:n
                if rand(rs)<cfg.lf_shift_probability
                    shifts(k)=2*(rand(rs)>0.5)-1;
                    U(k,:)=circshift(U(k,:),[0 shifts(k)]);
                end
            end
        elseif ~strcmp(condition,'synchronous')
            error('stage7a12:Condition','Unknown LF condition.');
        end
    end
    out=struct('U',U,'I',I,'clean_U',clean,'shifts',shifts, ...
        'labels',{ci.labels},'condition',condition,'seed',seed);
end
