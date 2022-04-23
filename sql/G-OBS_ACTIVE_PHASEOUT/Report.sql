/*
 * Status Validations - Report.sql
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
select count(distinct tc_id)item_count
from &table_name
;

--INFO - Count RDDs
select count(distinct rdd_id)item_count
from &table_name
;

--INFO - Item Staged Twice 
select * from (
    select chk.*, count(*) over(
        partition by tc_id) count 
    from &table_name chk)
where count > 1
order by tc_id
;

--INFO - RDD Staged Twice 
select * from (
    select chk.*, count(*) over(
        partition by rdd_id, tc_id) count 
    from &table_name chk
    where rdd_id is not null)
where count > 1
order by rdd_id
;

/************** Teamcenter Checks ****************/
--ISSUE - Item Not Exist In TC
select /*+driving_site(dw)*/
    chk.*
from &table_name chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
where dw.tc_id is null
;

--ISSUE - RDD Not Exist In TC
select /*+driving_site(dw)*/
    chk.*
from &table_name chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.rdd_id
where chk.rdd_id is not null 
and dw.tc_id is null
;

--ISSUE - Part-RDD Relation Mismacth
select /*+driving_site(item)*/
    chk.tc_id, chk.rdd_id as given_rdd
    ,rel.rdd_id as actual_rdd
    ,rev.pitem_revision_id as on_max_rev_released
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
left join (
        select 
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on item.puid = iman.rsecondary_objectu
        ) rel on rel.rprimary_objectu = rev.puid
where nvl(chk.rdd_id, 'None') <> nvl(rel.rdd_id, 'None')
;

/************** Site/Group Checks ****************/
--INFO - Owining Group
select /*+driving_site(dw)*/
	dw.local_site
	,pgrp.pname as parent
	,dw.pname as owninggroup
	,count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
left join infodba.ppom_group@&linked_server grp on
	grp.pname = dw.pname
left join infodba.ppom_group@&linked_server pgrp on
	pgrp.puid = grp.rparentu 
group by dw.local_site, pgrp.pname, dw.pname
order by count(*) desc
;

/************** Type Checks ****************/
--INFO - Item Type
select /*+driving_site(dw)*/
	item_type, count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
group by dw.item_type
order by count(*) desc
;

-- ISSUE - Item Not A Part 
select /*+driving_site(dw)*/
	dw.tc_id, dw.item_type
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
where 
	item_type not in ('Nov4Part','Non-Engineering')
;

/************** Status Checks ****************/
--INFO - Item Status Current
select /*+driving_site(dw)*/
	dw.status, count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
group by dw.status
order by count(*) desc
;

--ISSUE - Item Lifecycle Current
select /*+driving_site(item)*/
    plifecycle, count(*)cnt
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
left join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
left join (
	select /*+driving_site(item)*/
		iman.rprimary_objectu, mf_info.plifecycle
		,frm.puid form_puid
	from 
		infodba.pimanrelation@&linked_server iman
		join infodba.pimantype@&linked_server rel on
			rel.puid = iman.rrelation_typeu
			and rel.ptype_name = 'IMAN_master_form'
		join infodba.pform@&linked_server frm on
			frm.puid = iman.rsecondary_objectu
		left join (
			select /*+driving_site(t)*/ puid, plifecycle from 
				infodba.pnoipartrevisionmaster@&linked_server t union
			select /*+driving_site(t)*/ puid, plifecycle from 
				infodba.pnoidocumentsrevisionmaster@&linked_server t union
			select /*+driving_site(t)*/ puid, plifecycle from 
				infodba.pitemversionmaster@&linked_server t
			) mf_info on mf_info.puid = frm.rdata_fileu
	) lfc on lfc.rprimary_objectu = rev.puid
group by plifecycle
order by count(*) desc
;

--INFO - Item Status to Update
select chk.status_new, count(*)count
from &table_name chk
group by chk.status_new
;

--ISSUE - Item is Superseded or Obsolete
select /*+driving_site(dw)*/
	chk.*
	,dw.pobject_name
	,dw.pobject_desc
	,dw.status
	,rel.ptype_name as reltype
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
	upper(dw.tc_id) = chk.tc_id
left join (
	select 
		distinct
		iman.rprimary_objectu
		,rel.ptype_name
	from 
		infodba.pimanrelation@&linked_server iman
		join infodba.pimantype@&linked_server rel on
			rel.puid = iman.rrelation_typeu
			and rel.ptype_name in ('Nov4_Superseded_by')
	) rel on rel.rprimary_objectu = dw.puid
where 
	dw.status in ('Superseded', 'Obsolete')
	or rel.ptype_name is not null
;


/************** Active Request Checks ****************/
--ISSUE - Item is Not Released
select /*+driving_site(item)*/
    chk.*
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
left join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
where 
	rev.puid is null
  and chk.status_new = 'ACTIVE'
;

--ISSUE - Item is Has No Alt ID
select /*+driving_site(item)*/
    chk.*
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
left join ( 
		select  
			altid.raltid_ofu
			,listagg(altid.pidfr_id||'@'||cntx.pidcxt_name,', ') 
				within group (order by cntx.pidcxt_name) as altid 
		from 
			infodba.pidentifier@&linked_server altid
			join infodba.pidcontext@&linked_server cntx on cntx.puid = altid.ridcontextu
		group by 
			altid.raltid_ofu
		) altid on altid.raltid_ofu = item.puid
where 
	altid.altid is null
  and chk.status_new = 'ACTIVE'
;

/************** Item Relation Checks ****************/
--INFO - Given Part-RDD Relation Not Match
select /*+driving_site(item)*/
    chk.tc_id, chk.rdd_id as given_rdd
    ,rel.rdd_id as actual_rdd
    ,rev.pitem_revision_id as on_max_rev_released
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = chk.tc_id
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
left join (
        select 
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on
                rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on
                item.puid = iman.rsecondary_objectu
        ) rel on rel.rprimary_objectu = rev.puid
where nvl(chk.rdd_id, 'None') <> nvl(rel.rdd_id, 'None')
;

--ISSUE - RDD Grp Different from Part Grp
select /*+driving_site(item)*/
    grp.pname as item_grp
    ,item.pitem_id
    ,rev.pitem_revision_id as max_rev_released
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
join z_max_rev_released@&linked_server rev on
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
where grp.pname <> rel.rdd_grp
;

--ISSUE - Related Part of Given Item (Doc) has Different Grp from Item (Doc) Grp
select /*+driving_site(item)*/
    grp.pname as doc_grp
    ,item.pitem_id as doc_id
    ,rev.pitem_revision_id as max_rev_released
    ,rel.rel_part_id
    ,rel.rel_part_grp
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
join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
join (
        select distinct
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
;

/************** Backup File ****************/
--Backup
select /*+driving_site(item)*/
	distinct
	dw.*
	,rev.pitem_revision_id as max_rev_working
	,rel.rdd_id
	,rel2.rpart_id as related_part
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = chk.tc_id
join infodba.pitem@&linked_server item on
	item.puid = dw.puid
join infodba.ppom_object@&linked_server obj on
	obj.puid = item.puid and 
	obj.rowning_siteu is null
join z_max_rev_working@&linked_server rev on
	rev.ritems_tagu = item.puid
left join (
	select
		distinct
		iman.rprimary_objectu
		,item.pitem_id as rdd_id
	from 
		infodba.pimanrelation@&linked_server iman
		join infodba.pimantype@&linked_server rel on
			rel.puid = iman.rrelation_typeu and 
			rel.ptype_name = 'RelatedDefiningDocument'
		join infodba.pitem@&linked_server item on
			item.puid = iman.rsecondary_objectu
	) rel on rel.rprimary_objectu = rev.puid
left join (
	select
		distinct
		iman.rsecondary_objectu
		,item.pitem_id as rpart_id
	from 
		infodba.pimanrelation@&linked_server iman
		join infodba.pimantype@&linked_server rel on
			rel.puid = iman.rrelation_typeu and 
			rel.ptype_name = 'RelatedDefiningDocument'
		join infodba.pitemrevision@&linked_server rev on
			rev.puid = iman.rprimary_objectu
		join infodba.pitem@&linked_server item on
			item.puid = rev.ritems_tagu
	) rel2 on rel2.rsecondary_objectu = item.puid
order by
	1
;

