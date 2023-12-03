#!/bin/bash

# Import the configuration variable to use
source variables.sh
source functions.sh

# MIGRATE GRAFANA SOURCE DATA 35.199 TO NEW GRAFANA

# Preparing
dnf install jq -y
preparing_to_run_script "$PGDATABASE_SOURCE_1"

# Create a new PostgreSQL database for Grafana
psql -d postgres -c "CREATE DATABASE $PGDATABASE_SOURCE_1;"

# Downgrade Grafana from version 9.4.17 to 8.3.3
change_grafana_version "$GRAFANA_833_INSTALLATION"

# Setup PostgreSQL to Grafana database
sed -i "/^\[database\]/a url = postgres://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE_SOURCE_1" "$GRAFANA_CONFIG_FILE_PATH"

# Start the grafana-server service to get metadata data
restart_grafana
stop_grafana

# Truncate default metadata data of Grafana
truncate_default_metadata "$PGDATABASE_SOURCE_1"

# Migrate data from SQLite to Postgresql for the new Grafana system
pgloader "$LOAD_DATA_SOURCE_PHASE_1"

# # Rename data source 35.199 on the new Grafana database
rename_data_sources "$PGDATABASE_SOURCE_1" "$DATA_SOURCE_NAME_PHASE_1"

# Restart the grafana-server service
restart_grafana

# MIGRATE GRAFANA SOURCE DATA 29.29 TO NEW GRAFANA

# Preparing
preparing_to_run_script "$PGDATABASE_SOURCE_2"

# Create a new PostgreSQL database for Grafana
psql -d postgres -c "CREATE DATABASE $PGDATABASE_SOURCE_2;"

# Downgrade Grafana from version 8.3.3 to 8.3.1
change_grafana_version "$GRAFANA_831_INSTALLATION"

# Setup PostgreSQL to Grafana database
sed -i "s|url = postgres://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE_SOURCE_1|url = postgres://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE_SOURCE_2|" "$GRAFANA_CONFIG_FILE_PATH"

# Start the grafana-server service to get metadata data
restart_grafana
stop_grafana

# Truncate default metadata data of Grafana
truncate_default_metadata "$PGDATABASE_SOURCE_2"

# Migrate data from SQLite to Postgresql for the new Grafana system
pgloader "$LOAD_DATA_SOURCE_PHASE_2"

# Restart the grafana-server service
restart_grafana

# Get credentials for authentication
get_credentials

# Export data sources
export_data_sources

# Upgrade Grafana from version 8.3.1 to 9.4.17
change_grafana_version "$GRAFANA_9417_INSTALLATION"

# Restart the grafana-server service
restart_grafana

# # Export dashboard folder
export_dashboard_folder

# Export contact points
export-contact-points

# Export alert rules
export_alert_rules

# Downgrade Grafana from version 9.4.17 to 8.3.3
change_grafana_version "$GRAFANA_833_INSTALLATION"

# Setup PostgreSQL to Grafana database
sed -i "s|url = postgres://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE_SOURCE_2|url = postgres://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE_SOURCE_1|" "$GRAFANA_CONFIG_FILE_PATH"

# Restart the grafana-server service
restart_grafana

# Import data sources
import_data_sources