/*
 * Name and Description Validations - Report.sql
 * Substitution Variables: table_name, linked_server.
 * To set all varibles run the below `define` commands:

 		set define on
 		define table_name = TABLE_NAME
        define linked_server = LINKED_SERVER

 * Additionally, if you want to unset a variable run the `undefine`
 * command followed by the variable you want to unset.
 */

/************** Dataset Checks ****************/ 
--INFO - Total Rows
select count(*)cnt
from &table_name
; 

--INFO - Total Items
select count(*)cnt 
from ( select distinct tc_id
from &table_name )
;

--INFO - Total Rows Distinct
select count(*)cnt 
from ( select distinct *
from &table_name )
;

--INFO - Duplicate Items
select * from (
    select t.*, count(tc_id) over (
        partition by tc_id) as cnt
    from &table_name t )
where cnt > 1
;

/************** Teamcenter Checks ****************/ 
--ISSUE - Item Not Exists
select /*+driving_site(dw)*/ 
    chk.*
from &table_name chk
left join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
where dw.puid is null
;

/************** Item Type Checks ****************/ 
--INFO - Item Types
select 
   dw.item_type
   ,count(*) as cnt
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = chk.tc_id
group by 
   dw.item_type
; 

/************** Item Name1 Checks ****************/ 
--ISSUE - Item Name1 is Null
select tc_id, name1
from &table_name
where name1 is null
;

--INFO - Item Name1 Length Greater than 64 chars
select tc_id, name1, length(name1) as length
from &table_name
where length(name1) > 64
order by length
;

--INFO - Item Name1 Length Greater than 30 (JDE)
select tc_id, name1, length(name1) as length
from &table_name
where length(name1) > 30
order by length
;

--INFO - Item Name1 Non-ASCII
select tc_id,name1 ,asciistr(name1)
from &table_name
where name1 <> asciistr(name1)
;
 
--ISSUE - Item Name1 has Control Chars
select tc_id, name1, regexp_replace(name1,'[[:cntrl:]]','CNTRL')
from &table_name
where regexp_like(name1,'[[:cntrl:]]')
;

/************** Item Name2 Checks ****************/ 
--INFO - Item Name2 is Null
select tc_id, name2
from &table_name
where name2 is null
;

--INFO - Item Name2 Length Greater than 30 chars
select  tc_id, name2, length(name2) as length
from &table_name
where length(name2) > 30
order by length
;

--INFO - Item Name2 Non-ASCII
select tc_id,name2 ,asciistr(name2)
from &table_name
where name2 <> asciistr(name2)
;
 
--ISSUE - Item Name2 has Control Chars
select tc_id, name2,  regexp_replace(name2,'[[:cntrl:]]','CNTRL')
from &table_name
where regexp_like(name2,'[[:cntrl:]]')
;

/************** Item Desc Checks ****************/ 
--INFO - Item Desc is Null
select  tc_id, description
from &table_name
where description is null
;

--INFO - Item Desc Greater than 240 chars 
select tc_id, description, length(description) as length
from &table_name
where length(description) > 240
order by length
;

--INFO - Item Desc has pipe
select tc_id, description
from &table_name
where regexp_like(description,'\|')
;

--ISSUE - Item Desc has Control Chars
select tc_id, description, regexp_replace(description,'[[:cntrl:]]','CNTRL')
from &table_name
where 
    regexp_like(description,'[[:cntrl:]]')
    and not regexp_like(description, chr(10)||'|'||chr(13)||chr(10))
;

--INFO - Item Desc has New Lines
select tc_id, description, regexp_replace(description, chr(10)||'|'||chr(13)||chr(10),'NEWLINE')
from &table_name
where regexp_like(description, chr(10)||'|'||chr(13)||chr(10))
;
 
/************** Group Checks ****************/
--INFO - Owning Group
select /*+driving_site(dw)*/
	distinct
    dw.local_site
    ,g.business_unit
    ,g.parent_name
    ,dw.pname grp
    ,g."ERPS"
    ,count(*) over (
    	partition by dw.local_site, dw.pname) as cnt
from &table_name chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.tc_id)
left join cdmrpt.dim_group_master@cdmdw g on
	upper(g.group_name) = upper(dw.pname)
order by cnt desc
;

/************** Backup ****************/
--Backup
select /*+driving_site(item)*/
    grp.pname as item_grp
    ,item.pitem_id
    ,wbj.pobject_name as item_name
    ,pm.pname2 as item_name2
    ,wbj.pobject_desc as item_desc
    ,rev.pitem_revision_id as rev_id
    ,wbj.pdate_released 
    ,wbj_rev.pobject_name as rev_name
    ,rm.pname2 as rev_name2
    ,wbj_rev.pobject_desc as rev_desc
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = chk.tc_id
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join infodba.ppom_application_object@&linked_server abj on abj.puid = item.puid
    join infodba.ppom_group@&linked_server grp on grp.puid = abj.rowning_groupu
    join infodba.pworkspaceobject@&linked_server wbj on wbj.puid = item.puid
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
    join infodba.pworkspaceobject@&linked_server wbj_rev on wbj_rev.puid = rev.puid
    left join (          
        select       
            iman.rprimary_objectu
            ,pm.pname2
        from         
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'IMAN_master_form'
            join infodba.pform@&linked_server frm on frm.puid = iman.rsecondary_objectu
            join (
                select puid, pname2 from infodba.pnoipartmaster@&linked_server union
                select puid, pname2 from infodba.pnoinonengineeringmaster@&linked_server
            ) pm on pm.puid = frm.rdata_fileu    
        ) pm on pm.rprimary_objectu = item.puid
    left join (          
        select       
            iman.rprimary_objectu
            ,pm.pname2
        from         
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'IMAN_master_form'
            join infodba.pform@&linked_server frm on frm.puid = iman.rsecondary_objectu
            join (
                select puid, pname2 from infodba.pitemversionmaster@&linked_server union
                select puid, pname2 from infodba.pnoipartrevisionmaster@&linked_server
            ) pm on pm.puid = frm.rdata_fileu    
        ) rm on rm.rprimary_objectu = rev.puid
order by
    grp.pname, item.pitem_id, rev.pitem_revision_id 
;
