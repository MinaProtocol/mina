#!/bin/bash

createdb archiver
psql -d archiver < create_schema.sql
