
DECLARE @DB_Name VARCHAR(100);
DECLARE @Command NVARCHAR(2000);
DECLARE database_cursor CURSOR FOR
SELECT name
FROM master.sys.sysdatabases
WHERE name NOT IN ( 'master', 'model', 'tempdb', 'msdb', 'UDBAA', 'test' ); --MODA JO FILTRIRARI


OPEN database_cursor;

FETCH NEXT FROM database_cursor
INTO @DB_Name;

WHILE @@FETCH_STATUS = 0
BEGIN

    SELECT @Command
        = 'USE ' + @DB_Name + ';'
          + 'SELECT state_desc,
       permission_name,
       ''ON'',
       OBJECT_NAME(major_id),
       ''TO'',
       U.name
FROM sys.database_permissions P
    JOIN sys.tables T
        ON P.major_id = T.object_id
    JOIN sysusers U
        ON U.uid = P.grantee_principal_id
WHERE U.name = ''PICK A USER'';';  --UNOS LOGINA / USERA ZA PROVJERU PRAVA

    PRINT @Command;

    FETCH NEXT FROM database_cursor
    INTO @DB_Name;
END;

CLOSE database_cursor;
DEALLOCATE database_cursor;