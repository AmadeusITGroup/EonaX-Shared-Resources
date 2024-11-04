--
--  Copyright (c) 2024 Amadeus SAS
--
--  This program and the accompanying materials are made available under the
--  terms of the Apache License, Version 2.0 which is available at
--  https://www.apache.org/licenses/LICENSE-2.0
--
--  SPDX-License-Identifier: Apache-2.0
--
--  Contributors:
--       Amadeus SAS - Initial SQL Query

-- THIS SCHEMA HAS BEEN WRITTEN AND TESTED ONLY FOR POSTGRES

-- table: edc_telemetry_record
CREATE TABLE IF NOT EXISTS edc_telemetry_record
(
    record_id  VARCHAR NOT NULL,
    properties         JSON    DEFAULT '{}',
    PRIMARY KEY (record_id)
);

COMMENT ON COLUMN edc_asset.properties IS 'Telemetry Record properties serialized as JSON';
