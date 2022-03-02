#!/bin/bash
set -o errexit
set -o nounset

# Inject custom configs into nginx
includeCesConfig="include /etc/nginx/ces-config/*.conf;"
# shellcheck disable=SC2016
serverIncludesKey='{{ if not (empty $server.ServerSnippet) }}'
sed -i "/${serverIncludesKey}/i ${includeCesConfig}" /etc/nginx/template/nginx.tmpl

# Inject custom values for ssl_protocols, ssl_session_cache, ssl_ciphers, and ssl_session_timeout
