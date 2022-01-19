USE master;

DECLARE @command_create VARCHAR(1000);
DECLARE @command_drop VARCHAR(1000);

SELECT @command_drop
    = 'IF ''?'' NOT IN(''master'', ''model'', ''msdb'', ''tempdb'') BEGIN USE ? DROP PROCEDURE IF EXISTS dbo.SP_IndexFragmentation_bcck END';

EXEC sp_MSforeachdb @command_drop;

SELECT @command_create
    = 'IF ''?'' NOT IN(''master'', ''model'', ''msdb'', ''tempdb'') BEGIN USE ? 
   EXEC(''
CREATE PROCEDURE SP_IndexFragmentation_bcck
AS
DROP TABLE IF EXISTS dbo.IndexFragmentation_bcck;

SELECT DB_NAME() AS DatabaseName,
       i.name AS IndexName,
       OBJECT_NAME(ips.object_id) AS TableName,
       ips.index_id,
       index_type_desc,
       avg_fragmentation_in_percent,
       page_count / 128 AS SizeMB,
       CAST(GETDATE() AS SMALLDATETIME) AS CollectionDate,
       0 AS Rebuilt
INTO IndexFragmentation_bcck
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) ips
    INNER JOIN sys.indexes i
        ON (ips.object_id = i.object_id)
           AND (ips.index_id = i.index_id)
WHERE ips.index_type_desc = ''''NONCLUSTERED INDEX''''
      AND ips.avg_fragmentation_in_percent > 89
ORDER BY avg_fragmentation_in_percent DESC;
'') END';

EXEC sp_MSforeachdb @command_create;

USE [msdb];
GO

/****** Object:  Job [IX_Fragmentation_bcck]    Script Date: 3.12.2021. 12:21:57 ******/
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3.12.2021. 12:21:57 ******/
IF NOT EXISTS
(
    SELECT name
    FROM msdb.dbo.syscategories
    WHERE name = N'[Uncategorized (Local)]'
          AND category_class = 1
)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class = N'JOB',
                                                @type = N'LOCAL',
                                                @name = N'[Uncategorized (Local)]';
    IF (@@ERROR <> 0 OR @ReturnCode <> 0)
        GOTO QuitWithRollback;

END;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'IX_Fragmentation_bcck',
                                       @enabled = 1,
                                       @notify_level_eventlog = 0,
                                       @notify_level_email = 0,
                                       @notify_level_netsend = 0,
                                       @notify_level_page = 0,
                                       @delete_level = 0,
                                       @description = N'No description available.',
                                       @category_name = N'[Uncategorized (Local)]',
                                       @owner_login_name = N'sa',
                                       @job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
    GOTO QuitWithRollback;
/****** Object:  Step [1. EXEC Proc]    Script Date: 3.12.2021. 12:21:57 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId,
                                           @step_name = N'1. EXEC Proc',
                                           @step_id = 1,
                                           @cmdexec_success_code = 0,
                                           @on_success_action = 1,
                                           @on_success_step_id = 0,
                                           @on_fail_action = 2,
                                           @on_fail_step_id = 0,
                                           @retry_attempts = 0,
                                           @retry_interval = 0,
                                           @os_run_priority = 0,
                                           @subsystem = N'TSQL',
                                           @command = N'DECLARE @command NVARCHAR(1000);

SELECT @command
    = N''IF ''''?'''' NOT IN(''''master'''', ''''model'''', ''''msdb'''', ''''tempdb'''') BEGIN USE ? 
   EXEC(''''
   SP_IndexFragmentation_bcck
'''') END'';

EXEC sp_MSforeachdb @command;
',
                                           @database_name = N'master',
                                           @flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
    GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId,
                                          @start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
    GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @jobId,
                                               @name = N'Daily 05:00',
                                               @enabled = 1,
                                               @freq_type = 4,
                                               @freq_interval = 1,
                                               @freq_subday_type = 1,
                                               @freq_subday_interval = 0,
                                               @freq_relative_interval = 0,
                                               @freq_recurrence_factor = 0,
                                               @active_start_date = 20211203,
                                               @active_end_date = 99991231,
                                               @active_start_time = 50000,
                                               @active_end_time = 235959,
                                               @schedule_uid = N'175beb07-b6c5-4c3e-bd79-fa4360b31819';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
    GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId,
                                             @server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
    GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;
EndSave:
GO

