package delegation_backend

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/btcsuite/btcutil/base58"
	logging "github.com/ipfs/go-log/v2"
	"golang.org/x/crypto/blake2b"
)

type errorResponse struct {
	Msg string `json:"error"`
}

func writeErrorResponse(app *App, w *http.ResponseWriter, msg string) {
	bs, err := json.Marshal(errorResponse{msg})
	if err == nil {
		_, err2 := io.Copy(*w, bytes.NewReader(bs))
		if err2 != nil {
			app.Log.Debugf("Failed to respond with error status: %v", err2)
		}
	} else {
		app.Log.Fatal("Failed to json-marshal error message")
	}
}

func (ctx *GoogleContext) GoogleStorageSave(objs ObjectsToSave) {
	for path, bs := range objs {
		obj := ctx.Bucket.Object(path).If(storage.Conditions{DoesNotExist: true})
		writer := obj.NewWriter(ctx.Context)
		defer writer.Close()
		_, err := io.Copy(writer, bytes.NewReader(bs))
		if err != nil {
			ctx.Log.Warnf("Error while saving metadata: %v", err)
		}
	}
}

type ObjectsToSave map[string][]byte

type GoogleContext struct {
	Bucket  *storage.BucketHandle
	Context context.Context
	Log     *logging.ZapEventLogger
}

type App struct {
	Log           *logging.ZapEventLogger
	SubmitCounter *AttemptCounter
	Whitelist     *WhitelistMVar
	Save          func(ObjectsToSave)
	Now           nowFunc
}

type SubmitH struct {
	app *App
}

type Paths struct {
	Meta  string
	Block string
}

func MakePathsImpl(submittedAt string, blockHash string, submitter Pk) (res Paths) {
	res.Meta = strings.Join([]string{"submissions", submittedAt[:10], submittedAt + "-" + submitter.String() + ".json"}, "/")
	res.Block = "blocks/" + blockHash + ".dat"
	return
}
func makePaths(submittedAt time.Time, req *submitRequest) (Paths, string) {
	blockHashBytes := blake2b.Sum256(req.Data.Block.data)
	blockHash := base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
	submittedAtStr := submittedAt.UTC().Format(time.RFC3339)
	return MakePathsImpl(submittedAtStr, blockHash, req.Submitter), blockHash
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
	signPayload.WriteString(",\"peer_id\":\"")
	signPayload.WriteString(req.PeerId)
	signPayload.WriteString("\"")
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
	if r.ContentLength == -1 {
		w.WriteHeader(411)
		return
	} else if r.ContentLength > MAX_SUBMIT_PAYLOAD_SIZE {
		w.WriteHeader(413)
		return
	}
	body, err1 := io.ReadAll(io.LimitReader(r.Body, r.ContentLength))
	if err1 != nil || int64(len(body)) != r.ContentLength {
		h.app.Log.Debugf("Error while reading /submit request's body: %v", err1)
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "Error reading the body")
		return
	}
	var req submitRequest
	if err := json.Unmarshal(body, &req); err != nil {
		h.app.Log.Debugf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "Wrong payload")
		return
	}
	if req.Data.Block == nil || req.Data.PeerId == "" || req.Data.CreatedAt == nilTime || req.Submitter == nilPk || req.Sig == nilSig {
		h.app.Log.Debug("One of required fields wasn't provided")
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "One of required fields wasn't provided")
		return
	}

	wl := h.app.Whitelist.ReadWhitelist()
	if (*wl)[req.Submitter] == nil {
		w.WriteHeader(401)
		writeErrorResponse(h.app, &w, "Submitter is not registered")
		return
	}

	submittedAt := h.app.Now()
	if req.Data.CreatedAt.Add(TIME_DIFF_DELTA).After(submittedAt) {
		h.app.Log.Debugf("Field created_at is a timestamp in future: %v", submittedAt)
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "Field created_at is a timestamp in future")
		return
	}

	payload, err := makeSignPayload(&req.Data)
	if err != nil {
		h.app.Log.Errorf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(500)
		writeErrorResponse(h.app, &w, "Unexpected server error")
		return
	}
	hash := blake2b.Sum256(payload)
	if !verifySig(&req.Submitter, &req.Sig, hash[:], NETWORK_ID) {
		w.WriteHeader(401)
		writeErrorResponse(h.app, &w, "Invalid signature")
		return
	}

	passesAttemptLimit := h.app.SubmitCounter.RecordAttempt(req.Submitter)
	if !passesAttemptLimit {
		w.WriteHeader(429)
		writeErrorResponse(h.app, &w, "Too many requests per hour")
		return
	}

	ps, blockHash := makePaths(submittedAt, &req)

	meta := MetaToBeSaved{
		CreatedAt:  req.Data.CreatedAt.Format(time.RFC3339),
		PeerId:     req.Data.PeerId,
		SnarkWork:  req.Data.SnarkWork,
		RemoteAddr: r.RemoteAddr,
		BlockHash:  blockHash,
		Submitter:  req.Submitter,
	}

	metaBytes, err1 := json.Marshal(meta)
	if err1 != nil {
		h.app.Log.Errorf("Error while marshaling JSON for metaToBeSaved: %v", err)
		w.WriteHeader(500)
		writeErrorResponse(h.app, &w, "Unexpected server error")
		return
	}

	toSave := make(ObjectsToSave)
	toSave[ps.Meta] = metaBytes
	toSave[ps.Block] = req.Data.Block.data
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
