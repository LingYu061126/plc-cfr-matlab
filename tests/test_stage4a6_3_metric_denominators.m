function test_stage4a6_3_metric_denominators()
%TEST_STAGE4A6_3_METRIC_DENOMINATORS Zero denominators use NaN, not zero.
    ci=stage4a6_3_wilson_interval(0,0);assert(all(isnan(ci)));
    ci=stage4a6_3_wilson_interval(5,10);assert(ci(1)>=0 && ci(2)<=1 && ci(1)<=0.5 && ci(2)>=0.5);
end
