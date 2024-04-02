#!/usr/bin/env bash


# shellcheck source=../scripts/lib/defaults.sh
source ../scripts/lib/defaults.sh
# shellcheck source=../scripts/lib/runtime.sh
source ../scripts/lib/runtime.sh --expected-host local

echo "postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$runtime_postgres_db"
status=$(psql "postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$runtime_postgres_db" -c "SELECT 1" || echo "NOT_READY")
if [ "$status" == "NOT_READY" ]; then
  echo "Postgres is not ready. Please make sure the caprover postgres app is running and the .env and .secrets/postgres files are correctly setup."
  exit 1
fi
connection_uri="postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$runtime_postgres_db"
remote_dbs=$(psql "$connection_uri" -q -A -t -c "SELECT datname FROM pg_database")
rm -f "$runtime_secrets_dir/db_connection_*"
for remote_db in $remote_dbs; do
  if [ "$remote_db" != "$runtime_postgres_db" ]; then
    if [ "$remote_db" != "postgres" ] && [ "$remote_db" != "template0" ] && [ "$remote_db" != "template1" ]; then
      echo "Dropping postgres DB: $remote_db"
      psql "$connection_uri" -c "DROP DATABASE $remote_db"
    fi
  fi
done
