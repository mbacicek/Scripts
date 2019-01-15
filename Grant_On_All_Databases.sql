Use master
GO

DECLARE @dbname VARCHAR(50)
DECLARE @statement NVARCHAR(max)

DECLARE db_cursor CURSOR 
LOCAL FAST_FORWARD
FOR  
SELECT name
FROM sys.databases
WHERE name NOT IN ('master','model','msdb','tempdb','distribution')
    AND source_database_id IS NULL
OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @dbname
WHILE @@FETCH_STATUS = 0  --
BEGIN

    SELECT @statement = 'use '+@dbname +';'+ 'CREATE USER [LOGIN] 
FOR LOGIN [LOGIN]; EXEC sp_addrolemember N''db_datareader'', 
[LOGIN];EXEC sp_addrolemember N''db_datawriter'', [LOGIN]'

    PRINT @statement --PRINTING THE STATEMENTS FOR EXECUTION

    FETCH NEXT FROM db_cursor INTO @dbname
END
CLOSE db_cursor
DEALLOCATE db_cursor
