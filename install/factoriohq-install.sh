#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: ChatGPT
# License: MIT
# Source: https://github.com/behindcurtain3/factoriohq

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  curl \
  git \
  libssl-dev \
  libyaml-dev \
  pkg-config \
  sqlite3 \
  sqlite3 \
  zlib1g-dev
msg_ok "Installed Dependencies"

fetch_and_deploy_gh_release "factoriohq" "behindcurtain3/factoriohq" "tarball"

RUBY_VERSION="3.2.4" RUBY_INSTALL_RAILS="false" setup_ruby
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

msg_info "Installing Application Dependencies"
cd /opt/factoriohq
$STD bundle install
msg_ok "Installed Application Dependencies"

msg_info "Configuring FactorioHQ"
cp .env.example .env

FACTORIO_DATA_PATH="/opt/factoriohq/factorio-data"
mkdir -p "$FACTORIO_DATA_PATH"

if ! grep -q '^FACTORIO_DATA_PATH=' .env; then
  echo "FACTORIO_DATA_PATH=${FACTORIO_DATA_PATH}" >> .env
else
  sed -i "s|^FACTORIO_DATA_PATH=.*|FACTORIO_DATA_PATH=${FACTORIO_DATA_PATH}|" .env
fi

if ! grep -q '^RAILS_ENV=' .env; then
  echo "RAILS_ENV=production" >> .env
fi

chmod 640 .env
msg_ok "Configured FactorioHQ"

msg_info "Preparing Database"
$STD bundle exec rails db:create db:migrate
msg_ok "Prepared Database"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/factoriohq.service
[Unit]
Description=FactorioHQ
After=network.target

[Service]
Type=simple
User=845
Group=845
WorkingDirectory=/opt/factoriohq
EnvironmentFile=/opt/factoriohq/.env
Environment=PATH=/opt/factoriohq/.rbenv/shims:/opt/factoriohq/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/factoriohq/.rbenv/shims/bundle exec rails server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable -q --now factoriohq
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
