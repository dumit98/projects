/*
 * Document Load Validations - Report.sql
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

--INFO - Count Total Items
select count(distinct doc_id)
from &table_name
;

--INFO - Item Staged Twice
select * from (
    select distinct count(*) over (partition by upper(doc_id)
                                                      ,upper(revision)
                                                      ,upper(path_location))dup_count
                    ,chk.*
    from &table_name chk
    ) 
where dup_count >1
order by doc_id
;

/************** Team Center Checks ****************/ 
--ISSUE - Item Exist in DW
select /*+DRIVING_SITE(dw)+*/
    dw.* 
from (select distinct doc_id from &table_name) chk
join cdmrpt.item_all_site@cdmdw dw on upper(dw.tc_id) = upper(chk.doc_id)
;

--ISSUE - Item Exist in TC
select /*+DRIVING_SITE(item)+*/
    count(distinct doc_id) as count
from &table_name  chk
join infodba.pitem@&linked_server item on
	upper(item.pitem_id) = upper(chk.doc_id)
join infodba.ppom_object@&linked_server obj on
	obj.puid = item.puid and 
	obj.rowning_siteu is null
;

/************** Suffix Checks ****************/
--INFO - Item ID Suffix
select nvl( suffix, 'NULL' ) suffix, count(*)cnt
from( select chk.*, regexp_substr(doc_id, '\:.*' )  Suffix
    from &table_name chk )
group by suffix
;

--INFO - Duplicate Suffix
select distinct doc_id from &table_name
where doc_id like '%:%:%'
;

--INFO - Item with no Suffix
select distinct doc_id from &table_name
where (doc_id not like '%:%')
;

/************** REV Checks ****************/
--INFO - Docs with multiple REVs
Select doc_id, count(distinct revision)rev_count
from &table_name
group by doc_id
having count(distinct revision) >1
order by 2 desc
;

--ISSUE - Revisions with Same Creation Date
select 
doc_id, rev_creation_date, cnt_revs_same_date
    ,listagg(revision, ', ') within group (
        order by rev_creation_date, revision ) as revisions_samedate
from (
    select distinct 
doc_id, rev_creation_date 
        ,count(distinct revision) over (
            partition by doc_id, rev_creation_date ) as cnt_revs_same_date
        ,revision 
    from &table_name
) 
where cnt_revs_same_date > 1
group by doc_id, rev_creation_date, cnt_revs_same_date
order by doc_id
;

--ISSUE - REV is null
select doc_id, revision
from &table_name chk
where revision is null
;

--INFO - Revisions
select revision, count(*)cnt
from &table_name chk
group by revision
order by 1
;

--INFO - Odd Revision ID
select distinct doc_id, revision
from &table_name 
where 
	regexp_like(regexp_replace(revision, '(.)\.(.)', '\1\2'), '[^A-Z0-9]')
	and not regexp_like(revision, '^-{1,2}$')
;

/************** TC ID Checks ****************/  
--ISSUE - TC ID Length Grater Than 64 Chars
select doc_id, length(doc_id)
from &table_name
where length(doc_id) >64
;

--INFO - Spaces in TC ID
select doc_id
from &table_name
where regexp_like(doc_id,  '\s')
;

-- INFO - Leading Non-AlphaNumeric Char in TC
select doc_id
from &table_name
where not regexp_like(doc_id, '^[[:alnum:]]')
;

--INFO - TC ID with Trailing Space
select doc_id 
from &table_name
where regexp_like(doc_id, '\s+:.*$|\s+$|:\s+.*$')
;

--INFO - TC ID  with Invalid Characters
select doc_id
from &table_name
where regexp_like(doc_id,'[][~`!@#$%^&*=+}{|<>;?,]')
;

--INFO - TC ID with Questionable Characters
select doc_id
from &table_name
where regexp_like(doc_id,'[\\\/")(]')
;

/************** Item Name Checks ****************/ 
--ISSUE - Item Name is Null
select doc_id, name, description
from &table_name
where name is null
;

--INFO - Item Name Length Greater than 34 chars
select doc_id, name, length(name) as length
from &table_name
where length(name) > 64
order by 3 desc
;

--INFO - Item Name Length Greater than 30 chars (JDE)
select doc_id, name, length(name) as length
from &table_name
where length(name) > 30
order by 3 desc
;

--INFO - Item Name Non-ASCII
select doc_id,name ,asciistr(name)
from &table_name
where name <> asciistr(name)
;

--ISSUE - Item Name has Control Chars
select doc_id, name
    ,regexp_replace(name,'[[:cntrl:]]','"CTRL"')
from &table_name
where (regexp_like(name,'[[:cntrl:]]'))
;

/************** Item Desc Checks ****************/ 
--INFO - Item Desc is Null
select doc_id, description, name
from &table_name
where description is null
;

--INFO - Item Desc > 240  
select doc_id, description, length(description) length
from &table_name
where length(description) > 240
;

--INFO - Item Desc has pipe
select doc_id, description
from &table_name
where regexp_like(description,'\|')
;

--ISSUE - Item Desc has Control Chars
select doc_id, description 
    ,regexp_replace(description,'[[:cntrl:]]','"CTRL"')
from &table_name
where (regexp_like(description,'[[:cntrl:]]'))
;

/************ Category/Type Checks **************/
--ISSUE - Doc Category is Null
select doc_id, document_category, document_type, name
    ,description
from &table_name
where document_category is null
;

--ISSUE - Doc Type is Null
select doc_id, document_category, document_type, name
    ,description
from &table_name
where document_type is null
;

--ISSUE - Doc with Multiple Types
select * from(
    select distinct upper(doc_id)tc_id, document_type
        ,count(distinct document_type) over (partition by upper(doc_id))cnt
    from &table_name
    )
where cnt>1 
;

--ISSUE - Invalid Doc Type
 select /*+DRIVING_SITE(lov)+*/
 	distinct 
    chk.document_category
    ,chk.document_type
    ,count(distinct doc_id) over(partition by document_category,
    	document_type)cnt
from
    &table_name chk
where
    not exists(
        select
            distinct regexp_substr( lov.plov_name, '[A-Z]{3}' ) cat,
            val.pval_0 doctype,
            d.df default_doctype,
            lov.plov_name
        from
            infodba.plistofvalues@&linked_server lov
        join infodba.plov_values_2@&linked_server val on
            lov.puid = val.puid
        left join(
                select
                    distinct substr( val.pval_0, 0, 3 ) cat,
                    substr( val.pval_0, 7 ) df
                from
                    infodba.plistofvalues@&linked_server lov
                join infodba.plov_values_2@&linked_server val on
                    lov.puid = val.puid
                where
                    lov.plov_name = 'ValidDocumentTypes_LOV'
            ) d on
            d.cat = regexp_substr( lov.plov_name, '[A-Z]{3}' )
        where
            regexp_like( lov.plov_name, '^(Nov4){0,1}[A-Z]{3}\_Subtype_LOV$' )
            and regexp_substr( lov.plov_name, '[A-Z]{3}' )= chk.document_category
            and val.pval_0 = chk.document_type
    )
order by 1,2
;

/************** Date Checks ****************/
--INFO - Release Date is Null
select count(*)count
from &table_name
where rev_release_date is null
;

--INFO - Creation Date is Null
select count(*)count
from &table_name
where rev_creation_date is null
;

--INFO - Release Dates
select 
	substr(extract(year from rev_release_date), 1, 3)||'0s' as decade
	,count(*) as count
from &table_name
group by substr(extract(year from rev_release_date), 1, 3)
order by 1
;

--INFO - Creation Dates
select 
	substr(extract(year from rev_creation_date), 1, 3)||'0s' as decade
	,count(*) as count
from &table_name
group by substr(extract(year from rev_creation_date), 1, 3)
order by 1
;

/************** Group Checks ****************/
--INFO - Owning Group
select /*+driving_site(dw)*/
	distinct
	g.primary_site
    ,g.business_unit
    ,g.parent_name
    ,chk.owninggroup grp
    ,g."ERPS"
    ,count(*) over (
    	partition by chk.owninggroup) as cnt
from &table_name chk
left join cdmrpt.dim_group_master@cdmdw g on
	upper(g.group_name) = upper(chk.owninggroup)
order by cnt desc
;

/************** Status Checks ****************/
--INFO - Item Status
select nvl(document_status,'NULL')document_status, count(*)count
from &table_name chk
group by document_status
;

--INFO - Revision Status
select nvl(revision_status,'NULL')revision_status, count(*)count
from &table_name chk
group by revision_status
;

/************** File Checks ****************/
--ISSUE - Multiple ItemRevs with Same Path Location
select path_location,doc_id, revision, cnt from(
    select doc_id, revision, path_location, 
    count(*) over(partition by upper(path_location), revision) cnt
    from &table_name
    )
where cnt > 1 and path_location is not null 
order by 1
;

--INFO - Duplicate Dataset Files
select * from (
select
doc_id
	,revision
	,upper(path_location) as path_location
	,upper(regexp_substr(path_location, '[^\\]+$')) as filename
	,count(upper(regexp_substr(path_location, '[^\\]+$'))) over(
		partition by 
			upper(doc_id)
			,upper(revision)
			,trim(upper(regexp_substr(path_location, '[^\\]+$')))
		) as cnt 
from 
	&table_name
) where cnt > 1
order by filename
;

--INFO - File Extensions
select extensions, count(*)cnt from (
    select regexp_replace(upper(path_location),'.+\.(.+)$','\1')extensions
    from &table_name
    where regexp_like(upper(path_location),'\.(.+)$') 
    )
group by extensions
;

--ISSUE - Paths Without Filenames
select distinct doc_id, revision, path_location
from &table_name
where not regexp_like(upper(path_location),'\.(.+)$')
;

--ISSUE - Item Without Path Location
select distinct doc_id, revision, path_location
from   &table_name
where path_location is null
;

--INFO - Invalid Remote Path
select distinct doc_id, revision, path_location
from &table_name
where not regexp_like(path_location,'^\\\\')
;

--INFO - Network Drives
select regexp_substr(upper(path_location), '^\\\\[^\\]+\\[^\\]+') as remote_drive
	,count(*) as count 
from &table_name
group by regexp_substr(upper(path_location), '^\\\\[^\\]+\\[^\\]+')
;

--INFO - Dataset File Status
select distinct doc_id, revision, rev_creation_date, path_location as file_path
from &table_name
where path_location is not null 
;

/************* Existing Items (Delta Items) *************/
--INFO - Existing - Revision Updates
select * from (
select /*+DRIVING_SITE(dw)+*/
	distinct
	chk.doc_id
	,listagg(rev.pitem_revision_id, ', ') within group(order by rev.pitem_revision_id) 
    over(partition by rev.ritems_tagu) as rev_current
	,chk.revision as rev_new
from &table_name  chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = upper(chk.doc_id)
join infodba.pitemrevision@&linked_server rev on
	rev.ritems_tagu = dw.puid
) where
	rev_current not like '%'||rev_new||'%'
;

--INFO - Existing - Parts With Multiple Revisions
select * from (
select /*+DRIVING_SITE(dw)+*/
	distinct
	chk.doc_id
	,rev.pitem_revision_id as rev_current
	,count(*) over(
		partition by chk.doc_id) cnt 
from &table_name  chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = upper(chk.doc_id)
join infodba.pitemrevision@&linked_server rev on
	rev.ritems_tagu = dw.puid
) where 
	cnt > 1
;

--INFO - Existing - Status Updates
select /*+DRIVING_SITE(dw)+*/
	distinct
	dw.tc_id ||'|'|| chk.document_status as inp,
	chk.doc_id
	,dw.status as status_current
	,chk.document_status as status_new
from &table_name  chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = upper(chk.doc_id)
left join infodba.prelease_status_list@&linked_server rsl on
	rsl.puid = dw.puid 
left join infodba.preleasestatus@&linked_server sta on
	sta.puid = rsl.pvalu_0
where 
	nvl(upper(trim(document_status)), 'none') <> nvl(upper(sta.pname), 'none')
;

--INFO - Existing - Item Name Updates
select /*+DRIVING_SITE(dw)+*/
	distinct 
	dw.tc_id||'|'||chk.name ||'|IGNORE' as inp,
	chk.doc_id
	,dw.pobject_name as name_current
	,length(dw.pobject_name) as length
	,chk.name as name_new
	,length(chk.name) as length
from &table_name  chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = upper(chk.doc_id)
join infodba.pworkspaceobject@&linked_server wbj on
	wbj.puid = dw.puid
where 
	upper(regexp_replace(name, '\W')) <> upper(regexp_replace(wbj.pobject_name, '\W'))
;

--INFO - Existing - Item Description Updates
select /*+DRIVING_SITE(dw)+*/
	distinct 
	dw.tc_id||'|IGNORE|'||chk.description as inp,
	chk.doc_id
	,dw.pobject_desc as description_current
	,chk.description as description_new
from &table_name  chk
join cdmrpt.item_all_site@cdmdw dw on 
	upper(dw.tc_id) = upper(chk.doc_id)
join infodba.pworkspaceobject@&linked_server wbj on
	wbj.puid = dw.puid
where 
	upper(regexp_replace(description, '\W')) <> upper(regexp_replace(wbj.pobject_desc, '\W'))
;

--INFO - Dataset file exists for given Item Revision
select 
	distinct
	pitem_id
	,pitem_revision_id
	,dswo.pobject_name as dataset_name_current
	,fl.poriginal_file_name as dataset_namedref_current
	,upper(regexp_substr(chk.path_location, '[^\\]+$')) file_given
	,upper(chk.path_location) file_path_location_given
from
		infodba.pitemrevision@&linked_server r2
	join infodba.pimanrelation@&linked_server iman on
		iman.rprimary_objectu = r2.puid
	join infodba.pimantype@&linked_server reltype on
		reltype.puid = iman.rrelation_typeu
		and reltype.ptype_name = 'IMAN_specification'
	join infodba.pdataset@&linked_server ds on
		ds.puid = iman.rsecondary_objectu
	join infodba.pdatasettype@&linked_server dst on
		dst.puid = ds.rdataset_typeu
	join infodba.pworkspaceobject@&linked_server dswo on
		dswo.puid = ds.puid
	join infodba.pref_list_0@&linked_server rl on
		rl.puid = ds.puid
	join infodba.pimanfile@&linked_server fl on
		fl.puid = rl.pvalu_0
	join infodba.pitem@&linked_server item on
		item.puid = r2.ritems_tagu
	join &table_name chk on
		chk.doc_id = item.pitem_id 
		and chk.revision = r2.pitem_revision_id
order by 
	pitem_id, pitem_revision_id, fl.poriginal_file_name
;
