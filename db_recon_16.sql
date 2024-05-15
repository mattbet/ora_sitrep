-- Nome db_recon.sql
-- Versione 1.6
-- Data: 20240514
-- Autore: matteo.bettini@gmail.com
-- Descrizione: Script ricognizione dati istanza Oracle 

-- Imposta lo spool per i risultati
SET LINESIZE 300;
SET PAGESIZE 40000;
SET LONG 300;
COLUMN nome_file NEW_VALUE risultati NOPRINT
select UPPER(INSTANCE_NAME) || '_' || TO_CHAR(SYSDATE,'DDMONYYYY_HH24MISS') || '.out' nome_file from V$INSTANCE;
SPOOL &risultati

-- Dati istanza
select HOST_NAME from V$INSTANCE;
select NAME, DBID, DB_UNIQUE_NAME, LOG_MODE, PLATFORM_NAME from V$DATABASE;
select BANNER_FULL from V$VERSION;
select PRODUCT, VERSION from SYS.PRODUCT_COMPONENT_VERSION;
select dbms_utility.port_string from dual;

-- Parametri
column Parametro format a30
column Valore format a80
select distinct(name) Parametro, display_value Valore from v$parameter
where name in ('asm_diskgroups','asm_diskstring','cluster_database','cluster_database_instances','compatible','control_files','cpu_count','db_name','db_recovery_file_dest','db_recovery_file_dest_size','db_unique_name','instance_name','instance_type','memory_max_target','memory_target','nls_language','nls_territory','nls_characterset','pga_aggregate_limit','pga_aggregate_target','sessions','sga_max_size','sga_min_size','sga_target','spfile') 
or isdefault='FALSE' 
order by 1;
select * from NLS_DATABASE_PARAMETERS where parameter in('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET');
select round(value/1048576) PGA_MAX_ALL_MB from v$pgastat where name='maximum PGA allocated';
select RESOURCE_NAME, CURRENT_UTILIZATION, MAX_UTILIZATION, LIMIT_VALUE from V$RESOURCE_LIMIT where RESOURCE_NAME IN ('sessions', 'processes');
-- DB Links
select * from DBA_DB_LINKS;
-- Directory
column OWNER format a30
column DIRECTORY_NAME format a30
column DIRECTORY_PATH format a80
select OWNER, DIRECTORY_NAME, DIRECTORY_PATH from all_directories;
-- Tablespace e dati
select ts.TABLESPACE_NAME, round(ts.df_mb/1048576) DF_MB, round(sg.sg_mb/1048576) DATI_MB from 
(select nvl(TABLESPACE_NAME,'Totale') TABLESPACE_NAME, sum (BYTES) df_mb from DBA_DATA_FILES group by rollup(TABLESPACE_NAME)) ts,
(select nvl(TABLESPACE_NAME,'Totale') TABLESPACE_NAME, sum (BYTES) sg_mb from DBA_SEGMENTS group by rollup(TABLESPACE_NAME)) sg
where sg.TABLESPACE_NAME = ts.TABLESPACE_NAME
order by 2 asc;
select TABLESPACE_NAME, TABLESPACE_SIZE/1048576 SIZE_MB, ALLOCATED_SPACE/1048576 ALLOC_MB, FREE_SPACE/1048576 LIBERO_MB from DBA_TEMP_FREE_SPACE;
select round(max(tablespace_usedsize)*8192/1048576) as MAX_TEMP_MB from dba_hist_tbspc_space_usage where tablespace_id in (select ts# from DBA_HIST_TABLESPACE where contents = 'TEMPORARY');
-- FRA
show parameter db_recovery_file_dest_size;
column NAME format a50
column SPACE_LIMIT format a20
column SPACE_USED format a20
column SPACE_RECLAIMABLE format a20
column NUMBER_OF_FILES format a20
select NAME, SPACE_LIMIT, SPACE_USED, SPACE_RECLAIMABLE, NUMBER_OF_FILES from V$RECOVERY_FILE_DEST;
select * from V$FLASH_RECOVERY_AREA_USAGE;
-- Avvisi sul dimensionamento della memoria
select * from V$SGA_TARGET_ADVICE;
select round(PGA_TARGET_FOR_ESTIMATE/1048576) PGA_TARGET_FOR_ESTIMATE_MB, PGA_TARGET_FACTOR, round(BYTES_PROCESSED/1048576) MB_PROCESSED, round(ESTD_TIME,ESTD_EXTRA_BYTES_RW/1048576) ESTD_EXTRA_MB_RW, ESTD_PGA_CACHE_HIT_PERCENTAGE, ESTD_OVERALLOC_COUNT from v$pga_target_advice;
-- Verifica errori ORA- nelle ultime due settimane
select record_id, to_char(originating_timestamp,'DD-MON-YYYY HH24:MI:SS') o_time, message_text 
from X$DBGALERTEXT 
where originating_timestamp > systimestamp - 14 
and regexp_like(message_text, '(ORA-|error)') 
order by record_id desc;
-- Fine
spool off