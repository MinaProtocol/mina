package delegation_backend

import (
	"os"
	"time"
)

const MAX_SUBMIT_PAYLOAD_SIZE = 50000000 // max payload size in bytes
const REQUESTS_PER_PK_HOURLY = 120
const DELEGATION_BACKEND_LISTEN_TO = ":8080"
const TIME_DIFF_DELTA time.Duration = -5 * 60 * 1000000000 // -5m
const WHITELIST_REFRESH_INTERVAL = 10 * 60 * 1000000000    // 10m
const DELEGATION_WHITELIST_LIST = "Form Responses 1"
const DELEGATION_WHITELIST_COLUMN = "E"

var PK_PREFIX = [...]byte{1, 1}
var SIG_PREFIX = [...]byte{1}
var BLOCK_HASH_PREFIX = [...]byte{1}

func NetworkId() uint8 {
	if os.Getenv("NETWORK") == "" {
		return 1
	}
	return 0
}

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
}

const PK_LENGTH = 33  // one field element (32B) + 1 bit (encoded as full byte)
const SIG_LENGTH = 64 // one field element (32B) and one scalar (32B)

// we use state hash code here, although it's not state hash
const BASE58CHECK_VERSION_BLOCK_HASH byte = 0x10
const BASE58CHECK_VERSION_PK byte = 0xCB
const BASE58CHECK_VERSION_SIG byte = 0x9A
