# Docker Support for Feed Monitor Examples

The files in this directory let you run any generated example application in containers alongside Postgres and Redis. Mount the repository into the containers, point `APP_PATH` at your generated host app, and start the stack with Docker Compose.

## Prerequisites

- Docker Engine 24+
- Docker Compose v2
- A generated example app (e.g., using `examples/basic_host/template.rb`)

## Quick Start

1. Copy `.env.example` to `.env` and update `APP_PATH` so it points at your generated example directory (relative to the repository root). Example: `APP_PATH=/workspace/examples/feed_monitor_basic`.
2. From `examples/docker`, run `docker compose up --build`.
3. Visit <http://localhost:3000/feed_monitor> (basic/custom adapter) or <http://localhost:3000/operations/feed_monitor> (advanced).

The stack launches three Rails processes:

- `web` – Runs `bin/rails server` bound to `0.0.0.0:3000`.
- `worker` – Runs `bin/rails solid_queue:start`.
- `scheduler` – Runs `bin/jobs --recurring_schedule_file=config/recurring.yml`.

Services share a persistent bundle cache (`bundle` volume) and Postgres data directory (`postgres-data`). Redis stores realtime messages for the advanced example but remains optional for the basic and custom adapter templates.

## Custom Commands

The entrypoint script accepts the following commands:

- `web` (default)
- `worker`
- `scheduler`

To open a shell inside the web container:

```bash
docker compose run --rm web bash
```

## Troubleshooting

- Ensure `Gemfile.lock` exists under `APP_PATH`; the entrypoint checks for it and warns if it is missing.
- If `npm install` fails, add Node dependencies to your example app or remove `package.json`.
- Update `DATABASE_URL` / `REDIS_URL` in `.env` to match your infrastructure when deploying beyond local Compose.
