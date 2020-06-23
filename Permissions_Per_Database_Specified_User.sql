


DECLARE @command varchar(1000) 
SELECT @command = 'USE ? SELECT DB_NAME() AS [Current Database], sys.schemas.name ''Schema'',
       sys.objects.name Object,
       sys.database_principals.name username,
       sys.database_permissions.type permissions_type,
       sys.database_permissions.permission_name,
       sys.database_permissions.state permission_state,
       sys.database_permissions.state_desc,
       state_desc + '' '' + permission_name + '' on ['' + sys.schemas.name + ''].['' + sys.objects.name + ''] to [''
       + sys.database_principals.name + '']'' COLLATE Latin1_General_CI_AS
FROM sys.database_permissions
    JOIN sys.objects
        ON sys.database_permissions.major_id = sys.objects.object_id
    JOIN sys.schemas
        ON sys.objects.schema_id = sys.schemas.schema_id
    JOIN sys.database_principals
        ON sys.database_permissions.grantee_principal_id = sys.database_principals.principal_id
WHERE sys.database_principals.name = ''INSERT_LOGIN_HERE''
ORDER BY 1,
         2,
         3,
         5'
EXEC sp_MSforeachdb @command 
