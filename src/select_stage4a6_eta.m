function selected = select_stage4a6_eta(validation_rows,eta_candidates,max_false_alarm)
%SELECT_STAGE4A6_ETA Select extension using development validation only.
    if nargin<3,max_false_alarm=0.10;end;best=-Inf;selected=eta_candidates(1);
    for eta=eta_candidates,z=validation_rows([validation_rows.eta]==eta);ind=strcmp({z.parameter_domain_truth},'in_domain');out=strcmp({z.parameter_domain_truth},'out_of_domain');sus=strcmp({z.parameter_status},'parameter_out_suspected');fa=ratio(sum(ind&sus),sum(ind));rec=ratio(sum(out&sus),sum(out));score=rec;if isfinite(fa)&&fa>max_false_alarm,score=score-10*(fa-max_false_alarm);end;if score>best,best=score;selected=eta;end,end
end
function r=ratio(a,b),if b==0,r=NaN;else,r=a/b;end,end
