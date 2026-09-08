function rows = stage4a7_2_r2_external_manifest(root_dir,derived_csv)
%STAGE4A7_2_R2_EXTERNAL_MANIFEST Logical-path provenance for ENWL material.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(derived_csv),derived_csv=fullfile(root_dir,'data','derived','enwl_uncertain_prior','stage4a7_2_r1_selected_public_subnetwork.csv');end
    % The external source cache is intentionally outside the Git repository;
    % only logical paths and hashes are written to the result manifest.
    d=fullfile(fileparts(root_dir),'materials','external_data','enwl_lvns','source');
    specs={
        'enwl_lvns_models_zip','lv-network-models-2.zip','materials/external_data/enwl_lvns/source/lv-network-models-2.zip', ...
        'https://www.enwl.co.uk/globalassets/innovation/lvns/lvns-academic/lv-network-models-2.zip', ...
        'archive member Lines.txt records Units=m; no conversion','m','identity_from_Lines_txt','verified_from_local_archive';
        'enwl_lvns_summary','summary-report.pdf','materials/external_data/enwl_lvns/source/summary-report.pdf', ...
        'https://www.enwl.co.uk/globalassets/innovation/lvns/lvns-academic/summary-report.pdf', ...
        'not_applicable','','','document_available';
        'enwl_lvns_closedown','lvns_closedown_report.pdf','materials/external_data/enwl_lvns/source/lvns_closedown_report.pdf', ...
        'https://www.ofgem.gov.uk/sites/default/files/docs/2017/04/lvns_closedown_report.pdf', ...
        'not_applicable','','','document_available';
        'derived_selected_subnetwork','stage4a7_2_r1_selected_public_subnetwork.csv', ...
        'data/derived/enwl_uncertain_prior/stage4a7_2_r1_selected_public_subnetwork.csv','repository-derived', ...
        'identity; source rows 32-38 Units=m','m','identity','derived_file_hash_recorded'};
    rows=repmat(row_template(),size(specs,1),1);
    for k=1:size(specs,1)
        rows(k).source_id=specs{k,1};rows(k).original_filename=specs{k,2};rows(k).relative_or_logical_path=specs{k,3};rows(k).source_url=specs{k,4};
        if k==4,p=derived_csv;else,p=fullfile(d,specs{k,2});end
        if exist(p,'file'),info=dir(p);rows(k).file_size_bytes=info.bytes;rows(k).sha256=stage4a7_2_r2_sha256_file(p);else,rows(k).file_size_bytes=NaN;end
        rows(k).retrieval_date='2026-09-08';rows(k).unit_original=specs{k,6};rows(k).unit_conversion=specs{k,7};rows(k).evidence_status=specs{k,8};rows(k).cable_mapping_status='controlled_model_mapping_not_measured_MHz_RLGC';
    end
end
function r=row_template(),r=struct('source_id','','original_filename','','relative_or_logical_path','','file_size_bytes',NaN,'sha256','','source_url','','retrieval_date','','unit_original','','unit_conversion','','evidence_status','','cable_mapping_status','');end
