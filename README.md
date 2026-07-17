# Fitxa CAE

Fitxa CAE is a Rails time registration app for operational teams. Employees use the mobile-friendly frontend at `/` to sign in, clock in/out, review clockings, request corrections, and manage account contact details. Managers use the operational frontend under `/admin` to review employees, corrections, and reports.

The default UI locale is Catalan and the app timezone is `Europe/Madrid`.

## Stack

- Ruby from `.ruby-version`
- Rails 8.1.3
- SQLite databases stored in `storage/`
- Hotwire, Importmap, Stimulus, Turbo, ERB, Propshaft
- Solid Cache, Solid Queue, and Solid Cable
- Puma and Thruster for production serving
- Docker and Kamal deployment files are included

No Node/npm install is required for the current frontend.

## Main Routes

- Employee app: `http://localhost:3000/`
- Employee login: `http://localhost:3000/login`
- Manager/admin app: `http://localhost:3000/admin`
- Manager login: `http://localhost:3000/admin/login`
- Health check: `http://localhost:3000/up`
- PWA files: `/manifest` and `/service-worker`

Admin pages are intentionally kept under `/admin` and are not cached by the service worker.

## Development Setup

Install system dependencies first:

- Ruby matching `.ruby-version`
- Bundler
- SQLite 3
- libvips
- Build tools needed for native gems

On Debian/Ubuntu, the system packages are typically:

```sh
sudo apt install build-essential git libvips sqlite3
```

Then install and prepare the app:

```sh
bundle install
bin/rails db:prepare
```

For a fresh deterministic demo database:

```sh
bin/rails db:seed:replant
```

You can also use the project setup script:

```sh
bin/setup --skip-server
```

To reset the database while running setup:

```sh
bin/setup --reset --skip-server
```

## Run In Development

Start the Rails server:

```sh
bin/dev
```

The app will run on `http://localhost:3000` by default. To use a different port:

```sh
bin/dev -p 3001
```

Useful development commands:

```sh
bin/rails console
bin/rails db:migrate
bin/rails db:seed:replant
bin/rails routes
```

## Tests And Checks

Run the Rails tests:

```sh
bin/rails test
```

Run the full local CI pipeline:

```sh
bin/ci
```

`bin/ci` runs setup, RuboCop, Bundler audit, Importmap audit, Brakeman, the Rails test suite, and a seed replant check in the test environment.

## Seed Data

`db/seeds.rb` creates deterministic demo data:

- 70 employees
- 4 managers
- 3 tags: `office`, `wharehouse`, `off-shore`
- Recent clockings and correction requests

The seed task deletes and recreates the main demo records, so do not run `db:seed:replant` against real production data.

## Default Employee Credentials

Seeded employees log in at `/login` with `DNI/NIE` plus password when the employee has a password.

Most active seeded employees whose index is not divisible by 5 have this password:

```text
1234
```

Good password-login examples:

| User | DNI/NIE | Password | Notes |
| --- | --- | --- | --- |
| Aina Martinez Vidal | `31007919D` | `1234` | Active, has email and phone |
| Alexia Lopez Soler | `31015838Q` | `1234` | Active, has email and phone |

Useful edge-case employees:

| User | DNI/NIE | Password | Notes |
| --- | --- | --- | --- |
| Carla Rodriguez Serra | `31039595Z` | None | Active, code-login only, has email and phone |
| Sonia Costa Grau | `31475140P` | None | Inactive |
| Tomas Puig Miro | `31483059S` | `1234` | Inactive, useful for rejected-login tests |

SMS code login is mocked unless `SMSARENA_ENABLED=true`. In development, request an SMS code and read the generated code in the Rails log.

## Default Manager Records

Manager records are seeded with these emails:

| Manager | Email | Seeded password |
| --- | --- | --- |
| Laia Riera | `laia.riera@fitxa-cae.test` | `12345678` |
| Marc Soler | `marc.soler@fitxa-cae.test` | `12345678` |
| Nuria Costa | `nuria.costa@fitxa-cae.test` | `12345678` |
| Pau Vidal | `pau.vidal@fitxa-cae.test` | `12345678` |

Managers sign in at `/admin/login` with email and password. Admin pages under `/admin` redirect to the manager login page unless `session[:manager_id]` belongs to an active manager.

## Production Configuration

Required production configuration:

- `RAILS_MASTER_KEY`, or a readable `config/master.key`
- Persistent storage for `storage/`, because production SQLite databases and local uploads live there
- A real host configured in `config/environments/production.rb` when deploying behind a domain
- SSL settings enabled in `config/environments/production.rb` when the app is served over HTTPS
- Backups for the production SQLite files in `storage/`

Optional SMSArena environment variables:

- `SMSARENA_ENABLED=true`
- `SMSARENA_API_URL`
- `SMSARENA_AUTH_MODE`, one of `params`, `basic`, or `bearer`
- `SMSARENA_API_KEY`
- `SMSARENA_USERNAME`
- `SMSARENA_PASSWORD`
- `SMSARENA_SENDER`

Email login codes require production mailer delivery settings before they can be used reliably outside development/test.

## Run In Production With Docker

Build the production image:

```sh
docker build -t fitxa_cae .
```

Create a persistent storage volume:

```sh
docker volume create fitxa_cae_storage
```

Run the container:

```sh
docker run -d \
  --name fitxa_cae \
  -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -v fitxa_cae_storage:/rails/storage \
  fitxa_cae
```

The Docker entrypoint runs `bin/rails db:prepare` before starting the server. To load demo seed data into a disposable production-like container:

```sh
docker exec fitxa_cae ./bin/rails db:seed
```

Do not seed demo data into a real production database unless that is intentional.

## Run In Production Without Docker

Install gems without development/test dependencies:

```sh
bundle config set without "development test"
bundle install
```

Prepare the database and assets:

```sh
RAILS_ENV=production RAILS_MASTER_KEY="$(cat config/master.key)" bin/rails db:prepare
RAILS_ENV=production RAILS_MASTER_KEY="$(cat config/master.key)" bin/rails assets:precompile
```

Start the production server:

```sh
RAILS_ENV=production \
RAILS_MASTER_KEY="$(cat config/master.key)" \
bin/thrust bin/rails server -b 0.0.0.0 -p 3000
```

Use a process manager and a reverse proxy for a real server deployment.

## Deploy With Kamal

`config/deploy.yml` is present but still contains placeholder values such as `192.168.0.1` and `localhost:5555`.

Before deploying:

1. Set the real server host under `servers.web`.
2. Set the image name and registry.
3. Put `RAILS_MASTER_KEY` in `.kamal/secrets`.
4. Confirm the persistent `fitxa_cae_storage:/rails/storage` volume is appropriate for the target server.
5. Keep the Dockerfile `RUBY_VERSION` build argument aligned with `.ruby-version`.

First deploy:

```sh
bin/kamal setup
```

Later deploys:

```sh
bin/kamal deploy
```

Useful Kamal commands:

```sh
bin/kamal logs
bin/kamal console
bin/kamal shell
```

## Data And Backups

Development database:

```text
storage/development.sqlite3
```

Production databases:

```text
storage/production.sqlite3
storage/production_cache.sqlite3
storage/production_queue.sqlite3
storage/production_cable.sqlite3
```

Back up the full `storage/` directory in production, including Active Storage files and SQLite databases.
