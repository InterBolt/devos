# DevOS - My personal debian-based PAAS

## Installation

Install `devos` to your path:

```shell
curl -H 'Cache-Control: no-cache' -s "https://raw.githubusercontent.com/InterBolt/devos/main/installer/bin/install" | bash
```

Get usage info:

```
devos --help
```

## Recipes

TODO

## Scripts

The following aliased scripts are available in this repository:

```
g-review: Review a file using OpenAI's GPT-4

Required Arguments:
-f,--filepath <string>. The file to review

Optional Arguments:
-m,--model <string>. OpenAI model (Default "gpt-4")
-s,--specialty <string>. A specialty to refine the system prompt. (eg. nextjs, vscode, etc)
-c,--context-file <string>. A file whose contents we append to the user message.
```

```
h-alias: Build alias commands and save them into the .bashrc file
```

```
h-build: Builds a repo using the specified strategy.

Required Arguments:
-r,--repo-dir <string>. The repo to deploy

Optional Arguments:
-s,--strategy <string>. The deployment strategy (Default "node/pnpm")
```

```
h-create: Automates the creation of a new hook script.

Required Arguments:
-n,--name <string>. The name of the hook script.
```

```
h-deploy: Deploys a built repository from an app directory to a caprover server via a tar file.

Required Arguments:
-r,--app-dir <string>. The output folder for a build that also contains any app specific env files.
-d,--dist-dir <string>. The dir of distribution files generated via the build script
```

```
h-docs: Generates inline comments for copilot and README.md documentation.
```

```
h-pg-dump: Creates and (by default) uploads a dump of a postgres db to a vultr S3 bucket.

Optional Arguments:
-d,--database <string>. The output folder for a build that also contains any app specific env files.
-l,--local-only <string>. If set, the dump will not be uploaded to the vultr s3 bucket. (Default "false")
```

```
h-pg-expire-backups: Retires any backups older than 30 days from the vultr s3 bucket.
```

```
h-pg-register-db: Create a new DB for an app.

Required Arguments:
-a,--app-db <string>. The name of the new database to create. It must be prefixed with app_.
```

```
h-pg-restore: Restores the given backup file to the postgres database.

Required Arguments:
-b,--backup-file-name <string>. The name of the backup file to restore.

Optional Arguments:
-d,--target-database <string>. The name of the database to restore the backup to.
-u,--unsafe <string>. If provided, the script will not create a backup of the current db before restoring the backup. (Default "false")
```

```
h-pg-sync-down: Syncs backups on vultr to the local machine.
```

```
h-pg-sync-up: Uploads any unsynced backups from this local machine to vultr.
```

```
h-print-secrets: Prints the contents of the .secrets directory.
```

```
h-psql: Safe way to invoke psql against a deployed DB.

Required Arguments:
-c,--command <string>. The command to run against the database.

Optional Arguments:
-d,--target-database <string>. The name of the database to connect to.
-f,--psql-flags <string>. The flags to pass to psql.
```

```
h-rsync-logs: Download logs from the remote machine to the local machine.
```

```
h-rsync-secrets: Syncs secrets between the local and remote machine.
```

```
h-tests: Runs tests on scripts that include __test__ in their names.
```

```
i-apps: Install the apps listed in apps.txt on the remote server.
```

```
i-caprover: Installs caprover and prepares the one-click-app template for our postgres DB.
```

```
i-clone-repos: Clones orginization's repos.
```

```
i-docker: Installs Docker.
```

```
i-node: Installs NodeJS and related tooling.
```

```
i-postgres: Installs postgres client and sets up the local database with the latest backup from the caprover postgres app.
```

```
i-webmin: Installs Webmin.
```

