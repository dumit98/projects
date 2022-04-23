/*
 * BOM Load Validations - Report.sql
 * Substitution Variables: table_name, linked_server.
 * To set all varibles run the below `define` commands:

 		set define on
 		define table_name = TABLE_NAME
 		define linked_server = LINKED_SERVER

 * Additionally, if you want to unset a variable run the `undefine`
 * command followed by the variable you want to unset.
 * 
 * NOTES
 * Depending on the source data, a parent_tc_rev filed might exist
 */

/************** Data Checks ****************/ 
--INFO - Count Total Rows 
select count(*)cnt  
from &table_name
;
  
--INFO - Item Staged Twice 
select * from ( 
    select chk.*, count(*) over (partition by parent_tc_id 
                                          ,child_tc_id 
                                          ,seq_no 
                                          ,quantity)cnt  
    from &table_name chk
    )  
where cnt >1 
;  
  
/************** BOM Item Checks ****************/ 
--INFO - Count Assemblies
select count(distinct upper(parent_tc_id))cnt
from &table_name
;

--INFO - Count Components
select count(distinct upper(child_tc_id))cnt
from &table_name
; 

--INFO - Count ASM and COMP
select
 	count(*)cnt
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name )
     )chk
;
  
/************** Team Center Checks ****************/  
--INFO - Count Items in Data Warehouse
select /*+DRIVING_SITE(dw)+*/
	count(*)cnt
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
left join cdmrpt.item_all_site@cdmdw dw on upper(dw.tc_id) = upper(chk.tc_id) 
where dw.tc_id is not null 
; 
  
--ISSUE - Item Not Exist in Data Warehouse 
select /*+DRIVING_SITE(dw)+*/
	chk.*
from ( 
        (select distinct upper(parent_tc_id) tc_id
         from &table_name )
      union 
        (select distinct upper(child_tc_id)
         from &table_name ))chk
left join cdmrpt.item_all_site@cdmdw dw on upper(dw.tc_id) = upper(chk.tc_id) 
where dw.tc_id is null 
; 
  
--ISSUE - Item Not Exist in TC
select /*+DRIVING_SITE(i)+*/
	chk.*
from ( 
        (select distinct upper(parent_tc_id) tc_id
         from &table_name )
      union 
        (select distinct upper(child_tc_id)
         from &table_name ))chk
left join infodba.pitem@&linked_server i on upper(i.pitem_id) = upper(chk.tc_id)
left join infodba.ppom_object@&linked_server obj on obj.puid = i.puid
	and obj.rowning_siteu is null
where obj.puid is null
; 
  
/************** REV Checks ****************/ 
--ISSUE - Item Rev Not Exist in TC
select /*+DRIVING_SITE(i)+*/
	chk.*
from ( 
        (select distinct upper(parent_tc_id) tc_id, parent_revision rev
         from &table_name )
      ) chk 
left join cdmrpt.item_all_site_rev@cdmdw dw on upper(dw.tc_id) = upper(chk.tc_id) 
	and dw.rev = chk.rev
where dw.rev is null 
;
  
/************** TC ID Checks ****************/   
--ISSUE - TC ID is NULL
select *
from &table_name
where parent_tc_id is null 
or child_tc_id is null
;

--ISSUE - TC ID Length > 28
select tc_id, length(tc_id) 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where length(tc_id) >28 
; 
  
--ISSUE - TC ID Length > 30 DHT 
select tc_id, length(tc_id) 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where length(tc_id) >30 
; 
  
--INFO - TC ID with Spaces
select tc_id 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where regexp_like(Tc_Id,  '\s') 
; 
  
--INFO - TC ID with Trailing Space 
select tc_id  
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where regexp_like(Tc_Id, '\s+:.*$|\s+$|:\s+.*$') 
; 
  
--INFO - TC ID  with Special Chars 
select tc_id 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where regexp_like(tc_id, '[*&~'';,%+#"\/$@`?)(^!]')
; 

--INFO - TC ID Leading Odd Character
select tc_id 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
where regexp_like(tc_id,'^\W') 
; 
  
--INFO - TC ID  with Control Chars 
select tc_id, 
       regexp_replace(tc_id,'[[:cntrl:]]','CNTRL')tc_id_cntrl 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id) tc_id
         from &table_name ))chk
where regexp_like(tc_id,'[[:cntrl:]]') 
; 
  
/************** Alt ID Checks ****************/   
--ISSUE - Alt ID not exist
select tc_id, altid 
from ( 
        (select distinct upper(parent_tc_id)tc_id, 
                         upper(parent_gid_id)altid 
         from &table_name )
      union 
        (select distinct upper(child_tc_id), 
                         upper(child_gid_id) 
         from &table_name ))chk
left join cdmuser.altid_all_site altid on  
    upper(altid.pitem_id) = upper(chk.tc_id) 
    and altid.pidfr_id = chk.altid 
    and altid.pidcxt_name in ('JDE', 'RSOne')
where altid.pitem_id is null
and chk.altid is not null
; 
  
/************** Item SEQ Checks ****************/  
--ISSUE - SEQ No is Missing
select * 
from &table_name
where seq_no is null 
; 

--INFO - SEQ No is a Decimal
select * 
from &table_name
where regexp_like(seq_no, '\.')
; 
  
--ISSUE - Components with Same SEQ on Same ASM
select distinct * 
from 
  (select upper(parent_tc_id), 
          seq_no, 
          upper(child_tc_id), 
          quantity,
          count(distinct upper(child_tc_id)) over(
          	partition by upper(parent_tc_id),seq_no)cnt 
   from 
     (select * 
      from &table_name ))
where cnt>1 
order by 1,2,to_number(seq_no)
; 
  
/************** Item QTY Checks ****************/  
--INFO - Quantity is Missing 
select * 
from &table_name
where quantity is null or quantity = 0 
; 
  
--INFO - Questionable QTY 
select * 
from &table_name
where quantity < 0 or quantity > 1000 
order by to_number(quantity) desc 
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
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name )) chk
join cdmrpt.item_all_site@cdmdw dw on
    upper(dw.tc_id) = upper(chk.tc_id)
left join cdmrpt.dim_group_master@cdmdw g on
	upper(g.group_name) = upper(dw.pname)
order by cnt desc
;

--ISSUE - Assy Not in Major Group
select  /*+DRIVING_SITE(dw)+*/
  dw.tc_id, chk.type, dw.pname owninggroup, local_site
from ( 
        (select distinct upper(parent_tc_id) tc_id,
          'Assembly' as type
         from &table_name )
      union 
        (select distinct upper(child_tc_id),
          'Component' as type 
         from &table_name )
     )chk 
  join cdmrpt.item_all_site@cdmdw dw on 
    upper(dw.tc_id) = upper(chk.tc_id) 
where 
	not exists(
	  select owninggroup from(
	    select 
	      pname owninggroup, row_number() over(order by count(*)desc)max_count
	    from ( 
	            (select distinct upper(parent_tc_id) tc_id 
	             from &table_name )
	          union 
	            (select distinct upper(child_tc_id)  
	             from &table_name )
	         )chk 
	    join cdmrpt.item_all_site@cdmdw dw_sub on 
	      upper(dw_sub.tc_id) = upper(chk.tc_id) 
	    group by pname )vs
	  where 
	    vs.max_count = 1 and 
	    vs.owninggroup = dw.pname )
	and type = 'Assembly'
order by owninggroup
;

--INFO - Comp Not in Major Group
select  /*+DRIVING_SITE(dw)+*/
  dw.tc_id, chk.type, dw.pname owninggroup, local_site
from ( 
        (select distinct upper(parent_tc_id) tc_id,
          'Assembly' as type
         from &table_name )
      union 
        (select distinct upper(child_tc_id),
          'Component' as type 
         from &table_name )
     )chk 
  join cdmrpt.item_all_site@cdmdw dw on 
    upper(dw.tc_id) = upper(chk.tc_id) 
where 
	not exists(
	  select owninggroup from(
	    select 
	      pname owninggroup, row_number() over(order by count(*)desc)max_count
	    from ( 
	            (select distinct upper(parent_tc_id) tc_id 
	             from &table_name )
	          union 
	            (select distinct upper(child_tc_id)  
	             from &table_name )
	         )chk 
	    join cdmrpt.item_all_site@cdmdw dw_sub on 
	      upper(dw_sub.tc_id) = upper(chk.tc_id) 
	    group by pname )vs
	  where 
	    vs.max_count = 1 and 
	    vs.owninggroup = dw.pname )
	and type = 'Component'
order by owninggroup
;

/************** Site Checks ****************/ 
--INFO - Owining Site 
select  /*+DRIVING_SITE(dw)+*/
	local_site, count(*)count 
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
join cdmrpt.item_all_site@cdmdw dw on upper(dw.tc_id) = upper(chk.tc_id) 
group by local_site 
; 

--ISSUE - Item in Different Owning Site
select  /*+DRIVING_SITE(dw)+*/
  dw.tc_id, chk.type, dw.local_site
from ( 
        (select distinct upper(parent_tc_id) tc_id,
          'Assembly' as type
         from &table_name )
      union 
        (select distinct upper(child_tc_id),
          'Component' as type 
         from &table_name )
     )chk 
  join cdmrpt.item_all_site@cdmdw dw on 
    upper(dw.tc_id) = upper(chk.tc_id) 
where 
not exists(
  select local_site from(
    select 
      local_site, row_number() over(order by count(*)desc)max_count
    from ( 
            (select distinct upper(parent_tc_id) tc_id 
             from &table_name )
          union 
            (select distinct upper(child_tc_id)  
             from &table_name )
         )chk 
    join cdmrpt.item_all_site@cdmdw dw_sub on 
      upper(dw_sub.tc_id) = upper(chk.tc_id) 
    group by local_site )vs
  where 
    vs.max_count = 1 and 
    vs.local_site = dw.local_site )
;

/************** Status Checks ****************/ 
--INFO - Item Status 
select /*+DRIVING_SITE(dw)+*/
	sta.pname as status, count(*)cnt
from ( 
        (select distinct upper(parent_tc_id) tc_id 
         from &table_name )
      union 
        (select distinct upper(child_tc_id)  
         from &table_name ))chk
join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.tc_id)
left join infodba.prelease_status_list@&linked_server rsl on rsl.puid = item.puid
left join infodba.preleasestatus@&linked_server sta on sta.puid = rsl.pvalu_0
group by sta.pname
order by count(*)
; 
  
/************** Misc Checks ****************/ 
--ISSUE - COMP and ASM are the Same
select * 
from &table_name
where upper(parent_tc_id) = upper(child_tc_id)
;

--INFO - ASSY has BOM
select 
	distinct 
	chk.parent_tc_id
	,bom.hasbom
--	chk.*
from 
	&table_name chk
	join (
		select /*+DRIVING_SITE(ps)+*/
			distinct
			asm.pitem_id as asmid
			,nvl2(comp.pitem_id,'Y', null) as hasbom
		from 
				infodba.ppsoccurrence@&linked_server ps
			join infodba.pstructure_revisions@&linked_server sr on
				sr.pvalu_0 = ps.rparent_bvru 
			join infodba.pitemrevision@&linked_server rev on
				rev.puid = sr.puid 
			join infodba.pitem@&linked_server comp on
				comp.puid = ps.rchild_itemu 
			right join infodba.pitem@&linked_server asm on
				asm.puid = rev.ritems_tagu 
		) bom on upper(bom.asmid) = upper(chk.parent_tc_id)
where 
	bom.hasbom = 'Y'
;

/********************************************/
--Backup
select /*+DRIVING_SITE(asm)+*/
	distinct 
	asm.pitem_id as assy
	,rev.pitem_revision_id as rev 
	,comp.pitem_id as comp 
	,round(ps.pqty_value, 4) qty
	,ps.pseq_no
	,rdes.ref_designator
	,descom.refdefcomments
from cdmuser.&table_name@cdm chk
join infodba.pitem@&linked_server asm on 
	upper(asm.pitem_id) = upper(chk.parent_tc_id)
join infodba.pitemrevision@&linked_server rev on 
	rev.ritems_tagu = asm.puid and 
	upper(rev.pitem_revision_id) = upper(chk.parent_revision)
join infodba.pstructure_revisions@&linked_server sr on 
	sr.puid = rev.puid 
join infodba.ppsoccurrence@&linked_server ps on 
	ps.rparent_bvru = sr.pvalu_0 
join infodba.pitem@&linked_server comp on 
	comp.puid = ps.rchild_itemu
left join (
	select /*+DRIVING_SITE(psn)+*/
		PSN.PUID,
		NTEXT.PVAL_0 as ref_designator
	from
		infodba.ppsoccurrencenotes@&linked_server psn,
		infodba.pnote_types@&linked_server ntype,
		infodba.pnotetype@&linked_server notetype,
		infodba.pnote_texts@&linked_server NTEXT
	where
		psn.puid = ntype.puid
		and ntype.pvalu_0 = notetype.puid
		and ntext.puid = psn.puid
		and ntext.pseq = ntype.pseq
		and notetype.pname = 'Reference Designator'
) rdes on rdes.puid = ps.rnotes_refu
left join (
	select /*+DRIVING_SITE(psn)+*/
		psn.puid,
		ntext.pval_0 as refdefcomments
	from
		INFODBA.PPSOCCURRENCENOTES@&linked_server PSN,
		INFODBA.PNOTE_TYPES@&linked_server NTYPE,
		INFODBA.PNOTETYPE@&linked_server NOTETYPE,
		infodba.pnote_texts@&linked_server NTEXT
	where
		psn.puid = ntype.puid
		and ntype.pvalu_0 = notetype.puid
		and ntext.puid = psn.puid
		and ntext.pseq = ntype.pseq
		and notetype.pname = 'Nov4RefDefComments'
) descom on descom.puid = ps.rnotes_refu
;
