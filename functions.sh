#!/bin/bash

preparing_to_run_script() {
    stop_grafana
    psql -d postgres -c "DROP DATABASE IF EXISTS $1;"
}

stop_grafana() {
    systemctl stop grafana-server && systemctl status grafana-server --no-pager
}

restart_grafana() {
    systemctl restart grafana-server && systemctl status grafana-server --no-pager
}

change_grafana_version() {
    grafana_package=$(rpm -qa | grep grafana)
    if [ -n "$grafana_package" ]; then
        rpm -e "$grafana_package"
    else
        echo "Package grafana not found."
    fi
    rpm -ivh "$1"
}

truncate_default_metadata() {
    TABLES=(
        "alert"
        "alert_configuration"
        "alert_instance"
        "alert_notification"
        "alert_notification_state"
        "alert_rule"
        "alert_rule_tag"
        "alert_rule_version"
        "annotation"
        "annotation_tag"
        "api_key"
        "builtin_role"
        "cache_data"
        "dashboard"
        "dashboard_acl"
        "dashboard_provisioning"
        "dashboard_snapshot"
        "dashboard_tag"
        "dashboard_usage_by_day"
        "dashboard_usage_sums"
        "dashboard_version"
        "data_keys"
        "data_source"
        "data_source_acl"
        "data_source_cache"
        "data_source_usage_by_day"
        "kv_store"
        "library_element"
        "library_element_connection"
        "license_token"
        "login_attempt"
        "migration_log"
        "ngalert_configuration"
        "org"
        "org_user"
        "permission"
        "playlist"
        "playlist_item"
        "plugin_setting"
        "preferences"
        "quota"
        "report"
        "report_settings"
        "role"
        "seed_assignment"
        "server_lock"
        "session"
        "setting"
        "short_url"
        "star"
        "tag"
        "team"
        "team_group"
        "team_member"
        "team_role"
        "temp_user"
        "test_data"
        '"user"'
        "user_auth"
        "user_auth_token"
        "user_dashboard_views"
        "user_role"
        "user_stats"
    )
    psql -d "$1" -c "TRUNCATE TABLE $(IFS=,; echo "${TABLES[*]}");"
}

rename_data_sources() {
    psql -d "$1" -c "UPDATE data_source SET name = concat('$2_', name); SELECT name FROM data_source;"
}

get_credentials() {
    CREDENTIALS=$(echo -n "$GRAFANA_USER:$GRAFANA_PASSWORD" | base64)
    export CREDENTIALS
}

export_data_sources() {
    while IFS= read -r uid; do
        if response=$(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/datasources/uid/$uid"); then
            mkdir -p "export"
            echo "$response" | jq > "export/grafana-datasource-$uid.json"
            slug=$(jq -r '.name' "export/grafana-datasource-${uid}.json")
            echo "Rename from ${uid} to ${uid}-${slug}."
            mv "export/grafana-datasource-${uid}.json" "export/grafana-datasource-${uid}-${slug}.json"
            echo "Datasource $uid exported."
        else
            echo "Failed to export data sources $uid. Skipping..."
        fi
    done < <(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/datasources" | jq -r '.[] | .uid')

    mkdir -p "$DATABASE_DUMP"
    chown -R postgres. "$DATABASE_DUMP"
    psql -d "$PGDATABASE_SOURCE_2" -c "\copy data_source to '/data/dbdump/data_source_$DATA_SOURCE_NAME_PHASE_2.csv' DELIMITER ',' CSV HEADER;"
}

export_dashboard_folder() {
    while IFS= read -r dashboard; do
        if response=$(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/dashboards/uid/$dashboard"); then
            modified_dashboard=$(jq '. |= (.folderUid=.meta.folderUid) | del(.meta) | del(.dashboard.id) + {overwrite: true}' <<< "$response")
            mkdir -p "dashboards_source_$DATA_SOURCE_NAME_PHASE_2"
            echo "$modified_dashboard" > "dashboards_source_$DATA_SOURCE_NAME_PHASE_2/${dashboard}.json"
            echo "Dashboard ${dashboard} saved."
        else
            echo "Failed to fetch dashboard $dashboard. Skipping..."
        fi
    done < <(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/search?query=&" | jq -r '.[] | select(.type == "dash-db") | .uid')

    while IFS= read -r folder; do
        if response=$(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/folders/$folder"); then
            modified_folder=$(jq '. | del(.id) + {overwrite: true}' <<< "$response")
            mkdir -p "folders_source_$DATA_SOURCE_NAME_PHASE_2"
            echo "$modified_folder" > "folders_source_$DATA_SOURCE_NAME_PHASE_2/${folder}.json"
            echo "Folder ${folder} saved."
        else
            echo "Failed to fetch folder $folder. Skipping..."
        fi
    done < <(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/folders" | jq -r '.[] | .uid')
}

export-contact-points() {
    while IFS= read -r contact; do
        CONTACT_UID="$(echo "$contact" | jq -r .uid)"
        mkdir -p "contact_points_$DATA_SOURCE_NAME_PHASE_2"
        echo "$contact" | jq '.' > "contact_points_$DATA_SOURCE_NAME_PHASE_2/contact-point-$CONTACT_UID.json"
        echo "Contact point $CONTACT_UID saved."
    done < <(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/v1/provisioning/contact-points" | jq -c '.[]')
}

export_alert_rules() {
    while IFS= read -r alert; do
        if response=$(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/v1/provisioning/alert-rules/$alert"); then
            modified_alert=$(jq '.id += 1000 | .title += " Alert 29"' <<< "$response")
            mkdir -p "alert_rules_$DATA_SOURCE_NAME_PHASE_2"
            echo "$modified_alert" > "alert_rules_$DATA_SOURCE_NAME_PHASE_2/grafana-alert-$alert.json"
            echo "Alert rule $alert saved."
        else
            echo "Failed to export alert rule $alert. Skipping..."
        fi
    done < <(curl -sSf -X GET -H "Authorization: Basic $CREDENTIALS" "$GRAFANA_URL/api/v1/provisioning/alert-rules" | jq -r '.[] | .uid')
}

import_data_sources() {
    for data_source in export/*.json; do
        if response=$(curl -sSf -X POST -H "Authorization: Basic $CREDENTIALS" -H "Content-type: application/json" "$GRAFANA_URL/api/datasources" -d "@$data_source"); then
            echo "Datasource $data_source imported."
        else
            echo "Failed to import datasource $data_source. Skipping..."
        fi
    done
}


