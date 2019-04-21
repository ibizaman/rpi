#!/bin/bash

function arguments() {
    domain="$1"
    available_domains="$(ls -d ~/.password-store/mailgun.com/mg.* | xargs -n1 basename | cut -d '.' -f 2-)"
    if [ -z "$domain" ] || ! contains "$available_domains" "$domain"; then
        echo "$help_args DOMAIN"
        echo "DOMAIN must be one of:"
        echo "$available_domains"
        exit 1
    fi
    shift

    kb_pw_user="$(get_or_create_pass "$domain/kibana/$user")"
    es_api_key="$(get_or_create_pass "$domain/elasticsearch/$host/api_key")"
}

function install_remote() {
    pacman -Sy --needed --noconfirm \
           elasticsearch \
           kibana \
           metricbeat \
           journalbeat \
           || exit 1

    mkdir -p /var/lib/elasticseach
    chown elasticsearch: /var/lib/elasticsearch
    cat <<ELASTICSEARCH > /etc/elasticsearch/elasticsearch.yml
cluster.name: $domain
path.data: /var/lib/elasticsearch
http.port: 9201
ELASTICSEARCH

    cat <<EOF > /etc/default/elasticsearch
JAVA_HOME=/usr/lib/jvm/default-runtime

ES_BUNDLED_JDK=false
EOF

    cat <<KIBANA > /etc/kibana/kibana.yml
server:
    basePath:        /kibana
    rewriteBasePath: true
    host:            127.0.0.1
    port:            5602
    name:            $domain

logging.quiet: false

elasticsearch.hosts: ["http://127.0.0.1:9201"]
KIBANA

    cat <<METRICBEAT > /etc/metricbeat/metricbeat.yml
output.elasticsearch.hosts: ["http://127.0.0.1:9201"]

logging:
    level: warning
    to_syslog: true
METRICBEAT

    cat <<METRICBEAT_ES > /etc/metricbeat/modules.d/elasticsearch.yml
- module: elasticsearch
  period: 10s
  hosts: ["http://127.0.0.1:9201"]
METRICBEAT_ES

    cat <<METRICBEAT_HAPROXY > /etc/metricbeat/modules.d/haproxy.yml
- module: haproxy
  period: 30s
  hosts: ["tcp://127.0.0.1:14567"]
METRICBEAT_HAPROXY

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

output.elasticsearch.hosts: ["http://127.0.0.1:9201"]

logging:
    level: warning
    to_syslog: true
JOURNALBEAT

    cat <<HAPROXY > /etc/haproxy/configs/40-elasticsearch.cfg
userlist ESUsersAuth
    group elasticsearch users api

    user api insecure-password "$es_api_key"

frontend elasticsearch
    mode http

    bind *:9200 ssl crt /etc/ssl/my_cert/
    reqadd X-Forwarded-Proto:\ https

    default_backend elasticsearch

backend elasticsearch
    mode http

    option forwardfor

    acl AuthOkay_ESUsersAuth http_auth(ESUsersAuth)
    http-request auth realm UserAuth if !AuthOkay_ESUsersAuth

    server elasticsearch1 127.0.0.1:9201
HAPROXY

    cat <<HAPROXY > /etc/haproxy/configs/40-elasticsearch-kibana.cfg
userlist KibanaUsersAuth
    group kibana users timi

    user timi insecure-password "$kb_pw_user"

frontend kibana
    mode http

    bind *:443 ssl crt /etc/ssl/my_cert/
    reqadd X-Forwarded-Proto:\ https

    acl acl_kibana path_beg /kibana
    use_backend kibana if acl_kibana

backend kibana
    mode http

    option forwardfor

    acl AuthOkay_KibanaUsersAuth http_auth(KibanaUsersAuth)
    http-request auth realm UserAuth if !AuthOkay_KibanaUsersAuth
    reqrep ^([^\ :]*)\ /kibana/(.*) \1\ /\2

    server kibana1 127.0.0.1:5602
HAPROXY

    systemctl daemon-reload

    systemctl reload-or-restart haproxy
    systemctl reload-or-restart elasticsearch
    systemctl enable elasticsearch
    systemctl reload-or-restart kibana
    systemctl enable kibana
    systemctl reload-or-restart metricbeat
    systemctl enable metricbeat
    systemctl reload-or-restart journalbeat
    systemctl enable journalbeat

    upnpport configure /etc/upnpport/upnpport.yaml add 9200
    systemctl reload upnpport
}

function install_local() {
    :
}
