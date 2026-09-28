function out=stage7a10r1_derive_statistics(samples)
%STAGE7A10R1_DERIVE_STATISTICS Population-correct Wilson 95% audit.
%   samples is a table with one row per scored observation. Returns one row
%   per scenario/method/library/truth group/population/metric. An empty
%   population has NaN point estimate and interval, never a synthetic 0%.
    required={'scenario','method','library','truth_id','truth_in_library', ...
        'correct_unique','false_unique','truth_in_set','candidate_set_size', ...
        'decision_state'};
    assert(all(ismember(required,samples.Properties.VariableNames)), ...
        'stage7a10r1:StatisticColumns');
    scenarios=unique(string(samples.scenario));methods=unique(string(samples.method));
    libraries=unique(string(samples.library));truths=["ALL";unique(string(samples.truth_id))];
    populations=["all","in_library","out_library"];
    metrics=["correct_unique","truth_in_set","false_unique","nonempty_set", ...
        "UNIQUE_CONFIDENT","MULTIPLE_AMBIGUOUS","LOW_CONFIDENCE","REJECTED"];
    proto=struct('scenario',"",'method',"",'library',"",'truth_group',"", ...
        'population',"",'metric',"",'numerator',0,'denominator',0, ...
        'proportion',NaN,'wilson_low95',NaN,'wilson_high95',NaN, ...
        'applicability',"");
    rows=repmat(proto,0,1);
    for s=1:numel(scenarios)
        for m=1:numel(methods)
            for q=1:numel(libraries)
                for t=1:numel(truths)
                    base=string(samples.scenario)==scenarios(s)& ...
                        string(samples.method)==methods(m)& ...
                        string(samples.library)==libraries(q);
                    if t>1,base=base&string(samples.truth_id)==truths(t);end
                    if ~any(base),continue;end
                    for p=1:numel(populations)
                        pop=base;
                        if p==2,pop=pop&logical(samples.truth_in_library);end
                        if p==3,pop=pop&~logical(samples.truth_in_library);end
                        n=nnz(pop);
                        for j=1:numel(metrics)
                            metric=metrics(j);
                            if j<=2 && p~=2,continue;end
                            if j>=3 && j<=4 && p~=3,continue;end
                            if j==1,k=nnz(logical(samples.correct_unique(pop)));
                            elseif j==2,k=nnz(logical(samples.truth_in_set(pop)));
                            elseif j==3,k=nnz(logical(samples.false_unique(pop)));
                            elseif j==4,k=nnz(samples.candidate_set_size(pop)>0);
                            else,k=nnz(string(samples.decision_state(pop))==metric);end
                            r=proto;r.scenario=scenarios(s);r.method=methods(m);
                            r.library=libraries(q);r.truth_group=truths(t);
                            r.population=populations(p);r.metric=metric;
                            r.numerator=k;r.denominator=n;
                            if n==0
                                r.applicability="not_applicable";
                            else
                                r.proportion=k/n;
                                [r.wilson_low95,r.wilson_high95]=stage7a4_wilson(k,n);
                                r.applicability="applicable";
                            end
                            rows(end+1)=r; %#ok<AGROW>
                        end
                    end
                end
            end
        end
    end
    out=struct2table(rows);
end
