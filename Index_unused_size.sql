WITH s
AS (SELECT objects.name AS Table_name,
           indexes.name AS Index_name,
           dm_db_index_usage_stats.user_seeks,
           dm_db_index_usage_stats.user_scans,
           dm_db_index_usage_stats.user_updates
    FROM sys.dm_db_index_usage_stats
        INNER JOIN sys.objects
            ON dm_db_index_usage_stats.object_id = objects.object_id
        INNER JOIN sys.indexes
            ON indexes.index_id = dm_db_index_usage_stats.index_id
               AND dm_db_index_usage_stats.object_id = indexes.object_id
    WHERE indexes.is_primary_key = 0 --This line excludes primary key constarint
          AND indexes.is_unique = 0 --This line excludes unique key constarint
          AND dm_db_index_usage_stats.user_updates <> 0 -- This line excludes indexes SQL Server hasn’t done any work with
          AND dm_db_index_usage_stats.user_lookups = 0
          AND dm_db_index_usage_stats.user_seeks = 0
          AND dm_db_index_usage_stats.user_scans = 0
--ORDER BY
--    dm_db_index_usage_stats.user_updates DESC
),
     p
AS (SELECT i.[name] AS IndexName,
           SUM(s.[used_page_count]) * 8 / 1024 AS IndexSizeMB
    FROM sys.dm_db_partition_stats AS s
        INNER JOIN sys.indexes AS i
            ON s.[object_id] = i.[object_id]
               AND s.[index_id] = i.[index_id]
    GROUP BY i.[name])
SELECT s.*,
       p.IndexSizeMB
FROM p
    JOIN s
        ON p.IndexName = s.Index_name
ORDER BY IndexSizeMB DESC;

