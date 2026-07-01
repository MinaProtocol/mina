package hardfork

// In-process ITN GraphQL client: the hardfork test signs ITN auth and
// scheduled-transaction mutations in-process with crypto/ed25519, so it depends
// only on Go (no external keygen/signing subprocesses).
//
// Auth protocol — mirrors the node's src/app/cli/src/init/graphql_internal.ml and
// the mina-perf-testing orchestrator (src/graphql.go):
//   - auth query:        Authorization: "Signature <b64 pub> <b64 sig(body)>"
//   - sequenced mutation: Authorization: "Signature <b64 pub> <b64 sig(msg)> ;
//     Sequencing <uuid> <seqno>", where msg = 2-byte big-endian seqno ++ uuid ++ body.
// The signature is pure Ed25519 over the exact transmitted body bytes; the public
// key is the 32 raw key bytes, base64'd, which is exactly what the daemon receives
// via --itn-keys.

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// itnAuth holds the ed25519 keypair used to authenticate to a daemon's ITN GraphQL
// endpoint.
type itnAuth struct {
	priv   ed25519.PrivateKey
	pubB64 string // base64 of the 32-byte raw public key (the daemon --itn-keys value)
}

// newItnAuth generates a fresh ed25519 ITN keypair.
func newItnAuth() (*itnAuth, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("generate ITN ed25519 key: %w", err)
	}
	return &itnAuth{priv: priv, pubB64: base64.StdEncoding.EncodeToString(pub)}, nil
}

// writePEM writes the private key as a PKCS#8 PEM, for debugging / manual reuse of
// the same identity with an external client. Signing always uses the in-memory key,
// so deleting this file (e.g. the main-network root wipe) cannot break the run.
func (a *itnAuth) writePEM(path string) error {
	der, err := x509.MarshalPKCS8PrivateKey(a.priv)
	if err != nil {
		return err
	}
	return os.WriteFile(path, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0600)
}

// sigB64 returns base64(ed25519 signature over msg).
func (a *itnAuth) sigB64(msg []byte) string {
	return base64.StdEncoding.EncodeToString(ed25519.Sign(a.priv, msg))
}

// itnURL is the ITN GraphQL endpoint for a daemon listening on the given port.
func itnURL(port int) string {
	return fmt.Sprintf("http://127.0.0.1:%d/graphql", port)
}

// itnPost issues a GraphQL POST with the given Authorization header and returns the
// "data" object, erroring if the response carries GraphQL "errors".
func itnPost(url string, body []byte, authHeader string) (map[string]json.RawMessage, error) {
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", authHeader)
	resp, err := (&http.Client{Timeout: 60 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out struct {
		Data   map[string]json.RawMessage `json:"data"`
		Errors json.RawMessage            `json:"errors"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode ITN response: %w", err)
	}
	if len(out.Errors) > 0 && string(out.Errors) != "null" {
		return nil, fmt.Errorf("GraphQL errors: %s", out.Errors)
	}
	return out.Data, nil
}

// marshalNoEscape JSON-encodes v without HTML escaping, trimming the trailing
// newline Encoder appends. The returned bytes are used both to sign and to send, so
// the signature always covers the exact transmitted body.
func marshalNoEscape(v interface{}) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

// auth performs the ITN auth handshake and returns the server UUID + the signer's
// current sequence number.
func (a *itnAuth) auth(url string) (string, int, error) {
	body := []byte(`{"query":"query { auth { serverUuid signerSequenceNumber } }"}`)
	hdr := "Signature " + a.pubB64 + " " + a.sigB64(body)
	data, err := itnPost(url, body, hdr)
	if err != nil {
		return "", 0, err
	}
	var auth struct {
		ServerUUID           string          `json:"serverUuid"`
		SignerSequenceNumber json.RawMessage `json:"signerSequenceNumber"`
	}
	if err := json.Unmarshal(data["auth"], &auth); err != nil {
		return "", 0, fmt.Errorf("decode auth: %w", err)
	}
	// signerSequenceNumber may arrive as a JSON string or number; accept both.
	seqno, err := strconv.Atoi(strings.Trim(string(auth.SignerSequenceNumber), `"`))
	if err != nil {
		return "", 0, fmt.Errorf("parse signerSequenceNumber %s: %w", auth.SignerSequenceNumber, err)
	}
	return auth.ServerUUID, seqno, nil
}

// sequencedMutation signs and sends a sequenced ITN mutation: it authenticates to
// obtain the current (uuid, seqno), signs 2-byte BE seqno ++ uuid ++ body, and
// returns the named field of the "data" object as a string.
func (a *itnAuth) sequencedMutation(url string, body []byte, field string) (string, error) {
	uuid, seqno, err := a.auth(url)
	if err != nil {
		return "", err
	}
	msg := make([]byte, 2, 2+len(uuid)+len(body))
	binary.BigEndian.PutUint16(msg, uint16(seqno))
	msg = append(msg, []byte(uuid)...)
	msg = append(msg, body...)
	hdr := fmt.Sprintf("Signature %s %s ; Sequencing %s %d", a.pubB64, a.sigB64(msg), uuid, seqno)
	data, err := itnPost(url, body, hdr)
	if err != nil {
		return "", err
	}
	var s string
	if err := json.Unmarshal(data[field], &s); err != nil {
		return "", fmt.Errorf("decode %s: %w", field, err)
	}
	return s, nil
}

// zkappLoadParams are the caller-supplied knobs for a scheduled zkApp load.
type zkappLoadParams struct {
	feePayers       []string
	numZkapps       int
	numNewAccounts  int
	numUpdates      int
	durationMin     int
	tps             float64
	memoPrefix      string
	maxCost         bool
	nonDefaultToken bool
}

// zkappCommandsInput mirrors the GraphQL ZkappCommandsDetails input the ITN
// scheduler expects.
type zkappCommandsInput struct {
	FeePayers          []string `json:"feePayers"`
	NumZkappsToDeploy  int      `json:"numZkappsToDeploy"`
	NumNewAccounts     int      `json:"numNewAccounts"`
	Tps                float64  `json:"tps"`
	DurationMin        int      `json:"durationMin"`
	MemoPrefix         string   `json:"memoPrefix"`
	NoPrecondition     bool     `json:"noPrecondition"`
	MinBalanceChange   string   `json:"minBalanceChange"`
	MaxBalanceChange   string   `json:"maxBalanceChange"`
	MinNewZkappBalance string   `json:"minNewZkappBalance"`
	MaxNewZkappBalance string   `json:"maxNewZkappBalance"`
	InitBalance        string   `json:"initBalance"`
	MinFee             string   `json:"minFee"`
	MaxFee             string   `json:"maxFee"`
	DeploymentFee      string   `json:"deploymentFee"`
	AccountQueueSize   int      `json:"accountQueueSize"`
	MaxCost            bool     `json:"maxCost"`
	MaxCostNumUpdates  int      `json:"maxCostNumUpdates"`
	NonDefaultToken    bool     `json:"nonDefaultToken"`
}

// scheduleZkappCommands schedules a zkApp load (max-cost or persistent custom-token,
// per params) and returns the scheduler handle. Balance-change bounds are required by
// the schema but unused by the max-cost generator; accountQueueSize 0 returns accounts
// to the pool immediately, keeping the per-public-key proof cache hot.
func (a *itnAuth) scheduleZkappCommands(url string, p zkappLoadParams) (string, error) {
	in := zkappCommandsInput{
		FeePayers:          p.feePayers,
		NumZkappsToDeploy:  p.numZkapps,
		NumNewAccounts:     p.numNewAccounts,
		Tps:                p.tps,
		DurationMin:        p.durationMin,
		MemoPrefix:         p.memoPrefix,
		NoPrecondition:     false,
		MinBalanceChange:   "0",
		MaxBalanceChange:   "1000000000",
		MinNewZkappBalance: "1000000000",
		MaxNewZkappBalance: "2000000000",
		InitBalance:        "5000000000",
		MinFee:             "1000000000",
		MaxFee:             "2000000000",
		DeploymentFee:      "1000000000",
		AccountQueueSize:   0,
		MaxCost:            p.maxCost,
		MaxCostNumUpdates:  p.numUpdates,
		NonDefaultToken:    p.nonDefaultToken,
	}
	body, err := marshalNoEscape(map[string]interface{}{
		"query":     "mutation($input: ZkappCommandsDetails!) { scheduleZkappCommands(input: $input) }",
		"variables": map[string]interface{}{"input": in},
	})
	if err != nil {
		return "", err
	}
	return a.sequencedMutation(url, body, "scheduleZkappCommands")
}
