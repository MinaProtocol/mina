package delegation_backend

import "time"

const MAX_SUBMIT_PAYLOAD_SIZE = 50000000 // max payload size in bytes
const REQUESTS_PER_PK_HOURLY = 120
const DELEGATION_BACKEND_LISTEN_TO = ":8080"
const TIME_DIFF_DELTA time.Duration = -5*60*1000000000 // -5m
const WHITELIST_REFRESH_INTERVAL = 10*60*1000000000 // 10m
const DELEGATION_WHITELIST_LIST = "Form Responses 1"
const DELEGATION_WHITELIST_COLUMN = "E"

// Production
const DELEGATION_WHITELIST_SPREADSHEET_ID = "1xiKppb0BFUo8IKM2itIx2EWIQbBzUlFxgtZlKdnrLCU"
const CLOUD_BUCKET_NAME = "foundation-delegation-snark-work"

var PK_PREFIX = [...]byte{1, 1}
var SIG_PREFIX = [...]byte{1}

const NETWORK_ID = 1 // mainnet
const PK_LENGTH = 33 // one field element (32B) + 1 bit (encoded as full byte)
const SIG_LENGTH = 64 // one field element (32B) and one scalar (32B)

const BASE58CHECK_VERSION_BLOCK_HASH byte = 0x10
const BASE58CHECK_VERSION_PK byte = 0xCB
const BASE58CHECK_VERSION_SIG byte = 0x9A
