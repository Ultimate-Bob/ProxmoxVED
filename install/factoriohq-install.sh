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
  openssl \
  pkg-config \
  sqlite3 \
  zlib1g-dev
msg_ok "Installed Dependencies"

setup_docker

msg_info "Creating FactorioHQ User"

if ! getent group 845 >/dev/null; then
  groupadd --system --gid 845 factoriohq
fi

if ! getent passwd 845 >/dev/null; then
  useradd \
    --system \
    --uid 845 \
    --gid 845 \
    --home-dir /opt/factoriohq \
    --no-create-home \
    --shell /usr/sbin/nologin \
    factoriohq
fi

usermod -aG docker factoriohq

msg_ok "Created FactorioHQ User"

msg_info "Downloading FactorioHQ"
git clone https://github.com/behindcurtain3/factoriohq.git /opt/factoriohq
msg_ok "Downloaded FactorioHQ"

cd /opt/factoriohq

if [[ ! -f .ruby-version ]]; then
  msg_error "No .ruby-version file found in FactorioHQ source!"
  exit 1
fi

RUBY_VERSION="$(tr -d ' \n' < .ruby-version)"
RUBY_VERSION="${RUBY_VERSION#ruby-}"

export HOME=/opt/factoriohq
RUBY_INSTALL_RAILS="false" setup_ruby

export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

msg_info "Installing Application Dependencies"

# This needs to be installed in debug mode, so just ignore the following bundle config lines
# bundle config set --local without 'development test'
# bundle config set --local deployment 'true'
$STD bundle install

msg_ok "Installed Application Dependencies"

msg_info "Configuring FactorioHQ"

cp .env.example .env

FACTORIO_DATA_PATH="/opt/factoriohq/factorio-data"
mkdir -p "$FACTORIO_DATA_PATH"

if grep -q '^FACTORIO_DATA_PATH=' .env; then
  sed -i "s|^FACTORIO_DATA_PATH=.*|FACTORIO_DATA_PATH=${FACTORIO_DATA_PATH}|" .env
else
  echo "FACTORIO_DATA_PATH=${FACTORIO_DATA_PATH}" >> .env
fi

if grep -q '^RAILS_ENV=' .env; then
  sed -i 's|^RAILS_ENV=.*|RAILS_ENV=production|' .env
else
  echo "RAILS_ENV=production" >> .env
fi

if ! grep -q '^SECRET_KEY_BASE=' .env; then
  echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
fi

chmod 640 .env

msg_ok "Configured FactorioHQ"

msg_info "Setting File Permissions"
chown -R 845:845 /opt/factoriohq
chown -R root:root /opt/factoriohq/.rbenv
chmod 640 /opt/factoriohq/.env
msg_ok "Set File Permissions"

msg_info "Preparing Database"
# $STD env RAILS_ENV=production bundle exec rails db:create db:migrate
# does the same as above but as the factoriohq user
$STD runuser -u factoriohq -- env \
  HOME=/opt/factoriohq \
  PATH=/opt/factoriohq/.rbenv/shims:/opt/factoriohq/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  RAILS_ENV=production \
  bundle exec rails db:create db:migrate

msg_ok "Prepared Database"

msg_info "Creating Service"

cat <<EOF >/etc/systemd/system/factoriohq.service
[Unit]
Description=FactorioHQ
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=factoriohq
Group=factoriohq
SupplementaryGroups=docker
WorkingDirectory=/opt/factoriohq
EnvironmentFile=/opt/factoriohq/.env
Environment=HOME=/opt/factoriohq
Environment=RAILS_ENV=production
Environment=PATH=/opt/factoriohq/.rbenv/shims:/opt/factoriohq/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/factoriohq/.rbenv/shims/bundle exec rails server -b 0.0.0.0 -p 3000
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