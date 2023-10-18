package delegation_backend

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	"golang.org/x/crypto/blake2b"
)

type errorResponse struct {
	Msg string `json:"error"`
}

func writeErrorResponse(app *App, w *http.ResponseWriter, msg string) {
	app.Log.Debugf("Responding with error: %s", msg)
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

func (ctx *AwsContext) S3Save(objs ObjectsToSave) {
	for path, bs := range objs {
		_, err := ctx.Client.HeadObject(ctx.Context, &s3.HeadObjectInput{
			Bucket: ctx.BucketName,
			Key:    aws.String(ctx.Prefix + "/" + path),
		})
		if err == nil {
			ctx.Log.Warnf("object already exists: %s", path)
		}

		_, err = ctx.Client.PutObject(ctx.Context, &s3.PutObjectInput{
			Bucket:     ctx.BucketName,
			Key:        aws.String(ctx.Prefix + "/" + path),
			Body:       bytes.NewReader(bs),
			ContentMD5: nil,
		})
		if err != nil {
			ctx.Log.Warnf("Error while saving metadata: %v", err)
		}
	}
}

type ObjectsToSave map[string][]byte

type AwsContext struct {
	Client     *s3.Client
	BucketName *string
	Prefix     string
	Context    context.Context
	Log        *logging.ZapEventLogger
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
func makePaths(submittedAt time.Time, blockHash string, submitter Pk) Paths {
	submittedAtStr := submittedAt.UTC().Format(time.RFC3339)
	return MakePathsImpl(submittedAtStr, blockHash, submitter)
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
		writeErrorResponse(h.app, &w, "Error decoding payload")
		return
	}

	if !req.CheckRequiredFields() {
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

	payload, err := req.Data.MakeSignPayload()
	if err != nil {
		h.app.Log.Errorf("Error while making sign payload: %v", err)
		w.WriteHeader(500)
		writeErrorResponse(h.app, &w, "Unexpected server error")
		return
	}

	hash := blake2b.Sum256(payload)
	if !verifySig(&req.Submitter, &req.Sig, hash[:], NetworkId()) {
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

	blockHash := req.GetBlockDataHash()
	ps := makePaths(submittedAt, blockHash, req.Submitter)

	remoteAddr := r.RemoteAddr
	xForwardedAll := r.Header.Values("X-Forwarded-For")
outerLoop:
	for _, xForwarded := range xForwardedAll {
		ipStrs := strings.Split(xForwarded, ",")
		for _, ipStr := range ipStrs {
			ipStr = strings.TrimSpace(ipStr)
			if ip := net.ParseIP(ipStr); ip != nil && !isPrivateIP(ip) {
				remoteAddr = ipStr
				break outerLoop
			}
		}
	}

	metaBytes, err1 := req.MakeMetaToBeSaved(remoteAddr)
	if err1 != nil {
		h.app.Log.Errorf("Error while marshaling JSON for metaToBeSaved: %v", err)
		w.WriteHeader(500)
		writeErrorResponse(h.app, &w, "Unexpected server error")
		return
	}

	toSave := make(ObjectsToSave)
	toSave[ps.Meta] = metaBytes
	toSave[ps.Block] = []byte(req.Data.Block.data)
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
