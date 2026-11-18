#!/bin/sh
# Points the dashboard at this deployment's router and Web SDK, then starts the
# upstream server (node dist/server/server.js, port 9000, health check /health).
set -eu

if [ -z "${HYPERSWITCH_PUBLIC_URL:-}" ]; then
  echo "control-center-start: HYPERSWITCH_PUBLIC_URL (the router's public URL) is required" >&2
  exit 1
fi
export default__endpoints__api_url="${default__endpoints__api_url:-${HYPERSWITCH_PUBLIC_URL%/}}"
if [ -n "${SDK_URL:-}" ]; then
  export default__endpoints__sdk_url="${default__endpoints__sdk_url:-${SDK_URL%/}/web/${HYPERSWITCH_WEB_VERSION:-0.135.0}/v1/HyperLoader.js}"
fi
# No SMTP in this template: sign-up and sign-in work with email and password.
export default__features__email="${default__features__email:-false}"

cd /usr/src/app
exec node dist/server/server.js
