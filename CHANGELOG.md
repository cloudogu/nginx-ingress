# Nginx Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.5.1-2] - 2023-02-10
### Changed
- [#17] Gzip proxied responses

## [v1.5.1-1] - 2023-02-08
### Changed
- [#15] Set `proxy_intercept_errors off;` so that dogus like bluespice work properly.
- Update ingress-nginx to 1.5.1

## [v1.3.0-3] - 2023-02-06
### Added
- [#13] Add namespaced permissions to get, create and update coordination.k8s.io/leases

## [v1.3.0-2] - 2022-11-28
### Changed
- [#11] Replace custom deployment definition with new service account definitions in the `dogu.json`.

## [v1.3.0-1] - 2022-08-24
### Changed
- [#9] Updated the nginx ingress controller to version 1.3.0. More information can be found [here](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.3.0)

### Removed
- [#9] Static content such as the ces-theme is no longer served by the ingress controller. The static content is generally outsourced to another webserver called [nginx-static](https://github.com/cloudogu/nginx-static)

## [v1.1.2-1] - 2022-06-21
### Changed
- Update make files to version 6.0.2
- Update make files to version 6.0.0
- Update make files to version 5.1.0

### Added 
Initial structure for the Nginx-Ingress Controller. This dogu is based on the official 
[Nginx-Ingress Controller](https://github.com/kubernetes/ingress-nginx/) provided by Kubernetes.