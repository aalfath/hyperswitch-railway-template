# Hyperswitch Web SDK (HyperLoader.js and the checkout iframe) for Railway.
# Official image, pinned by version and digest. v0.135.0 is the Web Client
# version listed in the Hyperswitch v1.129.0 release's compatibility matrix.
#
# The SDK bakes the router's URL and its own URL into the bundle, so it is built
# here with this deployment's URLs (Railway passes service variables as build args).
FROM juspaydotin/hyperswitch-web:v0.135.0@sha256:e9188fc789f4fd81a2d99f0c28c1c8cdfc9b5c2940a5fac2bf4b1ef9dd35cbea AS build

ARG HYPERSWITCH_PUBLIC_URL
ARG SDK_URL
WORKDIR /usr/src/app
RUN test -n "${HYPERSWITCH_PUBLIC_URL}" && test -n "${SDK_URL}" \
    && ENV_BACKEND_URL="${HYPERSWITCH_PUBLIC_URL%/}" ENV_SDK_URL="${SDK_URL%/}" \
       sdkEnv=sandbox NODE_ENV=production NODE_OPTIONS=--max-old-space-size=3072 \
       npx webpack --config webpack.common.js \
    && test -f dist/sandbox/v1/HyperLoader.js \
    && mkdir -p /out/web/0.135.0 \
    && cp -r dist/sandbox/v1 /out/web/0.135.0/v1

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0
COPY --from=build /out /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 8080
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
