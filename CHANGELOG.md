# Nginx Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- [#47] add "use-forwarded-headers" option to ensure cas gets the correct request headers

## [v1.12.1-3] - 2025-08-20
### Changed
- [#45] Adjust configuration for snippet annotations to enable redirection of alternative fqdns.

## [v1.12.1-2] - 2025-04-23
### Changed
- [#43] Set sensible resource requests and limits

## [v1.12.1-1] - 2025-04-03
### Changed
- Upgrade to nginx-ingress 1.12.1; #41
- Upgrade to latest ces-build-lib, dogu-build-lib and Makefiles

## [v1.11.1-4] - 2024-12-10
### Fixed
- [#38] Fix showing the warp-menu in all dogus
  - The problem only occurred for dogus which send gzipped-responses
  - This is fixed by adding a `Accept-Encoding: "identity"`-header to the proxy-request
  - The response is then gzipped by the nginx

## [v1.11.1-3] - 2024-09-18
### Changed
- Relicense to AGPL-3.0-only

## [v1.11.1-2] - 2024-09-04
### Fixed
- [#34] Fix problems with content security policies (CSP) caused by whitelabeling

## [v1.11.1-1] - 2024-08-14
- [#30] Update ingress-nginx to 1.11.1

## [v1.6.4-6] - 2024-08-13
### Changed
- [#32] Include whitelabeling-styles in html-<head> instead of html-<body> 

## [v1.6.4-5] - 2024-08-06
### Added
- [#28] Default CSS Styles and Whitelabeling CSS Styles are being loaded now
    - similarly to the already existing warp-menu script and styles

## [v1.6.4-4] - 2023-10-27
### Fixed
- Fixed CVE-2023-38545

## [v1.6.4-3] - 2023-06-27
### Added
- [#24] Configuration options for resource requirements
- [#24] Defaults for CPU and memory requests

## [v1.6.4-2] - 2023-06-05
### Added
- [#22] Added configmaps `tcp-services` and `udp-services` to provide the possibility to expose those.

## [v1.6.4-1] - 2023-05-09
### Changed
- [#20] Use registry.k8s.io 
- Update ingress-nginx to 1.6.4

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
