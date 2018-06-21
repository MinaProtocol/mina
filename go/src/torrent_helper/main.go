package main

import (
	"bufio"
	"bytes"
	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/bencode"
	"github.com/anacrolix/torrent/metainfo"
	"github.com/fvbommel/sexpr"
	"golang.org/x/time/rate"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"
)

var (
	mutex            = &sync.Mutex{}
	client           *torrent.Client
	config           *Config
	default_trackers = [][]string{
		{"udp://tracker.openbittorrent.com:80"},
		{"udp://tracker.publicbt.com:80"},
		{"udp://tracker.opentrackr.org:1337"},
	}
	default_dht_bootstraps = []metainfo.Node{
		metainfo.Node("dht.libtorrent.org:25401"),
		metainfo.Node("router.bittorrent.com:6881"),
		metainfo.Node("router.utorrent.com:6881"),
	}
)

type Config struct {
	datadir        string
	upload_limit   int
	download_limit int
}

func newSyntax() *sexpr.Syntax {
	s := new(sexpr.Syntax)
	s.StringLit = []string{"\"", "\""}
	s.Delimiters = [][2]string{{"(", ")"}}
	s.NumberFunc = sexpr.LexNumber
	s.BooleanFunc = sexpr.LexBoolean
	return s
}

func offer(w http.ResponseWriter, r *http.Request) {
	mutex.Lock()
	defer mutex.Unlock()

	subdir, err := url.QueryUnescape(r.URL.Query()["subdir"][0])
	if err != nil {
		log.Panicf("subdir (%s) failed url unescaping: %s", subdir, err.Error())
	}

	datapath := filepath.Join(config.datadir, subdir, "blob_content")
	os_fi, err := os.Stat(datapath)
	if err != nil {
		log.Panicf("couldn't stat %s: %s", datapath, err)
	}

	mi := metainfo.MetaInfo{
		AnnounceList: default_trackers,
		Nodes:        default_dht_bootstraps,
		Comment:      "Coda blob",
		CreatedBy:    "coda torrent_helper",
		CreationDate: time.Now().Unix(),
	}

	info := metainfo.Info{
		PieceLength: 256 * 1024,
		Length:      os_fi.Size(),
		Name:        "blob_content",
	}

	info.GeneratePieces(func(fi metainfo.FileInfo) (io.ReadCloser, error) {
		return os.Open(datapath)
	})
	mi.InfoBytes, err = bencode.Marshal(info)
	if err != nil {
		log.Panicf("error encoding the Info: %s", err)
	}
	magnet := mi.Magnet("", mi.HashInfoBytes())
	log.Printf("made this magnet link: %s", magnet)
}

func retrieve(w http.ResponseWriter, r *http.Request) {
	mutex.Lock()
	defer mutex.Unlock()
}

func forget(w http.ResponseWriter, r *http.Request) {
	mutex.Lock()
	defer mutex.Unlock()

}

func main() {
	var err error = nil

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	pconfig_line := scanner.Text()
	pconfig := new(sexpr.AST)
	err = sexpr.ParseString(pconfig, pconfig_line, newSyntax())
	if err != nil {
		log.Panicf("couldn't parse configuration: %s", err)
	}

	config = new(Config)
	for _, child := range pconfig.Root.Children {
		k := child.Children[0].Data
		v := string(child.Children[1].Data[:])
		if bytes.Equal(k, []byte("datadir")) {
			config.datadir = v
		} else if bytes.Equal(k, []byte("upload_limit")) {
			config.upload_limit, err = strconv.Atoi(v)
			if err != nil {
				log.Fatalf("upload_limit couldn't be parsed: %s", err)
			}
		} else if bytes.Equal(k, []byte("download_limit")) {
			config.download_limit, err = strconv.Atoi(v)
			if err != nil {
				log.Fatalf("download_limit couldn't be parsed: %s", err)
			}
		} else {
			log.Fatalf("unexpected field `%s` in pconfig sexp, out of sync with daemon?", k)
		}
	}

	// XXX: this _static_ burst size assumes the maximum piece size we'll
	// ever encounter is 256KiB.

	tconfig := torrent.Config{
		Seed:                true,
		UploadRateLimiter:   rate.NewLimiter(rate.Limit(config.upload_limit), 256*1024),
		DownloadRateLimiter: rate.NewLimiter(rate.Limit(config.download_limit), 256*1024),
	}
	log.Printf("%v %v", config, tconfig)

	//client, err = torrent.NewClient(nil)
	//if err != nil {
	//	log.Fatal("couldn't create the torrent client: %s", err)
	//}

	//http.HandleFunc("/offer", offer)
	//http.HandleFunc("/retrieve", retrieve)
	//http.HandleFunc("/forget", forget)
}
