#!/bin/sh
set -o errexit
set -o nounset

includeCesConfig="include /etc/nginx/ces-config/*.conf;"
# shellcheck disable=SC2016
serverIncludesKey='{{ if not (empty $server.ServerSnippet) }}'

sed "/${serverIncludesKey}/i ${includeCesConfig}" /etc/nginx/template/nginx.tmpl | cat -n | grep -A 10 975