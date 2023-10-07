#!/bin/bash

TOKEN="bkua_1502ef5a64ee3f5517cb5caae3dfc310c8a0c0b6"

RESPONSE_JSON=$(curl -H "Authorization: Bearer $TOKEN" "https://api.buildkite.com/v2/builds")


psql -c "INSERT INTO table_name (column1, column2, column3) VALUES (value1, value2, value3);" mydatabase myusername

