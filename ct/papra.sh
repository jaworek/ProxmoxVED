#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: jaworek
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/papra-hq/papra

APP="Papra"
var_tags="${var_tags:-productivity}"
var_disk="${var_disk:-10}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/papra ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  PNPM_VERSION="10.19.0"
  NODE_VERSION="24" NODE_MODULE="pnpm@${PNPM_VERSION}" setup_nodejs

  if check_for_gh_release "papra" "papra-hq/papra"; then
    msg_info "Stopping Service"
    systemctl stop papra
    msg_ok "Stopped Service"

    msg_info "Creating Backup"
    cp /opt/papra/.env /opt/papra_env.backup
    tar -czf /opt/papra_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
      /opt/papra/app-data/db \
      /opt/papra/app-data/documents 2>/dev/null || true
    msg_ok "Backup Created"

    RELEASE=$(curl -fsSL https://api.github.com/repos/papra-hq/papra/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
    msg_info "Updating ${APP} to v${RELEASE}"
    cd /opt
    curl -fsSL "https://github.com/papra-hq/papra/archive/refs/tags/v${RELEASE}.tar.gz" -o "papra-${RELEASE}.tar.gz"
    $STD tar -xzf papra-${RELEASE}.tar.gz
    rm -rf papra-${RELEASE}.tar.gz
    cp -r papra-${RELEASE}/* /opt/papra/
    rm -rf papra-${RELEASE}
    cp /opt/papra_env.backup /opt/papra/.env
    cd /opt/papra
    export NODE_ENV=production
    export NODE_OPTIONS="--max-old-space-size=3584"
    export NEXT_PUBLIC_VERSION="v${RELEASE}"
    export NEXT_PUBLIC_BUILDTIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    $STD pnpm install --frozen-lockfile
    $STD pnpm build
    echo "${RELEASE}" >/opt/papra_version.txt
    msg_ok "Updated ${APP} to v${RELEASE}"

    msg_info "Starting Service"
    systemctl start papra
    msg_ok "Started Service"
    msg_ok "Updated Successfully!"
  else
    msg_ok "No update required. ${APP} is already at the latest version."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:1221${CL}"
