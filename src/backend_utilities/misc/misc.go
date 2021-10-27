package misc

import (
	"bytes"
	"cloud.google.com/go/storage"
	"context"
	"encoding/json"
	logging "github.com/ipfs/go-log/v2"
	"io"
	"net/http"
	"time"
)

type errorResponse struct {
	Msg string `json:"error"`
}

func WriteErrorResponse(log *logging.ZapEventLogger, w *http.ResponseWriter, msg string) {
	bs, err := json.Marshal(errorResponse{msg})
	if err == nil {
		_, err2 := io.Copy(*w, bytes.NewReader(bs))
		if err2 != nil {
			log.Debugf("Failed to respond with error status: %v", err2)
		}
	} else {
		log.Fatal("Failed to json-marshal error message")
	}
}

func (ctx *GoogleContext) GoogleStorageSave(objs ObjectsToSave) {
	for path, bs := range objs {
		writer := ctx.Bucket.Object(path).NewWriter(ctx.Context)
		defer writer.Close()
		_, err := io.Copy(writer, bytes.NewReader(bs))
		if err != nil {
			ctx.Log.Debugf("Error while saving metadata: %v", err)
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

type NowFunc = func() time.Time

func ValidateContentLength(w http.ResponseWriter, r *http.Request, log *logging.ZapEventLogger, max_size int64) []byte {
	if r.ContentLength == -1 {
		w.WriteHeader(411)
		return nil
	} else if r.ContentLength > max_size {
		w.WriteHeader(413)
		return nil
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, r.ContentLength))
	if err != nil || int64(len(body)) != r.ContentLength {
		log.Debugf("Error while readinng /submit request's body:  %v", err)
		w.WriteHeader(400)
		WriteErrorResponse(log, &w, "Error reading the body")
		return nil
	}
	return body
}
