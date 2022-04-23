/*
 * Document Relation Load Validations - Report.sql
 * Substitution Variables: table_name, linked_server.
 * To set all varibles run the below `define` commands:

 		set define on
 		define table_name = TABLE_NAME
 		define linked_server = LINKED_SERVER

 * Additionally, if you want to unset a variable run the `undefine`
 * command followed by the variable you want to unset.
 */

/************** Data Checks ****************/

--INFO - Count Total Rows
select count(*)cnt 
from &table_name
;

--INFO - Count Parts and Docs
select t.*, sum(parts+docs) over() as total_items from(
select 
    count(distinct item_id) as parts
    ,count(distinct doc_id) as docs
from &table_name )t
;

--INFO - Item Staged Twice
select * from (
    select distinct chk.*, count(*) over (partition by upper(item_id)
                                                      ,upper(revision)
                                                      ,upper(doc_id)
                                                      ,upper(relationship_type))Cnt 
    from &table_name chk
    ) 
where cnt >1
;

/************** Team Center Checks ****************/ 
--ISSUE - Item Not Exist in TC
select 
  chk.tc_id, chk.type
from ( 
        (select distinct upper(item_id) tc_id,
          'PART' as type
         from &table_name )
      union 
        (select distinct upper(doc_id),
          'DOCUMENTS' as type 
         from &table_name )
     )chk 
where 
    not exists(
        select /*+driving_site(item)*/ 1 
        from infodba.pitem@&linked_server item
        join infodba.ppom_object@&linked_server obj on
        	obj.puid = item.puid and 
        	obj.rowning_siteu is null
        where upper(item.pitem_id) = upper(chk.tc_id)
        )
;

/************** RDD/RD  Checks ****************/ 
--INFO - Given Relations Count
select 
	relationship_type, count(1)
from &table_name
group by 
	relationship_type 
;

--ISSUE - RDD Added Multiple Times
select * from(
select chk.*, count(distinct doc_id) over (
    partition by item_id, revision, relationship_type )count
from &table_name chk
where relationship_type = 'RelatedDefiningDocument' )
where count > 1
order by 1,3
;


--INFO - RD Added Multiple Times
select * from(
select chk.*, count(distinct doc_id) over (
    partition by item_id, revision, relationship_type, doc_id )count
from &table_name chk
where relationship_type = 'RelatedDocuments' )
where count > 1
order by 1,3
;


--INFO - Parts with Existing RDD
select /*+DRIVING_SITE(item)+*/
    chk.item_id
    ,chk.revision 
    ,case when chk.relationship_type = 'RelatedDefiningDocument'
        then chk.doc_id else null end as given_rdd
    ,rel.rdd_id as current_rdd
    ,case when rel.rdd_id = chk.doc_id then 
    	'Y' else null end as is_match
from 
        &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
        and rev.pitem_revision_id = chk.revision
    join (
        select /*+driving_site(iman)*/
            iman.rprimary_objectu
            ,item.pitem_id as rdd_id
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDefiningDocument'
            join infodba.pitem@&linked_server item on item.puid = iman.rsecondary_objectu
        ) rel on rel.rprimary_objectu = rev.puid
;

--INFO - Parts with Existing RD
select /*+DRIVING_SITE(item)+*/
    chk.item_id
    ,chk.revision 
    ,case when chk.relationship_type = 'RelatedDocuments'
        then chk.doc_id else null end as given_rd
    ,rel.rd_id as current_rd
from 
        &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
        and rev.pitem_revision_id = chk.revision
    join (
        select /*+driving_site(iman)*/
            iman.rprimary_objectu
            ,item.pitem_id as rd_id
        from 
            infodba.pimanrelation@&linked_server iman
            join infodba.pimantype@&linked_server rel on rel.puid = iman.rrelation_typeu
                and rel.ptype_name = 'RelatedDocuments'
            join infodba.pitem@&linked_server item on item.puid = iman.rsecondary_objectu
        ) rel on rel.rprimary_objectu = rev.puid
where
    rel.rd_id <> chk.doc_id
;

/************** Revision Checks ****************/ 
--ISSUE - Given Part REV does not Exist
select /*+DRIVING_SITE(item)+*/
    chk.*
from 
        &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    left join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
    	and upper(rev.pitem_revision_id) = upper(chk.revision)
where 
    rev.puid is null
;

--INFO - Part Latest Rev and Doc Latest Rev Mismatch
select /*+DRIVING_SITE(item)+*/
	distinct
    chk.*
    ,rev.pitem_revision_id as doc_rev_latest
    ,listagg(revall.pitem_revision_id,', ') within group (
        order by raabj.pcreation_date ) over (
            partition by revall.ritems_tagu, chk.revision ) as doc_rev_list
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.doc_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join infodba.pitemrevision@&linked_server revall on revall.ritems_tagu = item.puid
    join infodba.ppom_application_object@&linked_server raabj on raabj.puid = revall.puid
    join (
    	select * from (
	    	select /*+driving_site(rev)*/
		    	ritems_tagu
		    	,pitem_revision_id
		    	,row_number() over( partition 
		    		by ritems_tagu order by pcreation_date desc) as rank
	    	from 
	    		infodba.pitemrevision@&linked_server rev
	    		join infodba.ppom_application_object@&linked_server abj on
	    			abj.puid = rev.puid )
    	where 
    		rank = 1
    	) rev on rev.ritems_tagu = item.puid 
--    			 and rev.pitem_revision_id = chk.revision
where 
--    rev.pitem_revision_id is null
	rev.pitem_revision_id <> chk.revision
order by 1,2,3
;

--INFO - Given Part REV is Not Current Released REV
select /*+DRIVING_SITE(item)+*/
    chk.*
    ,rev.pitem_revision_id as current_released_rev
from 
        &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join z_max_rev_released@&linked_server rev on rev.ritems_tagu = item.puid
where 
    chk.revision <> rev.pitem_revision_id 
;

--INFO - Given Part REV is Not Current Working REV
select /*+DRIVING_SITE(item)+*/
    chk.*
    ,rev.pitem_revision_id as current_working_rev
from 
        &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    join z_max_rev_working@&linked_server rev on rev.ritems_tagu = item.puid
where 
    chk.revision <> rev.pitem_revision_id 
;

/************** Status Checks ****************/ 

--INFO - Status - Part
select /*+DRIVING_SITE(item)+*/
    count(*) as parts
    ,nvl(sta.pname,'NULL') status
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    left join (
        select /*+driving_site(rsl)*/
            rsl.puid
            ,sta.pname
        from 
            infodba.prelease_status_list@&linked_server rsl
            join infodba.preleasestatus@&linked_server sta on sta.puid = rsl.pvalu_0
        ) sta on sta.puid = item.puid
group by sta.pname
order by 1 desc
;

--INFO - Status - Doc
select /*+DRIVING_SITE(item)+*/
    count(*) as docs
    ,nvl(sta.pname,'NULL') status
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.doc_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    left join (
        select /*+driving_site(rsl)*/
            rsl.puid
            ,sta.pname
        from 
            infodba.prelease_status_list@&linked_server rsl
            join infodba.preleasestatus@&linked_server sta on sta.puid = rsl.pvalu_0
        ) sta on sta.puid = item.puid
group by sta.pname
order by 1 desc
;

--ISSUE - Status is Superseded - Part
select /*+DRIVING_SITE(item)+*/
    sta.pname as item_status
    ,chk.*
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    left join (
        select /*+driving_site(rsl)*/
            rsl.puid
            ,sta.pname
        from 
            infodba.prelease_status_list@&linked_server rsl
            join infodba.preleasestatus@&linked_server sta on sta.puid = rsl.pvalu_0
        ) sta on sta.puid = item.puid
where nvl(sta.pname,'None') = 'Superseded'
;

--ISSUE - Status Missing - Part
select /*+DRIVING_SITE(item)+*/
    sta.pname as item_status
    ,chk.*
from
    &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.ppom_object@&linked_server obj on obj.puid = item.puid
        and obj.rowning_siteu is null
    left join (
        select /*+driving_site(rsl)*/
            rsl.puid
            ,sta.pname
        from 
            infodba.prelease_status_list@&linked_server rsl
            join infodba.preleasestatus@&linked_server sta on sta.puid = rsl.pvalu_0
        ) sta on sta.puid = item.puid
where sta.puid is null
;

/************** Lifecycle Checks ****************/ 

--INFO - Lifecycle - Part
 select /*+DRIVING_SITE(item)+*/
    count(*) as parts
    ,nvl(rs.pname,'NULL') as lifecycle
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.item_id) 
    left join infodba.prelease_Status_list@&linked_server rsl on
        rsl.puid = item.puid
    left join infodba.preleasestatus@&linked_server rs on
        rs.puid = rsl.pvalu_0
group by rs.pname
order by 1 desc
;

--INFO - Lifecycle - Doc
 select /*+DRIVING_SITE(item)+*/
    count(*) as docs
    ,nvl(rs.pname,'NULL') as lifecycle
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.doc_id)
    left join infodba.prelease_Status_list@&linked_server rsl on
        rsl.puid = item.puid
    left join infodba.preleasestatus@&linked_server rs on
        rs.puid = rsl.pvalu_0
group by rs.pname
order by 1 desc
;

--ISSUE - Lifecycle is Superseded - Part
 select /*+DRIVING_SITE(item)+*/
    rs.pname as item_lifecycle
    ,chk.*
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.item_id) 
    left join infodba.prelease_Status_list@&linked_server rsl on
        rsl.puid = item.puid
    left join infodba.preleasestatus@&linked_server rs on
        rs.puid = rsl.pvalu_0
where nvl(rs.pname,'None') = 'Superseded'
;

--ISSUE - Lifecycle Missing - Part
 select /*+DRIVING_SITE(item)+*/
    rs.pname as item_lifecycle
    ,chk.*
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.item_id) 
    left join infodba.prelease_Status_list@&linked_server rsl on
        rsl.puid = item.puid
    left join infodba.preleasestatus@&linked_server rs on
        rs.puid = rsl.pvalu_0
where rs.pname is null
;

/************** Owning Group Checks ****************/ 

--INFO - Owning Group - Part
 select /*+DRIVING_SITE(item)+*/
    count(*) as parts
    ,nvl(grp.pname,'NULL') as owninggroup
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.item_id) 
    join infodba.ppom_application_object@&linked_server abj on
        abj.puid = item.puid
    join infodba.ppom_group@&linked_server grp on
        grp.puid = abj.rowning_groupu 
group by grp.pname
order by 1 desc
;

--INFO - Owning Group - Doc
 select /*+DRIVING_SITE(item)+*/
    count(*) as docs
    ,nvl(grp.pname,'NULL') as owninggroup
from
         &table_name chk
    join infodba.pitem@&linked_server item on
        upper(item.pitem_id) = upper(chk.doc_id) 
    join infodba.ppom_application_object@&linked_server abj on
        abj.puid = item.puid
    join infodba.ppom_group@&linked_server grp on
        grp.puid = abj.rowning_groupu 
group by grp.pname
order by 1 desc
;

/************** Released Item Checks ****************/ 

--INFO - Released - Part
 select /*+DRIVING_SITE(item)+*/
    count(*) as part_revisions
    ,nvl2(wbj.pdate_released ,'Yes','No') as released
from
         &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
        and rev.pitem_revision_id = chk.revision
    join infodba.pworkspaceobject@&linked_server wbj on wbj.puid = rev.puid
group by nvl2(wbj.pdate_released ,'Yes','No')
order by 1 desc
;

--INFO - Released - Doc
 select /*+DRIVING_SITE(item)+*/
    count(*) as doc_revisions
    ,nvl2(wbj.pdate_released ,'Yes','No') as released
from
         &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.doc_id)
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
    join infodba.pworkspaceobject@&linked_server wbj on wbj.puid = rev.puid
group by nvl2(wbj.pdate_released ,'Yes','No')
order by 1 desc
;

--ISSUE - Not Released - Parts
select /*+DRIVING_SITE(item)+*/
    chk.item_id
    ,rev.pitem_revision_id
    ,nvl2(wbj.pdate_released ,'Yes','No') released
from
         &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.item_id)
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
        and rev.pitem_revision_id = chk.revision
    join infodba.pworkspaceobject@&linked_server wbj on wbj.puid = rev.puid
where wbj.pdate_released is null
;

--ISSUE - Not Released - Docs
select /*+DRIVING_SITE(item)+*/
    chk.doc_id
    ,rev.pitem_revision_id
    ,nvl2(wbj.pdate_released ,'Yes','No') released
from
         &table_name chk
    join infodba.pitem@&linked_server item on upper(item.pitem_id) = upper(chk.doc_id)
    join infodba.pitemrevision@&linked_server rev on rev.ritems_tagu = item.puid
    join infodba.pworkspaceobject@&linked_server wbj on wbj.puid = rev.puid
where wbj.pdate_released is null
;
