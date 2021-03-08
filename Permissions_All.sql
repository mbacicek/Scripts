


;WITH 
[explicit] AS (
   SELECT [p].[principal_id], [p].[name], [p].[type_desc], [p].[create_date], [p].[is_disabled],
         [dbp].[permission_name] COLLATE SQL_Latin1_General_CP1_CI_AS [permission],
         CAST('' AS SYSNAME) [grant_through]
   FROM [sys].[server_permissions] [dbp]
   INNER JOIN [sys].[server_principals] [p] ON [dbp].[grantee_principal_id] = [p].[principal_id]
   WHERE ([dbp].[type] IN ('CL','TO','IM','ADBO') OR [dbp].[type] LIKE 'AL%')
     AND [dbp].[state] IN ('G','W')
   UNION ALL
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [dp].[is_disabled], [p].[permission], [p].[name] [grant_through]
   FROM [sys].[server_principals] [dp]
   INNER JOIN [sys].[server_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [explicit] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   ),
[fixed] AS (
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [dp].[is_disabled], [p].[name] [permission], CAST('' AS SYSNAME) [grant_through]
   FROM [sys].[server_principals] [dp]
   INNER JOIN [sys].[server_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [sys].[server_principals] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   WHERE [p].[name] IN ('sysadmin','securityadmin','bulkadmin')
   UNION ALL
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [dp].[is_disabled], [p].[permission], [p].[name] [grant_through]
   FROM [sys].[server_principals] [dp]
   INNER JOIN [sys].[server_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [fixed] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   )
SELECT DISTINCT [name], [type_desc], [create_date], [is_disabled], [permission], [grant_through]
FROM [explicit]
WHERE [type_desc] NOT IN ('SERVER_ROLE')
  AND [name] NOT IN ('sa','SQLDBO','SQLNETIQ')
  AND [name] NOT LIKE '##%'
  AND [name] NOT LIKE 'NT SERVICE%'
  AND [name] NOT LIKE 'NT AUTHORITY%'
  AND [name] NOT LIKE 'BUILTIN%'
UNION ALL
SELECT DISTINCT [name], [type_desc], [create_date], [is_disabled], [permission], [grant_through]
FROM [fixed]
WHERE [type_desc] NOT IN ('SERVER_ROLE')
  AND [name] NOT IN ('sa','SQLDBO','SQLNETIQ')
  AND [name] NOT LIKE '##%'
  AND [name] NOT LIKE 'NT SERVICE%'
  AND [name] NOT LIKE 'NT AUTHORITY%'
  AND [name] NOT LIKE 'BUILTIN%'
ORDER BY 1
OPTION(MAXRECURSION 10)

CREATE TABLE #Info([database] SYSNAME, [username] SYSNAME, [type_desc] NVARCHAR(60), [create_date] DATETIME, [permission] SYSNAME, [grant_through] SYSNAME)
DECLARE @cmd VARCHAR(MAX)
SET @cmd = ''
SELECT @cmd = @cmd + 'INSERT #Info EXEC(''
USE ['+[name]+']
;WITH 
[explicit] AS (
   SELECT [p].[principal_id], [p].[name], [p].[type_desc], [p].[create_date],
         [dbp].[permission_name] COLLATE SQL_Latin1_General_CP1_CI_AS [permission],
         CAST('''''''' AS SYSNAME) [grant_through]
   FROM [sys].[database_permissions] [dbp]
   INNER JOIN [sys].[database_principals] [p] ON [dbp].[grantee_principal_id] = [p].[principal_id]
   WHERE ([dbp].[type] IN (''''IN'''',''''UP'''',''''DL'''',''''CL'''',''''DABO'''',''''IM'''',''''SL'''',''''TO'''') OR [dbp].[type] LIKE ''''AL%'''' OR [dbp].[type] LIKE ''''CR%'''')
     AND [dbp].[state] IN (''''G'''',''''W'''')
   UNION ALL
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [p].[permission], [p].[name] [grant_through]
   FROM [sys].[database_principals] [dp]
   INNER JOIN [sys].[database_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [explicit] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   ),
[fixed] AS (
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [p].[name] [permission], CAST('''''''' AS SYSNAME) [grant_through]
   FROM [sys].[database_principals] [dp]
   INNER JOIN [sys].[database_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [sys].[database_principals] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   WHERE [p].[name] IN (''''db_owner'''',''''db_datareader'''',''''db_datawriter'''',''''db_ddladmin'''',''''db_securityadmin'''',''''db_accessadmin'''')
   UNION ALL
   SELECT [dp].[principal_id], [dp].[name], [dp].[type_desc], [dp].[create_date], [p].[permission], [p].[name] [grant_through]
   FROM [sys].[database_principals] [dp]
   INNER JOIN [sys].[database_role_members] [rm] ON [rm].[member_principal_id] = [dp].[principal_id]
   INNER JOIN [fixed] [p] ON [p].[principal_id] = [rm].[role_principal_id]
   )
SELECT DB_NAME(), [name], [type_desc], [create_date], [permission], [grant_through]
FROM [explicit]
WHERE [type_desc] NOT IN (''''DATABASE_ROLE'''')
UNION ALL
SELECT DB_NAME(), [name], [type_desc], [create_date], [permission], [grant_through]
FROM [fixed]
WHERE [type_desc] NOT IN (''''DATABASE_ROLE'''')
OPTION(MAXRECURSION 10)
'');'
FROM [sys].[databases]
WHERE [state_desc] = 'ONLINE'
EXEC (@cmd)
SELECT DISTINCT *
FROM #Info
--FILTERING
WHERE [username] NOT IN ('dbo','guest','SQLDBO')
  AND [username] NOT LIKE '##%'
  AND [database] NOT IN ('master','model','msdb','tempdb')
  --AND username = 'LOGIN_NAME'  --ADDITIONAL FILTERING
ORDER BY 1, 2
DROP TABLE #Info