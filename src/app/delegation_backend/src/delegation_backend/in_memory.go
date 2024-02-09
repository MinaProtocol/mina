package delegation_backend

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"time"

	logging "github.com/ipfs/go-log/v2"
)

// Map from record to submission time
type InMemoryStorage struct {
	data map[MiniMetaToBeSaved]time.Time
	log  logging.StandardLogger
}

func NewInMemoryStorage(log logging.StandardLogger) *InMemoryStorage {
	return &InMemoryStorage{
		data: make(map[MiniMetaToBeSaved]time.Time),
		log:  log,
	}
}

func (storage *InMemoryStorage) Save(submittedAt time.Time, meta MetaToBeSaved, _ BlockDataHash, _ Pk, _ []byte) error {
	storage.data[meta.MiniMetaToBeSaved] = submittedAt
	return nil
}

func (storage *InMemoryStorage) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var result []MiniMetaToBeSaved
	var outdated []MiniMetaToBeSaved
	earliest := time.Now().Add(-IN_MEMORY_KEEP_INTERVAL)
	for meta, submittedAt := range storage.data {
		if submittedAt.After(earliest) {
			result = append(result, meta)
		} else {
			outdated = append(outdated, meta)
		}
	}
	for _, meta := range outdated {
		delete(storage.data, meta)
	}
	var bs []byte
	var err error
	if result == nil {
		bs = []byte("[]")
	} else {
		bs, err = json.Marshal(result)
	}
	if err != nil {
		storage.log.Errorf("Error while marshaling response: %v", err)
		w.WriteHeader(500)
		writeErrorResponse(storage.log, &w, "Unexpected server error")
		return
	}
	_, err = io.Copy(w, bytes.NewReader(bs))
	if err != nil {
		storage.log.Debugf("Error while responding with ok status to the user: %v", err)
	}
}
