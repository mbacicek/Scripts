DECLARE @spacetable table
(
database_name varchar(500) ,
physical_name varchar (500),
total_size_data int,
space_util_data int,
space_data_left int,
percent_fill_data float,
total_size_data_log int,
space_util_log int,
space_log_left int,
percent_fill_log char(50),
[total db size] int,
[total size used] int,
[total size left] int
)
insert into  @spacetable
EXECUTE master.sys.sp_MSforeachdb 'USE [?];
select x.[DATABASE NAME],x.[physical_name],x.[total size data],x.[space util],x.[total size data]-x.[space util] [space left data],
x.[percent fill],y.[total size log],y.[space util],
y.[total size log]-y.[space util] [space left log],y.[percent fill],
y.[total size log]+x.[total size data] ''total db size''
,x.[space util]+y.[space util] ''total size used'',
(y.[total size log]+x.[total size data])-(y.[space util]+x.[space util]) ''total size left''
 from (select DB_NAME() ''DATABASE NAME'', physical_name,
sum(size/1024)*8 ''total size data'',sum(FILEPROPERTY(name,''SpaceUsed'')/1024)*8 ''space util''
,case when sum(size/1024)*8=0 then ''less than 1% used'' else
substring(cast((sum(FILEPROPERTY(name,''SpaceUsed''))*1.0*100/sum(size)) as CHAR(50)),1,6) end ''percent fill''
from sys.master_files where database_id=DB_ID(DB_NAME())  and  type=0
group by type_desc, physical_name  ) as x ,
(select 
sum(size/1024)*8 ''total size log'',sum(FILEPROPERTY(name,''SpaceUsed'')/1024)*8 ''space util''
,case when sum(size/1024)*8=0 then ''less than 1% used'' else
substring(cast((sum(FILEPROPERTY(name,''SpaceUsed''))*1.0*100/sum(size)) as CHAR(50)),1,6) end ''percent fill''
from sys.master_files where database_id=DB_ID(DB_NAME())  and  type=1
group by type_desc, physical_name  )y'
select * from @spacetable
where database_name in ('CrnaGora_Reporting','vezuv','vezuv_accounting','htk_bih','htk_bih_accounting')
order by database_name


