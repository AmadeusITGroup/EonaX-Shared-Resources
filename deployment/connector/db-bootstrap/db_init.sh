#!/bin/bash

echo "Create user $DB_USER"
psql -v ON_ERROR_STOP=1 -h $DB_FQDN --username $POSTGRES_USER --dbname $POSTGRES_DB -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD'"

echo "Create DB $DB_NAME"
psql -v ON_ERROR_STOP=1 -h $DB_FQDN --username $POSTGRES_USER --dbname $POSTGRES_DB -c "CREATE DATABASE $DB_NAME OWNER $DB_USER"

echo "Bootstrap DB $DB_NAME"
psql -v ON_ERROR_STOP=1 -h $DB_FQDN --username $POSTGRES_USER --dbname $DB_NAME -f /db/sql/bootstrap.sql

echo "Grant access to $DB_USER"
psql -v ON_ERROR_STOP=1 -h $DB_FQDN --username $POSTGRES_USER --dbname $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER"