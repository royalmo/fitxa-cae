# Fitxa CAE

Fitxa CAE is a Rails time registration app for operational teams. Employees use the mobile-friendly frontend at `/` to sign in, clock in/out, review clockings, request corrections when enabled, and manage account contact details. Managers use the operational frontend under `/admin` to review employees, corrections, and reports.

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

### Backups

Production backups have two layers:

- Production-local snapshots in `/home/deploy/fitxa-backups`.
- Home-server Borg backups on `mnr.ericroy.net` in `/mnt/bak1t1/fitxa-cae.compila.cat/borg/fitxa-production`.

Snapshots include the primary SQLite database, local Active Storage files, and
the runtime secret values needed to recreate `.kamal/secrets.*`. They
intentionally exclude Solid Queue, Solid Cache, and Solid Cable databases.

Retention:

```text
Every 6h: latest 8 snapshots
Daily: 7
Weekly: 4
Monthly: 12
Yearly: 10
```

Production-local snapshots are created by:

```sh
/home/deploy/fitxa-backups/bin/production_snapshot create
```

The scheduled job runs from `mnr.ericroy.net` root cron every 6 hours. It calls
the production snapshot script over a restricted SSH key, leaves a retained copy
on the production server, then stores the same snapshot in the home Borg
repository. The production `deploy` user does not currently have an independent
timer because user-systemd lingering is disabled on the production host.

List production-local snapshots:

```sh
ssh deploy@fitxa-cae.compila.cat '/home/deploy/fitxa-backups/bin/production_snapshot list'
```

List home Borg archives:

```sh
ssh mnr.ericroy.net 'sudo BORG_PASSCOMMAND="cat /root/.config/fitxa-cae-backups/borg-passphrase" borg list /mnt/bak1t1/fitxa-cae.compila.cat/borg/fitxa-production'
```

#### Restore The Current Production Host

Use this when the server is healthy but production data needs to roll back to a
recent snapshot.

SSH into the production host and choose a snapshot:

```sh
ssh deploy@fitxa-cae.compila.cat
snapshot="$(ls -1t /home/deploy/fitxa-backups/archives/sixhour/*.tar.gz | head -n 1)"
restore_dir="$(mktemp -d /home/deploy/fitxa-restore.XXXXXX)"
tar -xzf "$snapshot" -C "$restore_dir"
```

Stop both running app containers:

```sh
cae_container="$(docker ps --format '{{.Names}}' | grep -E '^fitxa_cae-web-fitxa-cae-' | head -n 1)"
xarranca_container="$(docker ps --format '{{.Names}}' | grep -E '^fitxa_xarranca-web-fitxa-xarranca-' | head -n 1)"
cae_image="$(docker inspect "$cae_container" --format '{{.Config.Image}}')"
xarranca_image="$(docker inspect "$xarranca_container" --format '{{.Config.Image}}')"
docker stop "$cae_container" "$xarranca_container"
```

Restore both storage volumes from the extracted snapshot:

```sh
docker run --rm \
  -v fitxa_cae_storage:/rails/storage \
  -v "$restore_dir/apps/fitxa-cae:/restore:ro" \
  "$cae_image" \
  sh -lc 'find /rails/storage -mindepth 1 ! -name "production*.sqlite3*" -exec rm -rf {} + &&
          cp /restore/databases/production.sqlite3 /rails/storage/production.sqlite3 &&
          cp -a /restore/storage/. /rails/storage/'

docker run --rm \
  -v fitxa_xarranca_storage:/rails/storage \
  -v "$restore_dir/apps/fitxa-xarranca:/restore:ro" \
  "$xarranca_image" \
  sh -lc 'find /rails/storage -mindepth 1 ! -name "production*.sqlite3*" -exec rm -rf {} + &&
          cp /restore/databases/production.sqlite3 /rails/storage/production.sqlite3 &&
          cp -a /restore/storage/. /rails/storage/'
```

Start the containers again:

```sh
docker start "$cae_container" "$xarranca_container"
```

For older snapshots, prefer restoring to a staging server first. A much older
database may not match the currently deployed code.

#### Restore From The Home Borg Backup

Use this when the production server or its local snapshots are gone.

On `mnr.ericroy.net`, extract the archive:

```sh
ssh mnr.ericroy.net
repo=/mnt/bak1t1/fitxa-cae.compila.cat/borg/fitxa-production
export BORG_PASSCOMMAND='cat /root/.config/fitxa-cae-backups/borg-passphrase'
sudo -E borg list "$repo"
archive=fitxa-production-YYYYmmddTHHMMSSZ
restore_dir=/tmp/fitxa-restore
sudo rm -rf "$restore_dir"
sudo mkdir -p "$restore_dir"
cd "$restore_dir"
sudo -E borg extract "$repo::$archive"
sudo chown -R "$USER:$USER" "$restore_dir"
```

Copy `/tmp/fitxa-restore` to the machine where you will run Kamal and to the
replacement host. The commands below assume it is available at that same path.

From a fresh clone of this repository, recreate the missing Kamal secrets:

```sh
mkdir -p .kamal
cp /tmp/fitxa-restore/apps/fitxa-cae/env/kamal_secrets.env .kamal/secrets.fitxa-cae
cp /tmp/fitxa-restore/apps/fitxa-xarranca/env/kamal_secrets.env .kamal/secrets.fitxa-xarranca
chmod 600 .kamal/secrets.fitxa-cae .kamal/secrets.fitxa-xarranca
```

Deploy to the replacement host:

```sh
bin/kamal setup -d fitxa-cae
bin/kamal setup -d fitxa-xarranca
```

Copy the restored data into the new Docker volumes. Run this on the replacement
host after `kamal setup` has created the volumes:

```sh
restore_dir=/tmp/fitxa-restore
cae_image="$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep 'fitxa_cae' | head -n 1)"

docker run --rm \
  -v fitxa_cae_storage:/rails/storage \
  -v "$restore_dir/apps/fitxa-cae:/restore:ro" \
  "$cae_image" \
  sh -lc 'find /rails/storage -mindepth 1 ! -name "production*.sqlite3*" -exec rm -rf {} + &&
          cp /restore/databases/production.sqlite3 /rails/storage/production.sqlite3 &&
          cp -a /restore/storage/. /rails/storage/'

docker run --rm \
  -v fitxa_xarranca_storage:/rails/storage \
  -v "$restore_dir/apps/fitxa-xarranca:/restore:ro" \
  "$cae_image" \
  sh -lc 'find /rails/storage -mindepth 1 ! -name "production*.sqlite3*" -exec rm -rf {} + &&
          cp /restore/databases/production.sqlite3 /rails/storage/production.sqlite3 &&
          cp -a /restore/storage/. /rails/storage/'
```

Then redeploy both destinations:

```sh
bin/kamal deploy -d fitxa-cae
bin/kamal deploy -d fitxa-xarranca
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
| Aina Martinez Vidal | `31007919D` | `1234` | Active, has email and phone, corrections enabled |
| Alexia Lopez Soler | `31015838Q` | `1234` | Active, has email and phone, corrections disabled |

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
- Enable or disable all users that have one tag.
