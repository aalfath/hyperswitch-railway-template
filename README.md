[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/hyperswitch?utm_medium=integration&utm_source=button&utm_campaign=hyperswitch)

# Hyperswitch on Railway

A Railway template for [Hyperswitch](https://github.com/juspay/hyperswitch), the open-source payments switch by Juspay (Apache-2.0). It deploys the payments API, the Control Center dashboard and the Web SDK, with Railway's Postgres and Redis.

| Service | Built from | Version |
|---|---|---|
| `router` (payments API, public) | `router/`: `juspaydotin/hyperswitch-router:v1.129.0-standalone@sha256:dbbc78845ac1c6dd3cdcc6bd00de11646351b37e2173cca5f32dd723a8021dea` | Hyperswitch v1.129.0 |
| `control-center` (dashboard, public) | `control-center/`: `juspaydotin/hyperswitch-control-center:v1.39.0@sha256:19a4c9c15b89865798b9730445cd5a1e84820896d6383c3eed97ad6e61ce18b0` | Control Center v1.39.0 |
| `web-sdk` (HyperLoader.js, public) | `web-sdk/`: `juspaydotin/hyperswitch-web:v0.135.0@sha256:e9188fc789f4fd81a2d99f0c28c1c8cdfc9b5c2940a5fac2bf4b1ef9dd35cbea`, served by `caddy:2.11.9-alpine` | Web SDK v0.135.0 |
| `Postgres` | Railway Postgres (volume) | |
| `Redis` | Railway Redis (volume) | |

The three app versions are the ones listed together in the [v1.129.0 release's compatibility matrix](https://github.com/juspay/hyperswitch/releases/tag/v1.129.0).

## What the wrapper does

- **router/**: runs the release's own database migrations (`diesel migration run` on the `migrations/` folder of tag `v1.129.0`) on every start, then starts the router as the image's unprivileged `app` user with the release's `config/docker_compose.toml`. Postgres and Redis come from Railway's variables. Uploaded files (dispute evidence, themes) are kept on a volume at `/local/bin/files`. There is no Superposition service: the router reads the release's bundled `superposition_seed.toml`, which holds the upstream defaults.
- **control-center/**: points the dashboard at this deployment's router and Web SDK URLs. Email features are off (no SMTP), so sign-up and sign-in use email and password.
- **web-sdk/**: builds the SDK with this deployment's router and SDK URLs baked in (Railway passes them as build arguments) and serves it with Caddy, with CORS open so any checkout page can load it.

## Variables

All generated or derived by the template; nothing to fill in.

| Service | Variable | Value |
|---|---|---|
| router | `ROUTER__SECRETS__ADMIN_API_KEY` | generated; admin API key (`Authorization: admin-api-key=...`) |
| router | `ROUTER__SECRETS__JWT_SECRET` | generated; signs dashboard sessions |
| router | `ROUTER__SECRETS__MASTER_ENC_KEY` | generated, 64 hex; encrypts merchant keys. **Back it up; without it the database can't be read.** |
| router | `ROUTER__API_KEYS__HASH_KEY` | generated, 64 hex; hashes API keys |
| router | `ROUTER__USER_AUTH_METHODS__ENCRYPTION_KEY` | generated, 64 hex |
| router | `ROUTER__PAYMENT_METHOD_AUTH__PM_AUTH_KEY`, `ROUTER__INTERNAL_MERCHANT_ID_PROFILE_ID_AUTH__PRIMARY_INTERNAL_API_KEY` | generated, replace the sample keys in the upstream config |
| router | `PG*`, `REDIS*` | references to the Postgres and Redis services |
| all | `HYPERSWITCH_PUBLIC_URL`, `CONTROL_CENTER_URL`, `SDK_URL` | the services' Railway domains |

Any other Hyperswitch setting can be set on the router as an environment variable: `ROUTER__<SECTION>__<KEY>` (for example `ROUTER__LOG__CONSOLE__LEVEL=DEBUG`).

## After deploy

1. Open the `control-center` URL and sign up. The first account creates your organization and becomes its admin. Anyone who can reach the URL can also sign up and get their own separate organization, so keep the URL private or put it behind access control if that matters to you.
2. In **Connectors**, add a processor. The built-in test processor (PhonyPay, `phonypay`) works with no outside account; real processors need their sandbox or live keys.
3. Create an API key in the Control Center and call the router's public URL, for example `POST https://YOUR-ROUTER-DOMAIN/payments` with header `api-key: YOUR-API-KEY`.
4. In your checkout page, load `https://YOUR-WEB-SDK-DOMAIN/web/0.135.0/v1/HyperLoader.js`.

This stack uses Hyperswitch's built-in mock card locker, so it suits evaluation, development and sandbox processing. Storing real card data needs the separate [Hyperswitch Card Vault](https://github.com/juspay/hyperswitch-card-vault) and your own PCI DSS work.

## Updates

Railway shows "update available" on your project when this repo's `main` branch changes (a version bump or a fix). Read [CHANGELOG.md](CHANGELOG.md) first, then apply the update from your Railway dashboard. The router runs any new database migrations on its next start. Back up Postgres and the `ROUTER__SECRETS__MASTER_ENC_KEY` value before a major upgrade.

## Local test

`docker compose -f test/compose.yml -p hyperswitch up -d --build` runs the same three services with Postgres and Redis on `localhost:42544` (router), `42545` (Control Center) and `42546` (Web SDK). It uses throwaway test keys; never use them for real data.

## License

Hyperswitch, its Control Center and Web SDK are Apache-2.0, by Juspay.
