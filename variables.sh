#!/bin/bash

# PostgreSQL 
export PGHOST="192.168.100.107"
export PGPORT="5432"
export PGUSER="grafana"
export PGPASSWORD="oracle_4U"
export PGDATABASE_SOURCE_PHASE_1="grafana_35199"
export PGDATABASE_SOURCE_PHASE_2="grafana_2929"

# Grafana Configurations
export GRAFANA_URL="http://192.168.100.107:3000"
export GRAFANA_USER="admin"
export GRAFANA_PASSWORD="oracle_4U"
export GRAFANA_CONFIG_FILE_PATH="/etc/grafana/grafana.ini"

#Grafana Installations
export GRAFANA_831_INSTALLATION="/data/setup/soft/grafana-enterprise-8.3.1-1.x86_64.rpm"
export GRAFANA_833_INSTALLATION="/data/setup/soft/grafana-enterprise-8.3.3-1.x86_64.rpm"
export GRAFANA_9417_INSTALLATION="/data/setup/soft/grafana-enterprise-9.4.17-1.x86_64.rpm"

# Grafana Data Sources
export LOAD_DATA_SOURCE_PHASE_1="/data/35199db/migrate_sqlite3_to_postgres.load"
export DATA_SOURCE_NAME_PHASE_1="35"
export LOAD_DATA_SOURCE_PHASE_2="/data/2929db/migrate_sqlite3_to_postgres.load"
export DATA_SOURCE_NAME_PHASE_2="29"
export DATABASE_DUMP="/data/dbdump"