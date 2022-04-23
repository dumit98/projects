/*
 * Ownership Validations - Input_Util.sql
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
    count(distinct sup_id)sup_count
    ,count(distinct sur_id)sur_count
    ,count(distinct sup_id)
        +count(distinct sur_id) as total
from &table_name
;

--INFO - Item Staged Twice 
select * from (
    select chk.*, count(*) over(
        partition by sup_id) count 
    from &table_name chk)
where count > 1
order by sup_id
;

/************** Teamcenter Checks ****************/
--ISSUE - Superseded Not Exist In DW
select /*+driving_site(dw)*/
    chk.sup_id
from &table_name chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sup_id)
where dw.tc_id is null
;

--ISSUE - Survivor Not Exist In DW
select /*+driving_site(dw)*/
    chk.sur_id
from (select distinct sur_id from &table_name) chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sur_id)
where dw.tc_id is null
;

/************** Site/Group Checks ****************/
--INFO - Superseded Owining Group
select /*+driving_site(dw)*/
    dw.local_site
    ,pgrp.pname as parent
    ,dw.pname as owninggroup
    ,count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sup_id)
left join infodba.ppom_group@&linked_server grp on
    grp.pname = dw.pname
left join infodba.ppom_group@&linked_server pgrp on
    pgrp.puid = grp.rparentu 
group by dw.local_site, pgrp.pname, dw.pname
order by 1, 4 desc
;

--INFO - Survivor Owining Group
select /*+driving_site(dw)*/
    dw.local_site
    ,pgrp.pname as parent
    ,dw.pname as owninggroup
    ,count(*)count
from (select distinct sur_id from &table_name) chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sur_id)
left join infodba.ppom_group@&linked_server grp on
    grp.pname = dw.pname
left join infodba.ppom_group@&linked_server pgrp on
    pgrp.puid = grp.rparentu 
group by dw.local_site, pgrp.pname, dw.pname
order by 1, 4 desc
;

/************** Type Checks ****************/
--INFO - Superseded Item Type
select /*+driving_site(dw)*/
    item_type, count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sup_id)
group by dw.item_type
order by count(*) desc
;

--INFO - Survivor Item Type
select /*+driving_site(dw)*/
    item_type, count(*)count
from (select distinct sur_id from &table_name) chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sur_id)
group by dw.item_type
order by count(*) desc
;

/************** Status Checks ****************/
--INFO - Superseded Status Current
select /*+driving_site(dw)*/
    dw.status, count(*)count
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sup_id)
group by dw.status
order by count(*) desc
;

--INFO - Survivor Status Current
select /*+driving_site(dw)*/
    dw.status, count(*)count
from (select distinct sur_id from &table_name) chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.sur_id)
group by dw.status
order by count(*) desc
;

--INFO - Superseded Not Released
select count(*) as count
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
left join z_max_rev_released@&linked_server r on
    r.ritems_tagu = item.puid
where r.puid is null
;

--INFO - Survivor Not Released
select count(*) as count
from (select distinct sur_id from &table_name) chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sur_id)
left join z_max_rev_released@&linked_server r on
    r.ritems_tagu = item.puid
where r.puid is null
;

--ISSUE - Item Is Currently Superseded 
select chk.*
	,sup.survivor_id as superseded_by
from (
		select sup_id tc_id, 'Superseded' type 
		from &table_name
	union 
		select sur_id tc_id, 'Survivor' type 
		from &table_name
		) chk 
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.tc_id)
left join cdmrpt.chk_superseded_items@cdmdw sup on 
	sup.superseded_puid = dw.puid
where 
	dw.status = 'Superseded'
order by 
	type, chk.tc_id
;

/************** Alt ID Checks ****************/
 --INFO - Superseded ERP Context
select distinct
    pidcxt_name
    ,count(*)cnt
from &table_name chk
join altid_all_site aid on 
    upper(aid.pitem_id) = upper(sup_id)
group by 
   pidcxt_name 
order by 
   1
;

--INFO - Survivor ERP Context
select distinct 
    pidcxt_name
    ,count(*)cnt
from (select distinct sur_id from &table_name) chk
join altid_all_site aid on 
    upper(aid.pitem_id) = upper(sur_id)
group by 
   pidcxt_name 
order by 
   1
;

--ISSUE - Superseded and Survivor ERPs Dont Match
--will still show non-error items just to double check accuracy till confident
with item_context_match as (
   select 
       distinct
       chk.sup_id 
       ,alt_sup.pidcxt_name as sup_cxt
       ,chk.sur_id 
       ,alt_sur.pidcxt_name as sur_cxt
       ,alt_sur.cxt_list as sur_cxt_list
       ,case when alt_sup.pidcxt_name = alt_sur.pidcxt_name then 
           1 else null end as ismatch
   from 
       &table_name chk
   join altid_all_site alt_sup on 
       upper(alt_sup.pitem_id) = upper(chk.sup_id) 
   left join (
       select 
           pitem_id
           ,pidcxt_name 
           ,listagg(pidcxt_name,',') 
               within group(order by null)
               over(partition by pitem_id) as cxt_list 
       from 
           altid_all_site 
           ) alt_sur on 
       upper(alt_sur.pitem_id) = upper(chk.sur_id) 
   )
select 
   distinct 
   case when max(ismatch) over(partition by sup_id, sup_cxt, sur_id) is null then 
       1 end as is_nomatch
   ,sup_id 
   ,sup_cxt 
   ,sur_id 
   ,sur_cxt_list
from 
   item_context_match icm
order by 
   2,3
;

/************** Integration Point (IP) Checks ****************/
--ISSUE - Superseded and Survivor IPs Dont Match
--will still show non-error items just to double check accuracy till confident 
with item_ip as (
   select /*+driving_site(dw)*/ 
       upper(tc_id) as tc_id
       ,replace(ip, '-', '_') as ip_list
   from 
       cdmrpt.item_all_site@cdmdw dw )
, superseded_ip_expanded as (
   select 
       chk.rowid as row_id
       ,chk.sup_id 
       ,trim(regexp_substr(i.ip_list, '[^\W]+', 1, level)) as ip
   from 
       &table_name chk
   join item_ip i on i.tc_id = chk.sup_id 
   connect by 
       level <= regexp_count(i.ip_list, '\W') + 1 )
, survivor_ip_expanded as (
   select
       chk.rowid as row_id
       ,chk.sur_id 
       ,trim(regexp_substr(i.ip_list, '[^\W]+', 1, level)) as ip
       ,i.ip_list
   from 
       &table_name chk
   join item_ip i on i.tc_id = chk.sur_id 
   connect by 
       level <= regexp_count(i.ip_list, '\W') + 1 )
, item_ip_match as (
   select 
       distinct
       sup.sup_id
       ,sup.ip as sup_ip
       ,sur.sur_id
       ,sur.ip_list as sur_ip_list
       ,case when sup.ip = sur.ip then 
           1 else null end as ismatch
   from 
       superseded_ip_expanded sup 
   join survivor_ip_expanded sur on 
       sur.row_id = sup.row_id 
   where 
       sup.ip is not null )
select 
   distinct
   case when max(ismatch) over(partition by sup_id, sup_ip, sur_id) is null then 
       1 end as is_nomatch
   ,sup_id 
   ,sup_ip 
   ,sur_id
   ,sur_ip_list
from 
   item_ip_match
order by 
   2,3
;

/************** Item Relation Checks ****************/
--INFO - Given SupPart-RDD Relation Not Match
select /*+driving_site(item)*/
    chk.sup_id, chk.rdd_id as given_rdd
    ,rel.rdd_id as actual_rdd
    ,rev.pitem_revision_id as on_max_rev_released
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join z_max_rev_released@&linked_server rev on
    rev.ritems_tagu = item.puid
left join (
        select /*+driving_site(iman)*/
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

--INFO - Superseded Has RDD
select /*+driving_site(item)*/
    count(*) as count
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
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
;

--ISSUE - RDD Grp Different from Sup Part Grp
select /*+driving_site(item)*/
    grp.pname as grp
    ,chk.sup_id
    ,rev.pitem_revision_id as max_rev_released
    ,rel.rdd_id
    ,rel.rdd_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
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

--ISSUE - Related Part of Given Sup Doc has Different Grp from Doc Grp
select /*+driving_site(item)*/
    grp.pname as grp
    ,item.pitem_id as sup_doc_id
    ,rev.pitem_revision_id as max_rev_released
    ,rel.rel_part_id
    ,rel.rel_part_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
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
        select /*+driving_site(iman)*/ distinct
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

/************** UOM Checks ****************/
--ISSUE - Superseded and Survivor UOM Not Same
--need to optimize the linked queries
select
	sup_puid,
	supersede_legacy,
	sup_uom,
	sup_rsuom,
	sur_puid,
	survivor_legacy,
	sur_uom,
	sur_rsuom
from
	(
		select *
		from &table_name
	) chk
join(
		select /*+driving_site(items)*/
            distinct 
			items.puid as sur_puid,
			sur_id as survivor_legacy,
			uom.psymbol as sur_uom,
			rsuom.prsone_uom as sur_rsuom
		from
			(
				select *
				from &table_name
			) chk
		join infodba.pitem@&linked_server items on
			upper( items.pitem_id ) = upper(chk.sur_id)
		join infodba.pworkspaceobject@&linked_server wo on
			wo.puid = items.puid
		left join infodba.punitofmeasure@&linked_server uom on
			uom.puid = items.ruom_tagu
		join infodba.ppom_application_object@&linked_server ao on
			ao.puid = items.puid
		join infodba.ppom_group@&linked_server grp on
			grp.puid = ao.rowning_groupu
		join infodba.ppom_object@&linked_server obj on
			obj.puid = items.puid
			and obj.rowning_siteu is null
		left join(
				select /*+driving_site(item)*/
					iman.rprimary_objectu,
					pm.prsone_uom
				from
					infodba.pitem@&linked_server item
				join infodba.pimanrelation@&linked_server iman on
					item.puid = iman.rprimary_objectu
				join infodba.pimantype@&linked_server reltype on
					reltype.puid = iman.rrelation_typeu
					and reltype.ptype_name = 'IMAN_master_form'
				join infodba.pform@&linked_server frm on
					frm.puid = iman.rsecondary_objectu
				join(
						(
							select /*+driving_site(pm)*/
								puid,
								prsone_uom
							from
								infodba.pnoipartmaster@&linked_server pm
						)
				union(
						select /*+driving_site(pm)*/
							puid,
							prsone_uom
						from
							infodba.pnoinonengineeringmaster@&linked_server pm
						)
					) pm on
					pm.puid = frm.rdata_fileu
					and pm.prsone_uom is not null
			) rsuom on
			rsuom.rprimary_objectu = items.puid
	) survivor on
	survivor.survivor_legacy = chk.sur_id
join(
		select /*+driving_site(items)*/
            distinct 
			items.puid as sup_puid,
			sup_id as supersede_legacy,
			uom.psymbol as sup_uom,
			rsuom.prsone_uom as sup_rsuom
		from
			(
				select *
				from &table_name
			) chk
		join infodba.pitem@&linked_server items on
			upper( items.pitem_id ) = upper(chk.sup_id)
		join infodba.pworkspaceobject@&linked_server wo on
			wo.puid = items.puid
		left join infodba.punitofmeasure@&linked_server uom on
			uom.puid = items.ruom_tagu
		join infodba.ppom_application_object@&linked_server ao on
			ao.puid = items.puid
		join infodba.ppom_group@&linked_server grp on
			grp.puid = ao.rowning_groupu
		join infodba.ppom_object@&linked_server obj on
			obj.puid = items.puid
			and obj.rowning_siteu is null
		left join(
				select /*+driving_site(item)*/
					iman.rprimary_objectu,
					pm.prsone_uom
				from
					infodba.pitem@&linked_server item
				join infodba.pimanrelation@&linked_server iman on
					item.puid = iman.rprimary_objectu
				join infodba.pimantype@&linked_server reltype on
					reltype.puid = iman.rrelation_typeu
					and reltype.ptype_name = 'IMAN_master_form'
				join infodba.pform@&linked_server frm on
					frm.puid = iman.rsecondary_objectu
				join(
						(
							select /*+driving_site(pm)*/
								puid,
								prsone_uom
							from
								infodba.pnoipartmaster@&linked_server pm
						)
				union(
						select /*+driving_site(pm)*/
							puid,
							prsone_uom
						from
							infodba.pnoinonengineeringmaster@&linked_server pm
					)
					) pm on
					pm.puid = frm.rdata_fileu
					and pm.prsone_uom is not null
			) rsuom on
			rsuom.rprimary_objectu = items.puid
	) superseded on
	superseded.supersede_legacy = chk.sup_id
where
	nvl( sup_uom, 'none' ) <> nvl( sur_uom, 'none' )
	or nvl( sup_rsuom, 'none' ) <> nvl( sur_rsuom, 'none' )
;

/************** Backup File ****************/
--Backup
select /*+driving_site(item)*/
    grp.pname as grp
    ,chk.sup_id
    ,rev.pitem_revision_id as max_rev_working
    ,wbj.pobject_name
    ,wbj.pobject_desc
    ,sta.pname as status
    ,alt.altid
    ,alt.context
    ,rel.rdd_id
    ,rel.rdd_grp
from &table_name chk
join infodba.pitem@&linked_server item on
    upper(item.pitem_id) = upper(chk.sup_id)
join infodba.ppom_object@&linked_server obj on
    obj.puid = item.puid 
    and obj.rowning_siteu is null
join infodba.ppom_application_object@&linked_server abj on
    abj.puid = item.puid
join infodba.pworkspaceobject@&linked_server wbj on
	wbj.puid = item.puid
join infodba.ppom_group@&linked_server grp on
    grp.puid = abj.rowning_groupu
join z_max_rev_working@&linked_server rev on
    rev.ritems_tagu = item.puid
left join (
	select
		altid.raltid_ofu
		,altid.pidfr_id as altid 
		,cntx.pidcxt_name as context 
	from
		infodba.pidentifier@&linked_server altid
	join infodba.pidcontext@&linked_server cntx on
		cntx.puid = altid.ridcontextu
	) alt on alt.raltid_ofu = item.puid
left join (
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
left join infodba.prelease_status_list@&linked_server rsl on
    rsl.puid = item.puid
left join infodba.preleasestatus@&linked_server sta on
    sta.puid = rsl.pvalu_0
;
