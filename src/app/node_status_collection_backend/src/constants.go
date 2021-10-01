package node_status_collection_backend

import "time"

const MAX_SUBMIT_PAYLOAD_SIZE = 50000000 // max payload size in bytes

const NODE_STATUS_COLLECTION_BACKEND_LISTEN_TO = ":8080"

const TIME_DIFF_DELTA time.Duration = -5 * 60 * 1000000000 // -5m

const CLOUD_BUCKET_NAME = "node-status-collection"
