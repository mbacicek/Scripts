USE [master]
GO

/****** Object:  StoredProcedure [dbo].[sp_disk_space_alert]    Script Date: 9/21/2018 4:52:48 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[sp_disk_space_alert]
	@from varchar(100),
	@to varchar(200),
	@subject varchar(100),
	@threshold INT   -- kolko MB ti je kritično?
AS

	SET NOCOUNT ON

	DECLARE @list nvarchar(2000) = '';

	WITH core AS ( 
		SELECT DISTINCT
			s.volume_mount_point [Drive],
			CAST(s.available_bytes / 1048576 as decimal(12,2)) [AvailableMBs]
		FROM 
			sys.master_files f
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) s
	)

	SELECT @list = @list + ' ' + Drive + ', '
	FROM core
	WHERE AvailableMBs < @threshold

	IF LEN(@list) > 3 BEGIN
		DECLARE @msg varchar(500) = 'LOW DISK SPACE - Truncate BackupMessages and shrink database ' --tu message staviš koji ti treba
		+ CAST(@threshold as varchar(12)) + ' MB free: ' + @list



EXEC msdb.dbo.sp_send_dbmail @profile_name = 'DB_Mail',
		@recipients = @to,
		@subject = @subject,
		@body = @msg

		END

	RETURN 0
GO