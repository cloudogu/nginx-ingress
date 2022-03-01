#!/bin/bash
set -o errexit
set -o nounset

includeCesConfig="include /etc/nginx/ces-config/*.conf;"

# shellcheck disable=SC2016
serverIncludesKey='{{ if not (empty $server.ServerSnippet) }}'

sed -i "/${serverIncludesKey}/i ${includeCesConfig}" /etc/nginx/template/nginx.tmpl