/*
 * Ownership Validations - Report.sql
 * Substitution Variables: table_name, linked_server.
 * To set all varibles run the below `define` commands:

 		set define on
 		define table_name = TABLE_NAME
        define linked_server = LINKED_SERVER

 * Additionally, if you want to unset a variable run the `undefine`
 * command followed by the variable you want to unset.
 */

/************** Data Checks ****************/
--INFO - Total Rows
select count(*)row_count
from &table_name
;

--INFO - Count Items
select 
	count(distinct tc_id)item_count
from &table_name
;

--INFO - Item Staged Twice 
select * from (
	select chk.*, count(*) over (
		partition by tc_id ) as count
	from &table_name chk )
where count > 1
order by tc_id
;

/************** Teamcenter Checks ****************/
--ISSUE - Item Not Exist in TC
select /*+driving_site(dw)*/
    chk.*
from &table_name chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
where dw.tc_id is null
;

/************** Group Checks ****************/
--ISSUE - Current Owining Group Not as Given
select /*+driving_site(dw)*/
	dw.tc_id
    ,chk.grp_old as grp_given
    ,grp.pname as grp_actual
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
join infodba.ppom_group@&linked_server grp on
    grp.pname = dw.pname
where regexp_substr(chk.grp_old, '^[^\.]+') <> grp.pname
;

--INFO - Current Owining Group
select /*+driving_site(dw)*/
    dw.local_site
    ,pgrp.pname as parent
    ,dw.pname as owninggroup
    ,gdim."ERPS"
    ,count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
join infodba.ppom_group@&linked_server grp on
    grp.pname = dw.pname
left join infodba.ppom_group@&linked_server pgrp on
    pgrp.puid = grp.rparentu 
left join cdmrpt.dim_group_master@cdmdw gdim on 
	gdim.group_name = dw.pname
group by dw.local_site, pgrp.pname, dw.pname, gdim."ERPS"
order by count(*) desc
;

--INFO - New Owining Group
select /*+driving_site(dw)*/
    dw.local_site
    ,pgrp.pname as parent
    ,chk.grp_new as grp
    ,gdim."ERPS"
    ,count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
join infodba.ppom_group@&linked_server grp on
    grp.pname = chk.grp_new
left join infodba.ppom_group@&linked_server pgrp on
    pgrp.puid = grp.rparentu 
left join cdmrpt.dim_group_master@cdmdw gdim on 
	gdim.group_name = chk.grp_new
group by dw.local_site, pgrp.pname, chk.grp_new, gdim."ERPS"
order by count(*) desc
;

/************** Type Checks ****************/
--INFO - TC Types
select /*+driving_site(dw)*/
    dw.item_type as tc_itemtype
    ,count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
group by dw.item_type
order by count(*) desc
;

--INFO - RSOne Types
select /*+driving_site(item)*/
    pm.prsone_itemtype
    ,count(*)count
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.pimanrelation@&linked_server iman on
	iman.rprimary_objectu = item.puid
join infodba.pimantype@&linked_server rel on
	rel.puid = iman.rrelation_typeu and
	rel.ptype_name = 'IMAN_master_form'
join infodba.pform@&linked_server frm on
	frm.puid = iman.rsecondary_objectu	 
left join (
	select puid, prsone_itemtype, prsone_uom 
		from infodba.pnoipartmaster@&linked_server union
  	select puid, prsone_itemtype, prsone_uom 
  		from infodba.pnoinonengineeringmaster@&linked_server
	) pm on pm.puid = frm.rdata_fileu	 
group by pm.prsone_itemtype
order by count(*) desc
;

/************** Status Checks ****************/
--ISSUE - Item is Superseded
select /*+driving_site(dw)*/ 
	*
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
where dw.status = 'Superseded'
;

--INFO - Status Current
select /*+driving_site(dw)*/
    dw.status, count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
group by dw.status
order by count(*) desc
;

--INFO - Item Not Released
select /*+driving_site(item)*/
	count(*)count
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
left join z_max_rev_released@&linked_server r on
    r.ritems_tagu = item.puid
where r.puid is null
;

/************** Alt ID Checks ****************/
--INFO - ERP Contexts
select /*+driving_site(erp)*/ 
    pidcxt_name as erp_context
    ,count(*)count
from &table_name chk
left join altid_all_site erp on 
    upper(erp.pitem_id) = chk.tc_id
group by pidcxt_name
;

/************** Item Relation Checks ****************/
--INFO - Item Has RDD
select /*+driving_site(item)*/
    count(*) as count
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
join (
        select 
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
            ,grp.pname as rdd_grp
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on
                item.puid = iman.rsecondary_objectu
            join infodba.ppom_application_object@&linked_server abj on
                abj.puid = item.puid
            join infodba.ppom_group@&linked_server grp on
                grp.puid = abj.rowning_groupu
        ) rel on rel.rprimary_objectu = rev.puid
;

--ISSUE - RDD Grp Different from Part Grp
select /*+driving_site(item)*/
    grp.pname as grp
    ,chk.tc_id
    ,rev.pitem_revision_id as max_rev_working
    ,rel.rdd_id
    ,rel.rdd_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
join (
        select /*+driving_site(iman)*/
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
            ,grp.pname as rdd_grp
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on
                item.puid = iman.rsecondary_objectu
            join infodba.ppom_application_object@&linked_server abj on
                abj.puid = item.puid
            join infodba.ppom_group@&linked_server grp on
                grp.puid = abj.rowning_groupu
        ) rel on rel.rprimary_objectu = rev.puid
where grp.pname <> rel.rdd_grp
;

--ISSUE - Related Part of Given Part's RDD has Different Grp
select /*+driving_site(item)*/
    grp.pname as grp
    ,chk.tc_id
    ,rev.pitem_revision_id as max_rev_working
    ,rel.rdd_id
    ,rel.rdd_grp
    ,rel.rel_partid
    ,rel.rel_partgrp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
join (
        select /*+driving_site(iman)*/
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
            ,grp.pname as rdd_grp
            ,rel.rel_partid
            ,rel.rel_partgrp
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on
                item.puid = iman.rsecondary_objectu
            join infodba.ppom_application_object@&linked_server abj on
                abj.puid = item.puid
            join infodba.ppom_group@&linked_server grp on
                grp.puid = abj.rowning_groupu
			join (
			        select /*+driving_site(iman)*/ 
			        	distinct
			            iman.rsecondary_objectu
			            ,item.pitem_id as rel_partid
			            ,grp.pname as rel_partgrp
			        from 
			            infodba.pimanrelation@&linked_server iman
			            join infodba.pimantype@&linked_server rel on
			                rel.puid = iman.rrelation_typeu
			                and rel.ptype_name = 'RelatedDefiningDocument'
			            join infodba.pitemrevision@&linked_server rev on
			            	rev.puid = iman.rprimary_objectu
			            join infodba.pitem@&linked_server item on
			                item.puid = rev.ritems_tagu
			            join infodba.ppom_application_object@&linked_server abj on
			                abj.puid = item.puid
			            join infodba.ppom_group@&linked_server grp on
			                grp.puid = abj.rowning_groupu
			        ) rel on rel.rsecondary_objectu = item.puid
        ) rel on rel.rprimary_objectu = rev.puid
where grp.pname <> rel.rel_partgrp
and not exists (
	select 1 from &table_name chk2
	where chk2.tc_id = rel.rel_partid
	or chk2.grp_new = rel.rel_partgrp )
order by item.pitem_id, rdd_id, rel_partid
;

--ISSUE - Related Part of Given Doc has Different Grp from Doc Grp
select /*+driving_site(item)*/
    grp.pname as grp
    ,item.pitem_id as doc_id
    ,rev.pitem_revision_id as max_rev_working
    ,rel.rel_part_id
    ,rel.rel_part_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.pworkspaceobject@&linked_server wbj on
	wbj.puid = item.puid 
	and wbj.pobject_type = 'Documents'
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
join (
        select /*+driving_site(iman)*/ 
        	distinct
            iman.rsecondary_objectu
            ,item.pitem_id as rel_part_id
            ,grp.pname as rel_part_grp
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitemrevision@&linked_server rev on
                rev.puid = iman.rprimary_objectu
            join infodba.pitem@&linked_server item on
                item.puid = rev.ritems_tagu
            join infodba.ppom_application_object@&linked_server abj on
                abj.puid = item.puid
            join infodba.ppom_group@&linked_server grp on
                grp.puid = abj.rowning_groupu
        ) rel on rel.rsecondary_objectu = item.puid
where grp.pname <> rel.rel_part_grp
and not exists (
	select 1 from &table_name chk2
	where chk2.grp_new = rel.rel_part_grp
	or chk2.tc_id = rel.rel_part_id )
;

/************** Backup File ****************/
--Backup
select /*+driving_site(item)*/
    chk.tc_id
    ,grp.pname as item_grp
    ,usr.puser_id item_usr
    ,sta.pname as status
    ,rev.pitem_revision_id as max_rev_working
    ,grp_rev.pname as rev_grp
    ,wbj_rev.pdate_released
    ,rel.rdd_id
    ,rel.rdd_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join infodba.ppom_user@&linked_server usr on
	usr.puid = abj.rowning_useru
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
join infodba.ppom_application_object@&linked_server abj_rev on
    abj_rev.puid = rev.puid
join infodba.ppom_group@&linked_server grp_rev on
    grp_rev.puid = abj_rev.rowning_groupu
join infodba.pworkspaceobject@&linked_server wbj_rev on
	wbj_rev.puid = rev.puid
left join (
        select /*+driving_site(iman)*/
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
            ,grp.pname as rdd_grp
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on
                item.puid = iman.rsecondary_objectu
            join infodba.ppom_application_object@&linked_server abj on
                abj.puid = item.puid
            join infodba.ppom_group@&linked_server grp on
                grp.puid = abj.rowning_groupu
        ) rel on rel.rprimary_objectu = rev.puid
left join infodba.prelease_status_list@&linked_server rsl on
    rsl.puid = item.puid
left join infodba.preleasestatus@&linked_server sta on
    sta.puid = rsl.pvalu_0
;
