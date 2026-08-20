#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Duck.ai
# License: MIT
# Source: https://github.com/behindcurtain3/factoriohq

APP="FactorioHQ"

var_tags="${var_tags:-games}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-32}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
# var_testurl="${var_testurl:-http://localhost:3000}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/factoriohq/.env ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  msg_info "Stopping Service"
  systemctl stop factoriohq
  msg_ok "Stopped Service"

  create_backup /opt/factoriohq/.env /opt/factoriohq/factorio-data

  msg_info "Updating Application"
  cd /opt/factoriohq

  git fetch origin
  git reset --hard origin/main

  if [[ ! -f .ruby-version ]]; then
    msg_error "No .ruby-version file found!"
    restore_backup
    systemctl start factoriohq
    exit 1
  fi

  RUBY_VERSION="$(tr -d ' \n' < .ruby-version)"
  RUBY_VERSION="${RUBY_VERSION#ruby-}"
  RUBY_INSTALL_RAILS="false" setup_ruby

  export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

  # This needs to be installed in debug mode, so just ignore the following bundle config lines
  # bundle config set --local without 'development test'
  # bundle config set --local deployment 'true'
  bundle install

  RAILS_ENV=production bundle exec rails db:migrate

  restore_backup

  chown -R 845:845 /opt/factoriohq

  msg_ok "Updated Application"

  msg_info "Starting Service"
  systemctl start factoriohq
  msg_ok "Started Service"

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:3000${CL}"