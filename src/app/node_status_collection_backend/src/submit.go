package node_status_collection_backend

import (
	"bytes"
	"cloud.google.com/go/storage"
	"context"
	"encoding/json"
	logging "github.com/ipfs/go-log/v2"
	"io"
	"net/http"
	"strings"
	"time"
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
		writer := ctx.Bucket.Object(path).NewWriter(ctx.Context)
		defer writer.Close()
		_, err := io.Copy(writer, bytes.NewReader(bs))
		if err != nil {
			ctx.Log.Debugf("Error while saving node status: %v", err)
			return
		}
	}
}

type ObjectsToSave map[string][]byte

type GoogleContext struct {
	Bucket  *storage.BucketHandle
	Context context.Context
	Log     *logging.ZapEventLogger
}

type nowFunc = func() time.Time

type App struct {
	Log  *logging.ZapEventLogger
	Save func(ObjectsToSave)
	Now  nowFunc
}

type SubmitH struct {
	app *App
}

func makePath(req *nodeStatusRequest) (res string) {
	ipAddress := req.Data.IpAddress
	peerId := req.Data.PeerId
	createdAt := req.Data.Timestamp.UTC().Format(time.RFC3339)
	return strings.Join([]string{"submissions", ipAddress, peerId, createdAt + ".json"}, "/")
}

var nilTime time.Time

func (h *SubmitH) ServerHTTP(w http.ResponseWriter, r *http.Request) {
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
		writeErrorResponse(h.app, &w, "Error  reading the body")
		return
	}
	var req nodeStatusRequest
	if err := json.Unmarshal(body, &req); err != nil {
		h.app.Log.Debugf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "Wrong payload")
		return
	}
	if req.Data.IpAddress == "" || req.Data.PeerId == "" || req.Data.Timestamp == nilTime {
		h.app.Log.Debug("One of required fields wasn't provided")
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "One of required fields wasn't provided")
		return
	}

	submittedAt := h.app.Now()
	if req.Data.Timestamp.Add(TIME_DIFF_DELTA).After(submittedAt) {
		h.app.Log.Debugf("Field timestamp is in future: %v", submittedAt)
		w.WriteHeader(400)
		writeErrorResponse(h.app, &w, "Field timestamp is in future")
		return
	}

	path := makePath(&req)

	toSave := make(ObjectsToSave)
	toSave[path] = body

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
