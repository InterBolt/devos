#!/bin/bash

SOURCE_MIGRATIONS_DIR="${HOME}/.solos/src/migrations"

for migration_file in "${SOURCE_MIGRATIONS_DIR}"/*; do
  echo "Migration file: ${migration_file}"
done
