-- VISTRA migration 001: align the imported six-table schema with backend/api.php.
-- FILE ONLY: execute manually only after explicit approval.
-- Select vistra_db in the client before running this file. No USE statement:
-- wrong targets abort and all DDL remains gated if a client continues.
-- Existing users/submissions are retained. No automatic relationship guessing.
SET NAMES utf8mb4;
SET @vistra_target_ok = (DATABASE() = 'vistra_db');
-- BEGIN VISTRA UMKM SCHEMA 001
-- MySQL 8.0.16+ / MariaDB 10.4+; no stored-routine privileges needed.
-- No account creation, data backfill, score recalculation, or row deletion.
-- NULL links preserve legacy records; map legacy accounts/periods separately.
-- Run with the SQL client configured to STOP on errors (never --force).
-- DDL commits implicitly; back up first. This is not a transactional rollback.
-- Preflight rejects incompatible existing additions before attempting DDL.
SET @vistra_schema_ok = COALESCE(@vistra_target_ok, 0) AND
  @@FOREIGN_KEY_CHECKS = 1
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='answers' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='validation_log' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='factor_definitions' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='question_definitions' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND EXTRA LIKE '%auto_increment%')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND EXTRA LIKE '%auto_increment%')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='role' AND IS_NULLABLE='NO' AND COLUMN_TYPE IN ('enum(''owner'',''employee'')','enum(''owner'',''employee'',''platform_admin'')'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id') OR EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND IS_NULLABLE='YES'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id') OR EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND IS_NULLABLE='YES'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role') OR (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role' AND NON_UNIQUE=1)='umkm_id,role,is_active')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user') OR (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user' AND NON_UNIQUE=0)='period_id,user_id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm') OR (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm')='umkm_id:umkms:id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period') OR (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period')='period_id:evaluation_periods:id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='owner_user_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='name' AND COLUMN_TYPE='varchar(150)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='lokasi' AND COLUMN_TYPE='varchar(100)' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='sektor' AND COLUMN_TYPE='varchar(80)' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='omzet' AND DATA_TYPE='bigint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='is_active' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 0 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='updated_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='uq_umkms_owner' AND NON_UNIQUE=0)='owner_user_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='uq_umkms_name' AND NON_UNIQUE=0)='name'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='idx_umkms_active_name' AND NON_UNIQUE=1)='is_active,name'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND CONSTRAINT_NAME='fk_umkms_owner')='owner_user_id:users:id'
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='owner_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='invited_email' AND COLUMN_TYPE='varchar(180)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='code_hash' AND COLUMN_TYPE='char(64)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='code_encrypted' AND DATA_TYPE='text' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='max_uses' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='used_count' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='expires_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='is_active' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 0 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='uq_invitation_hash' AND NON_UNIQUE=0)='code_hash'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='idx_invitation_pending' AND NON_UNIQUE=1)='umkm_id,invited_email,is_active,used_count,expires_at'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='idx_invitation_owner' AND NON_UNIQUE=1)='owner_id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='fk_invitation_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='fk_invitation_owner')='owner_id:users:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='chk_invitation_single_use' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='invitation_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='user_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='used_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='uq_invitation_use' AND NON_UNIQUE=0)='invitation_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='uq_invitation_user' AND NON_UNIQUE=0)='user_id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND CONSTRAINT_NAME='fk_invitation_use_code')='invitation_id:invitation_codes:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND CONSTRAINT_NAME='fk_invitation_use_user')='user_id:users:id'
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='period_name' AND COLUMN_TYPE='varchar(150)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='status' AND LOWER(COLUMN_TYPE)='enum(''open'',''published'',''closed'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='min_employee_responses' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='started_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='completed_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='created_by' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='uq_period_name' AND NON_UNIQUE=0)='umkm_id,period_name'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='uq_period_umkm' AND NON_UNIQUE=0)='id,umkm_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='idx_period_status' AND NON_UNIQUE=1)='umkm_id,status,id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='idx_period_creator' AND NON_UNIQUE=1)='created_by'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='fk_period_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='fk_period_creator')='created_by:users:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='chk_period_min_employees' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='period_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='score_composite' AND COLUMN_TYPE='decimal(5,4)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='score_on_5' AND COLUMN_TYPE='decimal(4,2)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='health_category' AND COLUMN_TYPE='varchar(30)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='respondent_count' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='status' AND LOWER(COLUMN_TYPE)='enum(''draft'',''published'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='calculated_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='published_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='uq_result_umkm_period' AND NON_UNIQUE=0)='umkm_id,period_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='idx_result_period_umkm' AND NON_UNIQUE=1)='period_id,umkm_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='idx_result_published' AND NON_UNIQUE=1)='status,published_at'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='fk_result_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='fk_result_period_umkm')='period_id:evaluation_periods:id,umkm_id:evaluation_periods:umkm_id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='chk_result_scores' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='result_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='factor_key' AND LOWER(COLUMN_TYPE)='enum(''ins'',''ov'',''ldi'',''weq'',''ops'',''ect'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='factor_score' AND COLUMN_TYPE='decimal(5,4)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='respondent_count' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='result_id,factor_key'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND INDEX_NAME='idx_result_factor' AND NON_UNIQUE=1)='factor_key'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND CONSTRAINT_NAME='fk_factor_result')='result_id:evaluation_results:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND CONSTRAINT_NAME='chk_result_factor_score' AND CONSTRAINT_TYPE='CHECK')
  ));
-- The deliberately missing metadata table makes PREPARE fail on bad schemas.
-- Every subsequent DDL is also gated, even if a client continues after errors.
SET @vistra_ddl = IF(@vistra_schema_ok, 'DO 0',
  'SELECT * FROM information_schema.VISTRA_ABORT_INCOMPATIBLE_SCHEMA');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id')),
  'ALTER TABLE `users` ADD COLUMN `umkm_id` INT UNSIGNED NULL DEFAULT NULL AFTER `id`', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id')),
  'ALTER TABLE `submissions` ADD COLUMN `period_id` INT UNSIGNED NULL DEFAULT NULL AFTER `id`', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='role' AND COLUMN_TYPE='enum(''owner'',''employee'')')),
  'ALTER TABLE `users` MODIFY COLUMN `role` ENUM(''owner'',''employee'',''platform_admin'') NOT NULL COMMENT ''Peran akun; admin tidak dibuat otomatis''', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `umkms` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner_user_id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `lokasi` VARCHAR(100) DEFAULT NULL,
  `sektor` VARCHAR(80) DEFAULT NULL,
  `omzet` BIGINT UNSIGNED DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_umkms_owner` (`owner_user_id`),
  UNIQUE KEY `uq_umkms_name` (`name`),
  KEY `idx_umkms_active_name` (`is_active`,`name`),
  CONSTRAINT `fk_umkms_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `invitation_codes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `owner_id` INT UNSIGNED NOT NULL,
  `invited_email` VARCHAR(180) NOT NULL,
  `code_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `code_encrypted` TEXT DEFAULT NULL,
  `max_uses` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `used_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `expires_at` DATETIME NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invitation_hash` (`code_hash`),
  KEY `idx_invitation_pending` (`umkm_id`,`invited_email`,`is_active`,`used_count`,`expires_at`),
  KEY `idx_invitation_owner` (`owner_id`),
  CONSTRAINT `fk_invitation_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_invitation_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_invitation_single_use` CHECK (`max_uses` = 1 AND `used_count` <= `max_uses`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `invitation_uses` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `invitation_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `used_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invitation_use` (`invitation_id`),
  UNIQUE KEY `uq_invitation_user` (`user_id`),
  CONSTRAINT `fk_invitation_use_code` FOREIGN KEY (`invitation_id`) REFERENCES `invitation_codes` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_invitation_use_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `evaluation_periods` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `period_name` VARCHAR(150) NOT NULL,
  `status` ENUM(''open'',''published'',''closed'') NOT NULL DEFAULT ''open'',
  `min_employee_responses` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `started_at` DATETIME DEFAULT NULL,
  `completed_at` DATETIME DEFAULT NULL,
  `created_by` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_period_name` (`umkm_id`,`period_name`),
  UNIQUE KEY `uq_period_umkm` (`id`,`umkm_id`),
  KEY `idx_period_status` (`umkm_id`,`status`,`id`),
  KEY `idx_period_creator` (`created_by`),
  CONSTRAINT `fk_period_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_period_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_period_min_employees` CHECK (`min_employee_responses` BETWEEN 1 AND 50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `evaluation_results` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `period_id` INT UNSIGNED NOT NULL,
  `score_composite` DECIMAL(5,4) NOT NULL,
  `score_on_5` DECIMAL(4,2) NOT NULL,
  `health_category` VARCHAR(30) NOT NULL,
  `respondent_count` INT UNSIGNED NOT NULL,
  `status` ENUM(''draft'',''published'') NOT NULL DEFAULT ''published'',
  `calculated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `published_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_result_umkm_period` (`umkm_id`,`period_id`),
  KEY `idx_result_period_umkm` (`period_id`,`umkm_id`),
  KEY `idx_result_published` (`status`,`published_at`),
  CONSTRAINT `fk_result_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_result_period_umkm` FOREIGN KEY (`period_id`,`umkm_id`) REFERENCES `evaluation_periods` (`id`,`umkm_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_result_scores` CHECK (`score_composite` BETWEEN 0 AND 1 AND `score_on_5` BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `result_factor_scores` (
  `result_id` INT UNSIGNED NOT NULL,
  `factor_key` ENUM(''INS'',''OV'',''LDI'',''WEQ'',''OPS'',''ECT'') NOT NULL,
  `factor_score` DECIMAL(5,4) NOT NULL,
  `respondent_count` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`result_id`,`factor_key`),
  KEY `idx_result_factor` (`factor_key`),
  CONSTRAINT `fk_factor_result` FOREIGN KEY (`result_id`) REFERENCES `evaluation_results` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_result_factor_score` CHECK (`factor_score` BETWEEN 0 AND 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role')),
  'ALTER TABLE `users` ADD KEY `idx_users_umkm_role` (`umkm_id`,`role`,`is_active`)', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user')),
  'ALTER TABLE `submissions` ADD UNIQUE KEY `uq_submission_period_user` (`period_id`,`user_id`)', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm' AND CONSTRAINT_TYPE='FOREIGN KEY')),
  'ALTER TABLE `users` ADD CONSTRAINT `fk_users_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period' AND CONSTRAINT_TYPE='FOREIGN KEY')),
  'ALTER TABLE `submissions` ADD CONSTRAINT `fk_sub_period` FOREIGN KEY (`period_id`) REFERENCES `evaluation_periods` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SELECT IF(@vistra_schema_ok, 'VISTRA schema 001 completed; legacy NULL links are unchanged.', 'VISTRA schema 001 ABORTED: incompatible schema.') AS migration_status;
-- END VISTRA UMKM SCHEMA 001
