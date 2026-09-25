function schemes=stage7a4_scheme_catalog(cfg,b_term_index,c_node_index)
%STAGE7A4_SCHEME_CATALOG Label fixed observation/cost combinations.
%   B and C indices are selected using D only, before final T evaluation.
    assert(ismember(b_term_index,1:numel(cfg.termination_ohm)));
    assert(ismember(c_node_index,1:numel(cfg.node_indices)));
    e=struct('name','','stage','','view_indices',[],'measurement_count',0, ...
        'receiver_port_count',0,'changes_termination',false, ...
        'receiver_ohm',NaN,'node_index',0,'needs_zin',false);
    schemes=repmat(e,0,1);
    schemes(end+1)=item(e,'A0_H50','A0',5,1,1,false,50,0,false);
    schemes(end+1)=item(e,'A0_Zin50','A0',6,1,1,false,50,0,true);
    schemes(end+1)=item(e,'A0_H50_Zin50','A0',[5 6],1,1,false,50,0,true);
    for k=1:numel(cfg.termination_ohm)
        if k==3,continue;end
        zr=cfg.termination_ohm(k);tag=strrep(sprintf('%g',zr),'.','p');
        schemes(end+1)=item(e,['A1_H_' tag],'A1',2*k-1,1,1,true,zr,0,false);
        schemes(end+1)=item(e,['A1_Zin_' tag],'A1',2*k,1,1,true,zr,0,true);
        schemes(end+1)=item(e,['A1_H_Zin_' tag],'A1',[2*k-1 2*k],1,1,true,zr,0,true);
    end
    schemes(end+1)=item(e,'B_H50_repeat','B',[5 numel(cfg.view_names)],2,1,false,50,0,false);
    zr=cfg.termination_ohm(b_term_index);
    schemes(end+1)=item(e,'B_H50_Hsecond','B',[5 2*b_term_index-1],2,1,true,zr,0,false);
    j=2*numel(cfg.termination_ohm)+2*c_node_index-1;
    node=cfg.node_indices(c_node_index);
    schemes(end+1)=item(e,'C_Hendpoint_loaded','C',j,1,2,false,50,node,false);
    schemes(end+1)=item(e,'C_Hnode','C',j+1,1,2,false,50,node,false);
    schemes(end+1)=item(e,'C_Hendpoint_Hnode','C',[j j+1],1,2,false,50,node,false);
end
function out=item(proto,name,stage,views,nmeasure,nports,changed,zr,node,zin)
    out=proto;out.name=name;out.stage=stage;out.view_indices=views;
    out.measurement_count=nmeasure;out.receiver_port_count=nports;
    out.changes_termination=changed;out.receiver_ohm=zr;out.node_index=node;
    out.needs_zin=zin;
end
