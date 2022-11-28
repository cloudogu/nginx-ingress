# Nginx Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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