
USE Db_Name

SELECT DB_NAME() AS DatabaseName,
       i.name AS IndexName,
       OBJECT_NAME(ips.object_id) AS TableName,
       ips.index_id,
       index_type_desc,
       avg_fragmentation_in_percent,
       page_count / 128 AS SizeMB
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) ips
    INNER JOIN sys.indexes i
        ON (ips.object_id = i.object_id)
           AND (ips.index_id = i.index_id)
WHERE ips.index_type_desc = 'NONCLUSTERED INDEX'
      AND ips.avg_fragmentation_in_percent > 89
ORDER BY avg_fragmentation_in_percent DESC;