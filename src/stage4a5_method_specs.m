function specs = stage4a5_method_specs(sc)
%STAGE4A5_METHOD_SPECS Enumerate the predeclared development candidates.
    specs=repmat(spec_template(),0,1);specs(end+1)=make('M0',0,0.90,5,0);
    for M=sc.subband_counts
        for q=sc.subband_quantiles,specs(end+1)=make('M1',M,q,5,0);end %#ok<AGROW>
    end
    for M=sc.subband_counts
        for q=sc.subband_quantiles
            for K=sc.neighborhood_K,specs(end+1)=make('M2',M,q,K,0);end %#ok<AGROW>
        end
    end
    for M=sc.subband_counts
        for q=sc.subband_quantiles
            for K=sc.neighborhood_K
                for t=sc.stability_thresholds,specs(end+1)=make('M3',M,q,K,t);end %#ok<AGROW>
            end
        end
    end
end
function s=make(f,M,q,K,t),s=spec_template();s.family=f;s.M=M;s.q=q;s.K=K;s.stability_threshold=t;s.method_id=method_name(s);end
function s=spec_template(),s=struct('family','','M',0,'q',0,'K',0,'stability_threshold',0,'method_id','');end
function n=method_name(s),n=sprintf('%s_M%d_q%03d_K%d_qs%02d',s.family,s.M,round(1000*s.q),s.K,round(100*s.stability_threshold));end
