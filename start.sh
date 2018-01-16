#!/bin/bash
set -eo pipefail

exec psql --host db -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'airbnb'" | grep -q 1 || psql \
     --host db --username airbnb -tc "CREATE DATABASE airbnb"

exec psql --host db -U postgres -tc "SELECT 1 FROM pg_extension WHERE extname = 'postgis'" | grep -q 1 || psql \
     --host db --username postgres airbnb -tc "CREATE EXTENSION postgis;"

exec psql --host db --username postgres airbnb < postgresql/schema_current.sql

exec while true; do echo 'up and running' && sleep 30; done;
