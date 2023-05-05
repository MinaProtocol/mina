#!/bin/bash

set -e 
set -o pipefail

echo "Hello, World!"

# export node logs
# echo "exporting node logs"
# export EXPORTED_LOGS="local-logs"
# export LOGS_FILENAME="daemon-logs-epoch-$EPOCHNUM-"${DATE:: -1}0".tgz"
# kubectl exec $TARGET_NODE --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina client export-local-logs --tarfile $EXPORTED_LOGS'
# kubectl exec $TARGET_NODE --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mv /root/.mina-config/exported_logs/$EXPORTED_LOGS.tar.gz $LOGS_FILENAME'
# echo "log export complete!"