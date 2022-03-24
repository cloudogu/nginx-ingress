#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "                                     ./////,                    "
echo "                                 ./////==//////*                "
echo "                                ////.  ___   ////.              "
echo "                         ,**,. ////  ,////A,  */// ,**,.        "
echo "                    ,/////////////*  */////*  *////////////A    "
echo "                   ////'        \VA.   '|'   .///'       '///*  "
echo "                  *///  .*///*,         |         .*//*,   ///* "
echo "                  (///  (//////)**--_./////_----*//////)   ///) "
echo "                   V///   '°°°°      (/////)      °°°°'   ////  "
echo "                    V/////(////////\. '°°°' ./////////(///(/'   "
echo "                       'V/(/////////////////////////////V'      "

# Start nginx
echo "[nginx] starting nginx service..."
/nginx-ingress-controller \
  --publish-service="${POD_NAMESPACE}"/ingress-nginx-controller \
  --election-id=ingress-controller-leader \
  --controller-class=k8s.io/ingress-nginx \
  --ingress-class=k8s-ecosystem-ces-service \
  --configmap="${POD_NAMESPACE}"/ingress-nginx-controller \
  --validating-webhook=:8443 \
  --validating-webhook-certificate=/usr/local/certificates/cert \
  --validating-webhook-key=/usr/local/certificates/key \
  --default-ssl-certificate="${POD_NAMESPACE}"/ecosystem-certificate \
  --watch-namespace="${POD_NAMESPACE}"