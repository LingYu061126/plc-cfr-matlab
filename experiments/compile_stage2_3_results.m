function output=compile_stage2_3_results(cfg)
%COMPILE_STAGE2_3_RESULTS Stream sealed batches without loading all raw MATs.
    if nargin<1||isempty(cfg),cfg=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    files=dir(fullfile(cfg.results_data,'stage2_3_partial_*_results.mat'));
    if numel(files)<14,error('compile_stage2_3_results:MissingBatch','Expected 14 sealed formal batches.');end
    pairwise=[];config=[];confusion=[];summary=[];manifest=cell(0,1);elapsed=0;
    final_csv=fullfile(cfg.results_data,'stage2_3_trials.csv');fid=fopen(final_csv,'w');assert(fid>0,'Cannot create final trial CSV.');cleanup=onCleanup(@()fclose(fid));
    wrote_header=false;
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);x=load(path,'pairwise','summary','confusion','config','elapsed','mode');
        % All result arrays here are small; raw records stay in sealed files.
        pairwise=[pairwise;x.pairwise(:)];config=[config;x.config(:)];confusion=[confusion;x.confusion(:)];summary=[summary;x.summary(:)]; %#ok<AGROW>
        elapsed=elapsed+x.elapsed;manifest{end+1}=path; %#ok<AGROW>
        csv_path=strrep(path,'_results.mat','_trials.csv');append_csv(fid,csv_path,wrote_header);wrote_header=true;
    end
    summary=merge_summary(summary);confusion=aggregate_confusion(confusion);[pairwise,config]=deduplicate_geometry(pairwise,config);
    writetable(struct2table(pairwise),fullfile(cfg.results_data,'stage2_3_pairwise_distance.csv'));writetable(struct2table(summary),fullfile(cfg.results_data,'stage2_3_summary.csv'));writetable(struct2table(confusion),fullfile(cfg.results_data,'stage2_3_confusion.csv'));writetable(struct2table(config),fullfile(cfg.results_data,'stage2_3_config.csv'));
    save(fullfile(cfg.results_data,'stage2_3_results.mat'),'pairwise','summary','confusion','config','manifest','elapsed','-v7');
    make_figures(cfg,pairwise,summary,config);output=struct('summary',summary,'pairwise',pairwise,'confusion',confusion,'manifest',{manifest},'elapsed_s',elapsed);
    fprintf('Stream-compiled %d sealed batches; raw rows remain in %d batch MAT files.\n',numel(files),numel(manifest));
end
function append_csv(out,path,skip_header)
    in=fopen(path,'r');assert(in>0,'Missing batch CSV: %s',path);c=onCleanup(@()fclose(in));
    if skip_header,fgetl(in);end
    while true,line=fgetl(in);if ~ischar(line),break;end;fprintf(out,'%s\n',line);end
end
function merged=merge_summary(rows)
    key=arrayfun(@(x)sprintf('%s|%s|%g|%s|%s',x.measurement_kind,x.condition,x.snr_db,x.method,x.feature),rows,'UniformOutput',false);keys=unique(key,'stable');merged=repmat(rows(1),0,1);
    for k=1:numel(keys)
        x=rows(strcmp(key,keys{k}));r=x(1);w=[x.sample_count];n=sum(w);r.sample_count=n;r.trials=sum([x.trials]);
        fields={'strict_accuracy','equivalence_class_accuracy','unique_strict_accuracy','ambiguity_rate','false_unique_rate','mean_margin','mean_intra','mean_inter','nmse','amplitude_rmse_db','raw_phase_rmse_deg','weighted_phase_rmse_deg','valid_phase_fraction','runtime_s','edge_precision','edge_recall','edge_f1'};
        for f=1:numel(fields),r.(fields{f})=sum(w.*[x.(fields{f})])/n;end
        % Combine 50-trial standard deviations into the exact pooled trial SD.
        mu=[x.strict_accuracy];sd=[x.accuracy_std];nt=[x.trials];grand=sum(mu.*nt)/sum(nt);ss=sum((nt-1).*sd.^2+nt.*(mu-grand).^2);r.accuracy_std=sqrt(ss/(sum(nt)-1));half=1.96*r.accuracy_std/sqrt(sum(nt));r.ci_low=max(0,grand-half);r.ci_high=min(1,grand+half);r.intra_inter_ratio=r.mean_intra/r.mean_inter;merged(end+1)=r; %#ok<AGROW>
    end
end
function out=aggregate_confusion(in)
    key=arrayfun(@(x)sprintf('%s|%s|%g|%s|%s|%s',x.measurement_kind,x.condition,x.snr_db,x.method,x.true_id,x.predicted_id),in,'UniformOutput',false);keys=unique(key,'stable');out=repmat(in(1),0,1);for k=1:numel(keys),x=in(strcmp(key,keys{k}));r=x(1);r.count=sum([x.count]);out(end+1)=r;end %#ok<AGROW>
end
function [p,c]=deduplicate_geometry(p,c)
    [~,ix]=unique({p.measurement_kind},'stable');p=p(sort(ix));[~,ix]=unique({c.measurement_kind},'stable');c=c(sort(ix));
end
function make_figures(cfg,pairwise,summary,config)
    kinds={config.measurement_kind};figure('Visible','off','Position',[100 100 1400 800]);tiledlayout(2,4,'Padding','compact');for k=1:numel(kinds),nexttile;z=pairwise(strcmp({pairwise.measurement_kind},kinds{k}));ids=unique([{z.topology_i},{z.topology_j}],'stable');M=zeros(numel(ids));for q=1:numel(z),i=find(strcmp(ids,z(q).topology_i));j=find(strcmp(ids,z(q).topology_j));M(i,j)=z(q).complex_distance;M(j,i)=M(i,j);end;imagesc(M);axis image;colorbar;set(gca,'XTick',1:numel(ids),'XTickLabel',ids,'YTick',1:numel(ids),'YTickLabel',ids);title(strrep(kinds{k},'_',' '));end;sgtitle('Full-complex CFR pairwise distances');print(gcf,fullfile(cfg.results_figures,'stage2_3_observability_matrix.png'),'-dpng','-r150');close(gcf);
    z=summary(strcmp({summary.condition},'noise_only')&[summary.snr_db]==20&strcmp({summary.feature},'amp_phase_joint_weighted')&strcmp({summary.method},'nominal_nearest'));figure('Visible','off');bar([z.strict_accuracy;z.equivalence_class_accuracy;z.unique_strict_accuracy]');grid on;set(gca,'XTickLabel',strrep({z.measurement_kind},'_',' '),'XTickLabelRotation',25);legend('strict','class','unique');print(gcf,fullfile(cfg.results_figures,'stage2_3_measurement_comparison.png'),'-dpng','-r150');close(gcf);
    z=summary(strcmp({summary.feature},'amp_phase_joint_weighted')&[summary.snr_db]==20&ismember({summary.method},{'nominal_nearest','nuisance_aware_joint'})&ismember({summary.condition},{'noise_only','joint'}));figure('Visible','off');bar([z.strict_accuracy]);grid on;set(gca,'XTick',1:numel(z),'XTickLabel',strrep(strcat({z.measurement_kind},' ',{z.condition},' ',{z.method}),'_',' '),'XTickLabelRotation',55,'FontSize',7);print(gcf,fullfile(cfg.results_figures,'stage2_3_algorithm_fair_comparison.png'),'-dpng','-r150');close(gcf);
end
