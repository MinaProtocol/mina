package main

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/Khan/genqlient/graphql"
	"github.com/btcsuite/btcutil/base58"
	logging "github.com/ipfs/go-log/v2"

	// "github.com/tvdburgt/go-argon2"
	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
	"google.golang.org/api/iterator"

	lib "itn_orchestrator"
)

func PrefixByTime(t time.Time) string {
	tStr := t.UTC().Format(time.RFC3339)
	dStr := t.UTC().Format(time.DateOnly)
	return strings.Join([]string{"submissions", dStr, tStr}, "/")
}

type node struct {
	address string
	client  graphql.Client
}

type boxValue []byte

func (v *boxValue) UnmarshalJSON(data []byte) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		encoded := string(data[1 : len(data)-1])
		decoded, version, err := base58.CheckDecode(encoded)
		if err != nil {
			return err
		}
		if version != '\x02' {
			return errors.New("wrong version byte")
		}
		*v = decoded
		return nil
	}
	return errors.New("not a string token")
}

type limits struct {
	Mem uint32
	Ops uint32
}

func (v *limits) UnmarshalJSON(data []byte) error {
	var l []uint32
	err := json.Unmarshal(data, &l)
	if err != nil {
		return err
	}
	if len(l) != 2 {
		return errors.New("wrong limits format")
	}
	*v = limits{Mem: l[0], Ops: l[1]}
	return nil
}

type secretBox struct {
	Box_primitive string
	Pw_primitive  string
	Nonce         boxValue
	Pwsalt        boxValue
	Ciphertext    boxValue
	Pwdiff        limits
}

func main() {
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("itn orchestrator")
	log.Infof("itn orchestrator has the following logging subsystems active: %v", logging.GetSubsystems())
	var seed [32]byte
	_, _ = base64.StdEncoding.Decode(seed[:], []byte("2Dtcua6w9g8JZczc/D6laz6Yn1ZP7DVGCmHfFDxGupY="))
	sk := ed25519.NewKeyFromSeed(seed[:])

	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Errorf("Error creating Cloud client: %v", err)
		return
	}
	before := time.Now().Add(-15 * time.Minute)
	bucket := client.Bucket("georgeee-uptime-itn-test-2")
	query := &storage.Query{StartOffset: PrefixByTime(before)}
	it := bucket.Objects(ctx, query)
	authClient := lib.NewAuthenticatedClient(sk, http.DefaultClient)
	var nodes []node
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Errorf("Error iterating submissions: %v", err)
			return
		}
		r, err := bucket.Object(attrs.Name).NewReader(ctx)
		if err != nil {
			log.Errorf("Error reading submission %s: %v", attrs.Name, err)
			continue
		}
		var meta lib.MetaToBeSaved
		d := json.NewDecoder(r)
		err = d.Decode(&meta)
		if err != nil {
			log.Errorf("Error decoding submission %s: %v", attrs.Name, err)
			continue
		}
		colonIx := strings.IndexRune(meta.RemoteAddr, ':')
		if colonIx < 0 {
			log.Errorf("Wrong remote address in submission %s: %s", attrs.Name, meta.RemoteAddr)
			return
		}
		addr := meta.RemoteAddr[:colonIx] + ":" + strconv.Itoa(int(meta.GraphqlControlPort))
		gqlClient := graphql.NewClient("http://"+addr+"/graphql", authClient)
		authRes, err := lib.Auth(ctx, gqlClient)
		if err != nil {
			log.Errorf("Error on auth for %s: %v", addr, err)
			continue
		}
		nodes = append(nodes, node{address: addr, client: gqlClient})
		fmt.Println(addr, authRes)
	}
	var senders []string
	dir := "./keys/"
	entries, err := os.ReadDir(dir)
	if err != nil {
		log.Fatal(err)
	}
	for _, e := range entries {
		jsonFile, err := os.Open(dir + e.Name())
		if err != nil {
			log.Fatal("Failed to open file", err)
		}
		defer jsonFile.Close()
		bs, err := io.ReadAll(jsonFile)
		if err != nil {
			log.Fatal(err)
		}
		var box secretBox
		json.Unmarshal(bs, &box)
		if box.Box_primitive != "xsalsa20poly1305" || box.Pw_primitive != "argon2i" {
			log.Fatal("Unknown primitive type")
		}
		k := argon2.Key([]byte{}, box.Pwsalt, box.Pwdiff.Ops, box.Pwdiff.Mem/1024, 1, 32)
		if err != nil {
			log.Warnf("failed to parse key %s: %v", e.Name(), err)
			continue
		}
		var key [32]byte
		copy(key[:], k)
		var nonce [24]byte
		copy(nonce[:], box.Nonce)
		sk, opened := secretbox.Open(nil, box.Ciphertext, &nonce, &key)
		if !opened {
			log.Warnf("failed to unseal key %s: %v", e.Name(), err)
			continue
		}
		sender := base58.CheckEncode(sk, '\x5A')
		senders = append(senders, sender)
	}
	paymentInput := lib.PaymentsDetails{
		DurationInMinutes:     600,
		TransactionsPerSecond: 0.02,
		Memo:                  "test 1",
		FeeMax:                500000000,
		FeeMin:                200000000,
		Amount:                100000000,
		Receiver:              "B62qpPita1s7Dbnr7MVb3UK8fdssZixL1a4536aeMYxbTJEtRGGyS8U",
		Senders:               senders,
	}
	_ = paymentInput
	// nodeIx := rand.Intn(len(nodes))
	// handle, err := lib.SchedulePayments(ctx, nodes[nodeIx].client, paymentInput)
	// if err != nil {
	// 	log.Errorf("Error scheduling payments to %s: %v", nodes[nodeIx].address, err)
	// 	return
	// }
	// fmt.Println("scheduled payments for", nodes[nodeIx], handle)
	handle := "c6ca89df-2701-4b1f-057f-518952504310"
	for _, node := range nodes {
		resp, err := lib.StopPayments(ctx, node.client, handle)
		fmt.Printf("stopPayments on %s: %s (%v)\n", node.address, resp, err)
	}
}
