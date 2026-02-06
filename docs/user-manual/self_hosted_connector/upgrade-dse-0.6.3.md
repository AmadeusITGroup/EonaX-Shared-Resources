## Overview: 
The new version of dse-0.6.3 includes the newer version of EDC V 0.14. This new version of EDC has included some breaking changes and DB schema changes. This document will guide you through the steps to upgrade your existing dse-0.5.18 to dse-0.6.3 and above. 

## Upgrade Steps:
1. Backup your existing PostgreSQL database. This is crucial to prevent data loss during the upgrade process.

2. Run the migration scripts provided in the dse-0.6.3 release. These scripts will update your database schema to be compatible with the new version of EDC.

    ``` SQL
    BEGIN;
    -- migrate edc-holder-credentialrequest table ----
    -- 1. Add the new 'ids_and_formats' column
    ALTER TABLE edc_holder_credentialrequest 
    ADD COLUMN ids_and_formats json;
    -- 2. Migrate data: transform types_and_formats (object) to ids_and_formats (array)
    -- Old format: {"MembershipCredential":"VC1_0_JWT"}
    -- New format: [{"id":"membership-credential-def-1","credentialType":"MembershipCredential","format":"VC1_0_JWT"}]
    UPDATE edc_holder_credentialrequest 
    SET ids_and_formats = (
        SELECT json_agg(
            json_build_object(
                'id', CASE 
                    WHEN key = 'MembershipCredential' THEN 'membership-credential-def-1'
                    WHEN key = 'DomainCredential' THEN 'domain-credential-def-1'
                    ELSE key
                END,
                'credentialType', key,
                'format', value
            )
        )
        FROM json_each_text(types_and_formats)
    )
    WHERE types_and_formats IS NOT NULL 
    AND types_and_formats::text != '{}'
    AND json_typeof(types_and_formats) = 'object';
    -- 3. Set empty array for NULL values before adding NOT NULL constraint
    UPDATE edc_holder_credentialrequest 
    SET ids_and_formats = '[]'::json 
    WHERE ids_and_formats IS NULL;
    -- migrate edc-holder-credentialrequest table ----
    -- 1. Add NOT NULL constraint
    ALTER TABLE edc_holder_credentialrequest 
    ALTER COLUMN ids_and_formats SET NOT NULL;
    -- 2. Drop the old types_and_formats column (only after you test the platform)
    ALTER TABLE edc_holder_credentialrequest 
    DROP COLUMN types_and_formats;
    ALTER TABLE edc_data_plane 
    ADD COLUMN resource_definitions json DEFAULT '[]'::json;
    COMMIT;
    ```
    This script is also available in the open source [repository](https://github.com/AmadeusITGroup/Dataspace_Ecosystem/blob/master/sql-migrations-v0.14/participant-migration.sql)

3. Update your connector deployment to use the new dse-0.6.3 image. 