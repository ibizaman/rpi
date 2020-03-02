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
           || exit 1

    mkdir -p /var/lib/elasticseach
    chown elasticsearch: /var/lib/elasticsearch
    cat <<ELASTICSEARCH > /etc/elasticsearch/elasticsearch.yml
cluster.name: $domain
discovery.type: single-node
path.data: /var/lib/elasticsearch
http.port: 9201
network.host: [_local_, _site_]
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

    cat <<HAPROXY > /etc/haproxy/configs/40-elasticsearch.cfg
userlist ESUsersAuth
    group elasticsearch users api

    user api insecure-password "$es_api_key"

frontend elasticsearch
    mode http

    bind *:9200 ssl crt /etc/ssl/my_cert/
    http-request add-header X-Forwarded-Proto https

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
    http-request add-header X-Forwarded-Proto https

    acl acl_kibana path_beg /kibana
    use_backend kibana if acl_kibana

backend kibana
    mode http

    option forwardfor

    acl AuthOkay_KibanaUsersAuth http_auth(KibanaUsersAuth)
    http-request auth realm UserAuth if !AuthOkay_KibanaUsersAuth
    http-request replace-path ^([^\ :]*)\ /kibana/(.*) \1\ /\2

    server kibana1 127.0.0.1:5602
HAPROXY

    cat <<EOF > /usr/local/bin/clean-elasticsearch.sh
#!/bin/bash

function dates {
    curl --silent http://localhost:9201/_cat/indices | \\
        grep -e "\$1" | \\
        cut -f3 -d' ' | \\
        cut --output-delimiter=' ' -f1- -d '-' | \\
        sort -n -k4
}

function keep {
    head -n -\$1
}

function del {
    while IFS= read -r data; do
        index=\$(echo "\$data" | cut --output-delimiter='-' -f1- -d ' ')
        echo deleting "\$index"
        curl -XDELETE http://localhost:9201/"\$index"
    done
}

dates metricbeat-arsenic | keep 5 | del
dates metricbeat-timusic | keep 5 | del

dates journalbeat-arsenic | keep 5 | del
dates journalbeat-timusic | keep 5 | del
EOF
    chmod a+x /usr/local/bin/clean-elasticsearch.sh
    part="/usr/local/bin/clean-elasticsearch.sh"
    line="@ 1d /usr/local/bin/clean-elasticsearch.sh"
    if ! fcrontab -l 2>/dev/null | grep -q "$part"; then
        (fcrontab -l; echo "$line") | fcrontab -
    fi

    fcrondyn -x ls | grep "$part" | cut -d ' ' -f 1 | xargs -I . fcrondyn -x "runnow ."

    systemctl daemon-reload

    systemctl reload-or-restart haproxy
    systemctl reload-or-restart elasticsearch
    systemctl enable elasticsearch
    systemctl reload-or-restart kibana
    systemctl enable kibana

    upnpport configure /etc/upnpport/upnpport.yaml add 9200
    systemctl reload upnpport
}

function install_local() {
    :
}
