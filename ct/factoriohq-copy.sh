#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/core/main/core/build.func)

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Duck.ai
# License: MIT
# Source: https://github.com/behindcurtain3/factoriohq

APP="FactorioHQ"
var_tags="${var_tags:-games;factorio;rails;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_testurl="${var_testurl:-http://localhost:3000}"

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
    exit
  fi

  msg_info "Stopping Services"
  systemctl stop factoriohq
  msg_ok "Stopped Services"

  create_backup /opt/factoriohq/.env /opt/factoriohq/storage

  msg_info "Updating Application"
  cd /opt/factoriohq
  git pull
  RUBY_VERSION=$(tr -d ' \n' < /opt/factoriohq/.ruby-version)
  RUBY_VERSION="${RUBY_VERSION}" RUBY_INSTALL_RAILS="false" setup_ruby
  export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
  bundle config set --local without 'development test'
  bundle config set --local deployment 'true'
  bundle install
  RAILS_ENV=production bundle exec rails db:migrate
  msg_ok "Updated Application"

  restore_backup

  msg_info "Starting Services"
  systemctl start factoriohq
  msg_ok "Started Services"
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
