/*

Updated: 2018-12-18

+ open new query window using SSMS.
+ paste this whole script. 
+ right click on the query windows and then 
>> Results to -> Results to file
+ execute the query
+ select the file to keep the results.

*/
SET NOCOUNT ON;

--(0) - timestamp and metadata
PRINT '*** General information';
PRINT 'SysDateTime';
SELECT SYSDATETIME();
PRINT 'ServerName';
SELECT @@servername;
PRINT 'DatabaseName';
SELECT DB_NAME() AS DatabaseName;

-- Get SLO Level and size
PRINT '*** Get SLO Level and size';
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS Collation;
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Edition') AS Edition;
SELECT DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective') AS ServiceObjective;
SELECT DATABASEPROPERTYEX(DB_NAME(), 'MaxSizeInBytes') AS MaxSizeInBytes;
SELECT DATABASEPROPERTYEX(DB_NAME(), 'IsParameterizationForced') AS Parameterization;
SELECT @@version;


--(1)
PRINT '***When were Statistics last updated on all indexes? ';
SELECT ObjectSchema = OBJECT_SCHEMA_NAME(s.object_id),
       ObjectName = OBJECT_NAME(s.object_id),
       StatsName = s.name,
       sp.last_updated,
       idx.rowcnt CurrentRowCnt,
       sp.rows RowCntWhenStatsTaken,
       sp.rows_sampled,
       sp.modification_counter,
       pct_modified = FORMAT((1.0 * sp.modification_counter / idx.rowcnt), 'p'),
       LastStatsUpdatedWith = IIF(sp.rows_sampled = sp.rows, 'FullScan', 'Partial'),
       'UPDATE STATISTICS [' + OBJECT_SCHEMA_NAME(s.object_id) + '].[' + OBJECT_NAME(s.object_id) + '](' + s.name
       + ') WITH FULLSCAN'
FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    JOIN sys.objects o
        ON s.object_id = o.object_id
    LEFT JOIN sys.sysindexes idx
        ON idx.id = s.object_id
           AND idx.indid IN ( 0, 1 )
WHERE s.object_id > 100
      AND o.schema_id != 4 /*sys*/
      AND idx.rowcnt > 0
ORDER BY modification_counter DESC;



--(2)
PRINT '***Get fragmentation info for all indexes above a certain size in the current database';
-- Note: This could take some time on a very large database
SELECT DB_NAME(database_id) AS [Database Name],
       OBJECT_NAME(ps.object_id) AS [Object Name],
       i.name AS [Index Name],
       ps.index_id,
       ps.index_type_desc,
       ps.avg_fragmentation_in_percent,
       ps.fragment_count,
       ps.page_count,
       i.fill_factor,
       i.has_filter,
       i.filter_definition
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
    INNER JOIN sys.indexes AS i WITH (NOLOCK)
        ON ps.[object_id] = i.[object_id]
           AND ps.index_id = i.index_id
WHERE database_id = DB_ID()
      AND page_count > 250
ORDER BY avg_fragmentation_in_percent DESC
OPTION (RECOMPILE);

--(3)
PRINT '***Index Read/Write stats (all tables in current DB) ordered by Reads';
SELECT OBJECT_NAME(s.[object_id]) AS [ObjectName],
       i.name AS [IndexName],
       i.index_id,
       user_seeks + user_scans + user_lookups AS [Reads],
       s.user_updates AS [Writes],
       i.type_desc AS [IndexType],
       i.fill_factor AS [FillFactor],
       i.has_filter,
       i.filter_definition,
       s.last_user_scan,
       s.last_user_lookup,
       s.last_user_seek
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
    INNER JOIN sys.indexes AS i WITH (NOLOCK)
        ON s.[object_id] = i.[object_id]
WHERE OBJECTPROPERTY(s.[object_id], 'IsUserTable') = 1
      AND i.index_id = s.index_id
      AND s.database_id = DB_ID()
ORDER BY user_seeks + user_scans + user_lookups DESC
OPTION (RECOMPILE); -- Order by reads


--(4)
PRINT '***full rowset of sys.dm_db_file_space_usage';
SELECT *
FROM sys.dm_db_file_space_usage;
GO

PRINT '***Table sizes';
SELECT s.name AS SchemaName,
       t.name AS TableName,
       p.rows AS RowCounts,
       SUM(a.total_pages) * 8 AS TotalSpaceKB,
       SUM(a.used_pages) * 8 AS UsedSpaceKB,
       (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM sys.tables t
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.indexes i
        ON t.object_id = i.object_id
    INNER JOIN sys.partitions p
        ON i.object_id = p.object_id
           AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a
        ON p.partition_id = a.container_id
WHERE t.name NOT LIKE 'dt%' -- filter out system tables for diagramming
      AND t.is_ms_shipped = 0
      AND i.object_id > 255
GROUP BY t.name,
         s.name,
         p.rows
ORDER BY s.name,
         t.name;

GO
PRINT 'sp_spaceused';
EXEC sp_spaceused;
GO


-- (5)
PRINT '***missing indexes';
SELECT id.[object_id] AS [ObjectID],
       id.[statement] AS [FullyQualifiedObjectName],
       id.[equality_columns] AS [EqualityColumns],
       id.[inequality_columns] AS [InEqualityColumns],
       id.[included_columns] AS [IncludedColumns],
       gs.[unique_compiles] AS [UniqueCompiles],
       gs.[user_seeks] AS [UserSeeks],
       gs.[user_scans] AS [UserScans],
       gs.[last_user_seek] AS [LastUserSeekTime],
       gs.[last_user_scan] AS [LastUserScanTime],
       gs.[avg_total_user_cost] AS [AvgTotalUserCost],
       gs.[avg_user_impact] AS [AvgUserImpact],
       gs.[system_seeks] AS [SystemSeeks],
       gs.[system_scans] AS [SystemScans],
       gs.[last_system_seek] AS [LastSystemSeekTime],
       gs.[last_system_scan] AS [LastSystemScanTime],
       gs.[avg_total_system_cost] AS [AvgTotalSystemCost],
       gs.[avg_system_impact] AS [AvgSystemImpact],
       gs.[user_seeks] * gs.[avg_total_user_cost] * (gs.[avg_user_impact] * 0.01) AS [IndexAdvantage],
       'CREATE INDEX [Missing_IXNC_' + OBJECT_NAME(id.[object_id]) + '_'
       + REPLACE(REPLACE(REPLACE(ISNULL(id.[equality_columns], ''), ', ', '_'), '[', ''), ']', '')
       + CASE
             WHEN id.[equality_columns] IS NOT NULL
                  AND id.[inequality_columns] IS NOT NULL THEN
                 '_'
             ELSE
                 ''
         END + REPLACE(REPLACE(REPLACE(ISNULL(id.[inequality_columns], ''), ', ', '_'), '[', ''), ']', '') + '_'
       + LEFT(CAST(NEWID() AS [NVARCHAR](64)), 5) + ']' + ' ON ' + id.[statement] + ' ('
       + ISNULL(id.[equality_columns], '') + CASE
                                                 WHEN id.[equality_columns] IS NOT NULL
                                                      AND id.[inequality_columns] IS NOT NULL THEN
                                                     ','
                                                 ELSE
                                                     ''
                                             END + ISNULL(id.[inequality_columns], '') + ')'
       + ISNULL(' INCLUDE (' + id.[included_columns] + ')', '') AS [ProposedIndex],
       CAST(CURRENT_TIMESTAMP AS [SMALLDATETIME]) AS [CollectionDate]
FROM [sys].[dm_db_missing_index_group_stats] gs WITH (NOLOCK)
    INNER JOIN [sys].[dm_db_missing_index_groups] ig WITH (NOLOCK)
        ON gs.[group_handle] = ig.[index_group_handle]
    INNER JOIN [sys].[dm_db_missing_index_details] id WITH (NOLOCK)
        ON ig.[index_handle] = id.[index_handle]
ORDER BY [IndexAdvantage] DESC
OPTION (RECOMPILE);


-- (6)

PRINT '***Get Average Waits for Database';
WITH [Waits]
AS (SELECT [wait_type],
           [wait_time_ms] / 1000.0 AS [WaitS],
           ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
           [signal_wait_time_ms] / 1000.0 AS [SignalS],
           [waiting_tasks_count] AS [WaitCount],
           100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS [Percentage],
           ROW_NUMBER() OVER (ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_db_wait_stats
    WHERE [wait_type] NOT IN ( N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
                               N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT',
                               N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE', N'DBMIRROR_DBM_EVENT',
                               N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',
                               N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE', N'EXECSYNC', N'FSAGENT',
                               N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX', N'HADR_CLUSAPI_CALL',
                               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
                               N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', N'KSOURCE_WAKEUP',
                               N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
                               N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
                               N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'REQUEST_FOR_DEADLOCK_SEARCH',
                               N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
                               N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
                               N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
                               N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
                               N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
                               N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_HOST_WAIT',
                               N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
                               N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT'
                             ))
SELECT [W1].[wait_type] AS [WaitType],
       CAST([W1].[WaitS] AS DECIMAL(16, 2)) AS [Wait_S],
       CAST([W1].[ResourceS] AS DECIMAL(16, 2)) AS [Resource_S],
       CAST([W1].[SignalS] AS DECIMAL(16, 2)) AS [Signal_S],
       [W1].[WaitCount] AS [WaitCount],
       CAST([W1].[Percentage] AS DECIMAL(5, 2)) AS [Percentage],
       CAST(([W1].[WaitS] / [W1].[WaitCount]) AS DECIMAL(16, 4)) AS [AvgWait_S],
       CAST(([W1].[ResourceS] / [W1].[WaitCount]) AS DECIMAL(16, 4)) AS [AvgRes_S],
       CAST(([W1].[SignalS] / [W1].[WaitCount]) AS DECIMAL(16, 4)) AS [AvgSig_S]
FROM [Waits] AS [W1]
    INNER JOIN [Waits] AS [W2]
        ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum],
         [W1].[wait_type],
         [W1].[WaitS],
         [W1].[ResourceS],
         [W1].[SignalS],
         [W1].[WaitCount],
         [W1].[Percentage]
HAVING SUM([W2].[Percentage]) - [W1].[Percentage] < 95; -- percentage threshold
GO


--(7) - Currently active queries 
PRINT '*** exec requests';
SELECT *
FROM sys.dm_exec_requests;

PRINT '*** exec sessions';
SELECT c.session_id,
       c.net_transport,
       c.encrypt_option,
       c.auth_scheme,
       s.host_name,
       s.program_name,
       s.client_interface_name,
       s.login_name,
       s.nt_domain,
       s.nt_user_name,
       s.original_login_name,
       c.connect_time,
       s.login_time
FROM sys.dm_exec_connections AS c
    JOIN sys.dm_exec_sessions AS s
        ON c.session_id = s.session_id;


--(8) - db stats
PRINT '*** content of dm_db_resource_stats';
SELECT *
FROM sys.dm_db_resource_stats;

--(9)
PRINT '*** current blocking and running batches';
SELECT sql_text.text,
       locks.resource_type,
       locks.resource_subtype,
       locks.resource_description,
       locks.resource_associated_entity_id,
       locks.request_mode,
       locks.request_status,
       ses.login_name,
       ses.original_login_name,
       ses.login_time,
       ses.host_name,
       ses.program_name,
       ses.last_request_start_time
FROM sys.dm_tran_locks locks
    JOIN sys.dm_exec_sessions ses
        ON locks.request_session_id = ses.session_id
    JOIN sys.sysprocesses pr
        ON ses.session_id = pr.spid
    CROSS APPLY sys.dm_exec_sql_text(pr.sql_handle) sql_text;

--(10) - database properties
PRINT '*** sys.databases';
SELECT *
FROM sys.databases;

--(11) deadlocks
PRINT '*** deadlock';
SET QUOTED_IDENTIFIER ON;
WITH CTE
AS (SELECT CAST(event_data AS XML) AS target_data_XML
    FROM sys.fn_xe_telemetry_blob_target_read_file('dl', NULL, NULL, NULL) )
SELECT target_data_XML.value('(/event/@timestamp)[1]', 'DateTime2') AS Timestamp,
       target_data_XML.query('/event/data[@name=''xml_report'']/value/deadlock') AS deadlock_xml,
       target_data_XML.query('/event/data[@name=''database_name'']/value').value('(/value)[1]', 'nvarchar(100)') AS db_name
FROM CTE;

--(12)
PRINT '*** database_scoped_configurations';
SELECT *
FROM sys.database_scoped_configurations;

--(0) - timestamp
SELECT SYSDATETIME();
