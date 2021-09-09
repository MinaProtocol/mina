SOURCE_INTROSPECTION_FILE_PATH=$CODA_DIRECTORY_PATH/src/app/archive/archive_graphql_schema.json
GENERTATED_INTROSPECTION_FILE_PATH=$CODA_DIRECTORY_PATH/scripts/archive/output/graphql_schema.json

SOURCE_INTROSPECTION_CONTENTS=$(cat $SOURCE_INTROSPECTION_FILE_PATH)

GENERTATED_INTROSPECTION_CONTENTS=$(cat $GENERTATED_INTROSPECTION_FILE_PATH)

if [ "$SOURCE_INTROSPECTION_CONTENTS" == "$GENERTATED_INTROSPECTION_CONTENTS" ]; then 
    echo "Introspection file in source match with Hasura's generated introspection file"
else
    echo "Introspection file in source does not match with Hasura's generated introspection file";
    echo "Make sure that the generated graphql schema in $SOURCE_INTROSPECTION_FILE_PATH is checked in";
    diff $SOURCE_INTROSPECTION_FILE_PATH $GENERTATED_INTROSPECTION_FILE_PATH;
    exit 1
fi
