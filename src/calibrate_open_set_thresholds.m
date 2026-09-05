function t=calibrate_open_set_thresholds(decisions,sc)
d=[decisions.best_distance];m=[decisions.margin];t=struct('name','model-internal calibration threshold','residual',quant(d,sc.quantile)*sc.safety_factor,'margin',quant(m,sc.margin_quantile),'sample_count',numel(d),'quantile',sc.quantile,'safety_factor',sc.safety_factor);
end
function q=quant(x,p),x=sort(x(isfinite(x)));q=x(max(1,min(numel(x),round(1+(numel(x)-1)*p))));end
