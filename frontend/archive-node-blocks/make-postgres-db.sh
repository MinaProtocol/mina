#!/bin/bash

createdb archive
psql -d archive < create_schema.sql

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'foobar';"


