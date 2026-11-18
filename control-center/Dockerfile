# Hyperswitch Control Center (dashboard) for Railway.
# Official image, pinned by version and digest. v1.39.0 is the Control Center
# version listed in the Hyperswitch v1.129.0 release's compatibility matrix.
FROM juspaydotin/hyperswitch-control-center:v1.39.0@sha256:19a4c9c15b89865798b9730445cd5a1e84820896d6383c3eed97ad6e61ce18b0

COPY --chmod=0755 start.sh /usr/local/bin/control-center-start
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/control-center-start"]
