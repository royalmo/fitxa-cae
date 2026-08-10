# Fitxa CAE

Fitxa CAE is a Rails time registration app for operational teams. Employees use the mobile-friendly frontend at `/` to sign in, clock in/out, review clockings, request corrections, and manage account contact details. Managers use the operational frontend under `/admin` to review employees, corrections, and reports.

## Production Configuration

Two Kamal destinations are configured:

- `fitxa-cae`, serving `fitxa.cae.cat`
- `fitxa-xarranca`, serving `fitxa-xarranca.cae.cat`

Deploy:

```sh
bin/kamal deploy -d fitxa-cae
bin/kamal deploy -d fitxa-xarranca
```

Useful Kamal commands:

```sh
bin/kamal logs -d fitxa-cae
bin/kamal console -d fitxa-cae
bin/kamal shell -d fitxa-cae
```

### Deploy to a new server

1. Create `.kamal/secrets.prod-environment`, copying an example and adapting and filling credentials.
2. Create `config/deploy.prod-environment.yml`, also following some examples of the other sites.
   That server should be accessible with docker and git installed.
3. Ensure you make backups to the docker volume you create.

Finally, deploy and create the first production manager from the command line:

```sh
bin/kamal deploy -d prod-environment
bin/kamal app exec -d prod-environment --reuse "bin/rails managers:create_first EMAIL=admin@example.com FIRST_NAME=Nom LAST_NAME=Cognoms"
```

## Development Setup

```sh
sudo apt install build-essential git libvips sqlite3
cd /path/to/this/repo
bundle install
bin/rails db:prepare
bin/rails db:seed:replant
# start the server with `bin/dev` so generated Sass assets are built first
# test the app with `rails test` or `bin/ci`
```

For local brand switching, `bin/dev` loads an ignored `.env` file from the repo root before booting Rails. Keep one block active and restart `bin/dev`:

```sh
APP_NAME=FitxaCAE
APP_SLUG=fitxa-cae
APP_BRAND_SUFFIX_IMAGE=cae_logo_trimmed.png
APP_FAVICON=
APP_ICON_PNG=
APP_ICON_SVG=

# APP_NAME=FitxaXarranca
# APP_SLUG=fitxa-xarranca
# APP_BRAND_SUFFIX_IMAGE=
# APP_FAVICON=fitxa_xarranca_favicon.ico
# APP_ICON_PNG=fitxa_xarranca_icon.png
# APP_ICON_SVG=fitxa_xarranca_icon.svg
```

### Seed Data

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

Manager records are seeded with these emails:

| Manager | Email | Seeded password |
| --- | --- | --- |
| Laia Riera | `laia.riera@fitxa-cae.test` | `12345678` |
| Marc Soler | `marc.soler@fitxa-cae.test` | `12345678` |
| Nuria Costa | `nuria.costa@fitxa-cae.test` | `12345678` |
| Pau Vidal | `pau.vidal@fitxa-cae.test` | `12345678` |

## Possible improvements

Below is a list of things I find interesting to do but am lazy to do for free
(even though some are just one prompt lmao):

- Add some history on TagUser: when a user had and lost a tag.
- Shift+click to certain buttons auto-confirm the confirm modal that should appear.
- Notify the user at the end of the day if they have odd swipes.
- Managers can have roles (auditor, admin, ...) and they can be scoped to users
  with a certain tag.
- Put a moving average on charts, and maybe use the metric of people that worked that day.
- Review performance with a miniprofiler
- Receive a mail for slow requests.
- Be able to delete (manually-triggered) information older than X years. This is
  a legal requirement but I still have some years to implement it!
- Be able to undo recently approved or rejected corrections.
- Be able to change the app's primary color.
- Translate to english (and maybe spanish), put a language selector, and make
  the default language and timezone env-switchable (for future deployments).
