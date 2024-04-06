#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "i-caprover" "Installs caprover and prepares the one-click-app template for our postgres DB."
fn_arg_parse "$@"

fn_fail_on_used_port 80

# expose the ports that caprover will need
ufw allow 80,443,3000,996,7946,4789,2377/tcp
ufw allow 7946,4789,2377/udp
# for postgres
ufw allow 5432/tcp

# run the docker container that will setup caprover
docker run -p 80:80 -p 443:443 -p 3000:3000 -e ACCEPTED_TERMS=true -v /var/run/docker.sock:/var/run/docker.sock -v /captain:/captain caprover/caprover

# install caprover CLI
. /root/.bashrc
npm install --global caprover
. /root/.bashrc

log.info "Waiting 50 seconds for caprover server to start..."
for _ in {50..1}; do
  sleep 1
done

caprover serversetup -y -e "$runtime_caprover_email" -w "$secret_caprover_password" -r "$runtime_caprover_root_domain" -n "$runtime_caprover_name" -i "$secret_remote_ip"
#
# Setup any one-click app templates.
# The installation script is responsible for pulling down the templates and
# setting up the remaining configuration on the caprover server.
#
database_json=$(
  cat <<EOF
{
  "captainVersion": 4,
  "services": {
    "\$\$cap_appname": {
      "image": "postgres:14.5",
      "ports": [
        "5432:5432"
      ],
      "volumes": [
        "\$\$cap_appname-data:/var/lib/postgresql/data"
      ],
      "restart": "always",
      "environment": {
        "POSTGRES_USER": "${runtime_postgres_user}",
        "POSTGRES_PASSWORD": "${secret_postgres_password}",
        "POSTGRES_DB": "${runtime_postgres_db}",
        "POSTGRES_INITDB_ARGS": null
      },
      "caproverExtra": {
        "containerHttpPort": 5432
      }
    }
  },
  "caproverOneClickApp": {
    "variables": [],
    "instructions": {
      "start": "PostgreSQL, often simply Postgres, is an object-relational database management system (ORDBMS) with an emphasis on extensibility and standards-compliance.\nAs a database server, its primary function is to store data, securely and supporting best practices, and retrieve it later, as requested by other software applications, be it those on the same computer or those running on another computer across a network (including the Internet).\nIt can handle workloads ranging from small single-machine applications to large Internet-facing applications with many concurrent users.",
      "end": "Postgres is deployed and available as \`srv-captain--database-dev:5432\` to other apps."
    },
    "displayName": "PostgreSQL",
    "isOfficial": true,
    "description": "The PostgreSQL object-relational database system provides reliability and data integrity",
    "documentation": "https://github.com/interbolt/solos"
  }
}
EOF
)
echo "$database_json" >"$repo_dir/.secret.database.json"
