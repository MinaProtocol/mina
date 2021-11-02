package delegation_backend

import (
	"backend_utilities/counter"
	"backend_utilities/misc"
	"bytes"
	"cloud.google.com/go/storage"
	"context"
	"encoding/json"
	"github.com/btcsuite/btcutil/base58"
	logging "github.com/ipfs/go-log/v2"
	"golang.org/x/crypto/blake2b"
	"io"
	"net/http"
	"strings"
	"time"
)

type App struct {
	Log           *logging.ZapEventLogger
	SubmitCounter *counter.AttemptCounter
	Whitelist     *WhitelistMVar
	Save          func(ObjectsToSave)
	Now           misc.NowFunc
}

type SubmitH struct {
	app *App
}

type Paths struct {
	metaPath  string
	blockPath string
}

func makePaths(req *submitRequest) (res Paths) {
	blockHashBytes := blake2b.Sum256(req.Data.Block.data)
	blockHash := base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
	createdAtStr := req.Data.CreatedAt.UTC().Format(time.RFC3339)
	pkStr := base58.CheckEncode(req.Submitter[:], BASE58CHECK_VERSION_PK)
	res.metaPath = strings.Join([]string{"submissions", pkStr, blockHash, createdAtStr + ".json"}, "/")
	res.blockPath = "blocks/" + blockHash + ".dat"
	return
}

func makeSignPayload(req *submitRequestData) ([]byte, error) {
	createdAtStr := req.CreatedAt.UTC().Format(time.RFC3339)
	createdAtJson, err2 := json.Marshal(createdAtStr)
	if err2 != nil {
		return nil, err2
	}
	signPayload := new(BufferOrError)
	signPayload.WriteString("{\"block\":")
	signPayload.Write(req.Block.json)
	signPayload.WriteString(",\"created_at\":")
	signPayload.Write(createdAtJson)
	signPayload.WriteString(",\"peer_id\":")
	signPayload.Write(req.PeerId.json)
	if req.SnarkWork != nil {
		signPayload.WriteString(",\"snark_work\":")
		signPayload.Write(req.SnarkWork.json)
	}
	signPayload.WriteString("}")
	return signPayload.Buf.Bytes(), signPayload.Err
}

// TODO consider using pointers and doing `== nil` comparison
var nilSig Sig
var nilPk Pk
var nilTime time.Time

func (h *SubmitH) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body := misc.ValidateContentLength(w, r, h.app.Log, MAX_SUBMIT_PAYLOAD_SIZE)
	if body == nil {
		return
	}

	var req submitRequest
	if err := json.Unmarshal(body, &req); err != nil {
		h.app.Log.Debugf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log, &w, "Wrong payload")
		return
	}
	if req.Data.Block == nil || req.Data.PeerId == nil || req.Data.CreatedAt == nilTime || req.Submitter == nilPk || req.Sig == nilSig {
		h.app.Log.Debug("One of required fields wasn't provided")
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log, &w, "One of required fields wasn't provided")
		return
	}

	wl := h.app.Whitelist.ReadWhitelist()
	if (*wl)[req.Submitter] == nil {
		w.WriteHeader(401)
		misc.WriteErrorResponse(h.app.Log, &w, "Submitter is not registered")
		return
	}

	submittedAt := h.app.Now()
	if req.Data.CreatedAt.Add(TIME_DIFF_DELTA).After(submittedAt) {
		h.app.Log.Debugf("Field created_at is a timestamp in future: %v", submittedAt)
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log, &w, "Field created_at is a timestamp in future")
		return
	}

	payload, err := makeSignPayload(&req.Data)
	if err != nil {
		h.app.Log.Errorf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(500)
		misc.WriteErrorResponse(h.app.Log, &w, "Unexpected server error")
		return
	}
	hash := blake2b.Sum256(payload)
	if !verifySig(&req.Submitter, &req.Sig, hash[:], NETWORK_ID) {
		w.WriteHeader(401)
		misc.WriteErrorResponse(h.app.Log, &w, "Invalid signature")
		return
	}

	passesAttemptLimit := h.app.SubmitCounter.RecordAttempt(req.Submitter)
	if !passesAttemptLimit {
		w.WriteHeader(429)
		misc.WriteErrorResponse(h.app.Log, &w, "Too many requests per hour")
		return
	}

	var meta metaToBeSaved
	meta.SubmittedAt = submittedAt
	meta.PeerId = req.Data.PeerId
	meta.SnarkWork = req.Data.SnarkWork
	meta.RemoteAddr = r.RemoteAddr

	metaBytes, err1 := json.Marshal(meta)
	if err1 != nil {
		h.app.Log.Errorf("Error while marshaling JSON for metaToBeSaved: %v", err)
		w.WriteHeader(500)
		misc.WriteErrorResponse(h.app.Log, &w, "Unexpected server error")
		return
	}

	ps := makePaths(&req)

	toSave := make(ObjectsToSave)
	toSave[ps.metaPath] = metaBytes
	toSave[ps.blockPath] = req.Data.Block.data
	h.app.Save(toSave)

	_, err2 := io.Copy(w, bytes.NewReader([]byte("{\"status\":\"ok\"}")))
	if err2 != nil {
		h.app.Log.Debugf("Error while responding with ok status to the user: %v", err2)
	}
}

func (app *App) NewSubmitH() *SubmitH {
	s := new(SubmitH)
	s.app = app
	return s
}
