function out=stage7a12_ci_matrix(network,cfg,visible_branches)
%STAGE7A12_CI_MATRIX Independent low-frequency common-path resistance.
%   R is N-by-N ohm for measured RX and B1..Bv. Intermediate main
%   junctions are hidden, not fictitious meters. Main/branch
%   lengths are m; cfg.r_main_ohm_per_m and r_branch_ohm_per_m are
%   independent low-frequency assumptions, not MHz characteristic Zin.
    m=numel(network.main_lengths);nb=numel(network.branches);
    if nargin<3||isempty(visible_branches),visible_branches=1:nb;end
    visible_branches=visible_branches(:).';
    assert(all(ismember(visible_branches,1:nb))&& ...
        numel(unique(visible_branches))==numel(visible_branches), ...
        'stage7a12:VisibleBranchIdentity');
    assert(all(isfinite(network.main_lengths))&& ...
        all(network.main_lengths>0),'stage7a12:InvalidMainLength');
    n=1+numel(visible_branches);p=zeros(n,m+nb);
    labels=cell(1,n);
    p(1,1:m)=1;labels{1}='RX';
    edge_r=[network.main_lengths(:).' * cfg.r_main_ohm_per_m, ...
        zeros(1,nb)];
    for b=1:nb
        branch=network.branches(b);
        assert(branch.node>=1&&branch.node<m&& ...
            branch.node==fix(branch.node)&&branch.length>0&& ...
            isfinite(branch.length),'stage7a12:InvalidBranch');
        edge_r(m+b)=branch.length*cfg.r_branch_ohm_per_m;
    end
    for j=1:numel(visible_branches)
        b=visible_branches(j);k=1+j;node=network.branches(b).node;
        p(k,1:node)=1;p(k,m+b)=1;
        labels{k}=sprintf('B%d',b);
    end
    R=(p.*edge_r)*p.';
    out=struct('R',R,'labels',{labels},'path_matrix',p, ...
        'edge_resistance_ohm',edge_r,'visible_branches',visible_branches);
end
