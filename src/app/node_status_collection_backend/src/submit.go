package node_status_collection_backend

import (
	"backend_utilities/counter"
	"backend_utilities/misc"
	"bytes"
	"encoding/json"
	logging "github.com/ipfs/go-log/v2"
	"io"
	"net/http"
	"strings"
	"time"
)

type App struct {
	Log  *logging.ZapEventLogger
	SubmitCounter *counter.AttemptCounter
	Save func(misc.ObjectsToSave)
	Now  misc.NowFunc
}

type SubmitH struct {
	app *App
}

func makePath(req *nodeStatusRequest) (res string) {
	ipAddress := req.Data.IpAddress
	peerId := req.Data.PeerId
	createdAt := req.Data.Timestamp.UTC().Format(time.RFC3339)
	return strings.Join([]string{"submissions", peerId, ipAddress, createdAt + ".json"}, "/")
}

var nilTime time.Time

func (h *SubmitH) ServerHTTP(w http.ResponseWriter, r *http.Request) {
	body := misc.ValidateContentLength(w, r, h.app.Log, MAX_SUBMIT_PAYLOAD_SIZE)
	if body == nil {
		return
	}

	var req nodeStatusRequest
	if err := json.Unmarshal(body, &req); err != nil {
		h.app.Log.Debugf("Error while unmarshaling JSON of /submit request's body: %v", err)
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log, &w, "Wrong payload")
		return
	}

	if req.Data.IpAddress == "" || req.Data.PeerId == "" || req.Data.Timestamp == nilTime {
		h.app.Log.Debug("One of required fields wasn't provided")
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log, &w, "One of required fields wasn't provided")
		return
	}

	passesAttemptLimit := h.app.SubmitCounter.RecordAttempt(req.Data.PeerId)
	if !passesAttemptLimit {
		w.WriteHeader(429)
		misc.WriteErrorResponse(h.app.Log, &w, "Too many requests per hour")
		return
	}

	submittedAt := h.app.Now()
	if req.Data.Timestamp.Add(TIME_DIFF_DELTA).After(submittedAt) {
		h.app.Log.Debugf("Field timestamp is in future: %v", submittedAt)
		w.WriteHeader(400)
		misc.WriteErrorResponse(h.app.Log	, &w, "Field timestamp is in future")
		return
	}

	path := makePath(&req)

	toSave := make(misc.ObjectsToSave)
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
