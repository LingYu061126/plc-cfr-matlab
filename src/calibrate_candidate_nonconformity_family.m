function model=calibrate_candidate_nonconformity_family(d,truth_index,ids,groups,alpha,options)
%CALIBRATE_CANDIDATE_NONCONFORMITY_FAMILY Freeze empirical physical scores.
if nargin<6,options=struct();end;ids=stage4a7_1_cellstr(ids);d=double(d);truth_index=truth_index(:);
if size(d,2)~=numel(ids)||numel(truth_index)~=size(d,1),error('stage4a7_2:CalibrationDimension','Calibration dimensions are inconsistent.');end
sc=getf(options,'scales',median(d,1,'omitnan'));sc(~isfinite(sc)|sc<=0)=1;f=score_candidate_nonconformity_family(d,ids,groups,sc);methods={'absolute','scaled','ratio','margin'};minc=getf(options,'minimum_per_candidate',1);cls=repmat(struct('candidate_id','','sample_count',0,'scores',struct(),'status','','minimum_attainable_p',NaN),1,numel(ids));
for j=1:numel(ids),ix=find(truth_index==j);cls(j).candidate_id=ids{j};cls(j).sample_count=numel(ix);cls(j).minimum_attainable_p=1/(numel(ix)+1);cls(j).status=ternary(numel(ix)>=minc,'calibrated','insufficient_calibration');for q=1:numel(methods),v=f.(methods{q});cls(j).scores.(methods{q})=sort(v(ix,j));end,end
model=struct('candidate_ids',{ids},'equivalence_group',{stage4a7_1_cellstr(groups)},'scales',sc,'classes',cls,'alpha',alpha,'minimum_per_candidate',minc,'status',ternary(all([cls.sample_count]>=minc),'calibrated','insufficient_calibration'),'definition_version','stage4a7_2_nonconformity_calibration_v1','calibration_hash',stage4a4_scientific_config_hash(struct('ids',{ids},'groups',{groups},'scales',sc,'alpha',alpha,'minimum',minc)));
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
