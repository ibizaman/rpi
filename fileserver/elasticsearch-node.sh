#!/bin/bash

function arguments() {
    domain="$1"
    available_domains="$(ls -d ~/.password-store/mailgun.com/mg.* | xargs -n1 basename | cut -d '.' -f 2-)"
    if [ -z "$domain" ] || ! contains "$available_domains" "$domain"; then
        echo "$help_args DOMAIN ESHOST"
        echo "DOMAIN must be one of:"
        echo "$available_domains"
        exit 1
    fi
    shift

    eshost="$1"
    available_eshosts="$(ls ~/.password-store/tiserbox.com/elasticsearch/)"
    if [ -z "$eshost" ] || ! contains "$available_eshosts" "$eshost"; then
        echo "$help_args DOMAIN ESHOST"
        echo "ESHOST must be one of:"
        echo "$available_eshosts"
        exit 1
    fi
    shift

    es_api_key="$(get_or_create_pass "$domain/elasticsearch/$eshost/api_key")"
}

function install_remote() {
    pacman -Sy --needed --noconfirm \
           metricbeat \
           journalbeat \
           || exit 1

    cat <<METRICBEAT > /etc/metricbeat/metricbeat.yml
output.elasticsearch:
    hosts: ["$eshost:9201"]
    index: "metricbeat-%{[agent.hostname]}-%{[agent.version]}-%{+yyyy.MM.dd}"

setup.template:
    name: "metricbeat"
    pattern: "metricbeat-*"

metricbeat.config.modules:
    path: \${path.config}/modules.d/*.yml

logging:
    level: warning
    to_syslog: true
METRICBEAT

    rm /etc/metricbeat/modules.d/elasticsearch.yml.disabled
    cat <<METRICBEAT_ES > /etc/metricbeat/modules.d/elasticsearch.yml
- module: elasticsearch
  period: 10s
  hosts: ["http://127.0.0.1:9201"]
METRICBEAT_ES

    rm /etc/metricbeat/modules.d/haproxy.yml.disabled
    cat <<METRICBEAT_HAPROXY > /etc/metricbeat/modules.d/haproxy.yml
- module: haproxy
  period: 30s
  hosts: ["tcp://127.0.0.1:14567"]
METRICBEAT_HAPROXY

    rm /etc/metricbeat/modules.d/system.yml.disabled
    cat <<METRICBEAT_SYSTEM > /etc/metricbeat/modules.d/system.yml
- module: system
  period: 10s
  metricsets:
    - cpu
    - load
    - memory
    - network
    - process
    - process_summary
    - socket_summary
  process.include_top_n:
    by_cpu: 5      # include top 5 processes by CPU
    by_memory: 5   # include top 5 processes by memory
  process.cgroups.enabled: false
  core.metrics: [percentages]
  cpu.metrics: [percentages]

- module: system
  period: 1m
  metricsets:
    - filesystem
  processors:
  - drop_event.when.regexp:
      system.filesystem.mount_point: '^/(sys|cgroup|proc|dev|etc|host|lib)($|/)'

- module: system
  period: 15m
  metricsets:
    - uptime

- module: system
  metricsets: [socket]
  period: 1s
  socket.reverse_lookup.enabled: true
  socket.reverse_lookup.success_ttl: 60s
  socket.reverse_lookup.failure_ttl: 60s

- module: system
  period: 5m
  metricsets:
    - raid
  raid.mount_point: '/'
METRICBEAT_SYSTEM

    cat <<JOURNALBEAT > /etc/journalbeat/journalbeat.yml
journalbeat.inputs:
- paths: ["/var/log/journal"]
  seek: cursor

setup.template.settings:
  index.number_of_shards: 1

output.elasticsearch:
    hosts: ["$eshost:9201"]
    index: "journalbeat-%{[agent.hostname]}-%{[agent.version]}-%{+yyyy.MM.dd}"

setup.template:
    name: "journalbeat"
    pattern: "journalbeat-*"

logging:
    level: warning
    to_syslog: true
JOURNALBEAT

    systemctl daemon-reload

    systemctl reload-or-restart metricbeat
    systemctl enable metricbeat
    systemctl reload-or-restart journalbeat
    systemctl enable journalbeat
}

function install_local() {
    :
}
