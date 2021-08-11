package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime/debug"
	"sync"
	"time"

	// importing this automatically registers the pprof api to our metrics server
	_ "net/http/pprof"

	logging "github.com/ipfs/go-log/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const validationTimeout = 5 * time.Minute

func startMetricsServer(port string) *codaMetricsServer {
	log := logging.Logger("metrics server")
	done := &sync.WaitGroup{}
	done.Add(1)
	server := &http.Server{Addr: ":" + port}

	// does this need re-registered every time?
	// http.Handle("/metrics", promhttp.Handler())

	go func() {
		defer done.Done()

		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("http server error: %v", err)
		}
	}()

	return &codaMetricsServer{
		port:   port,
		server: server,
		done:   done,
	}
}

func (ms *codaMetricsServer) Shutdown() {
	if err := ms.server.Shutdown(context.Background()); err != nil {
		panic(err)
	}

	ms.done.Wait()
}

var (
	metricsServer *codaMetricsServer
)

const (
	latencyMeasurementTime = time.Second * 5
)

var connectionCountMetric = prometheus.NewGauge(prometheus.GaugeOpts{
	Name: "Mina_libp2p_connections_total",
	Help: "Number of active connections, according to the CodaConnectionManager.",
})

func init() {
	// === Register metrics collectors here ===
	prometheus.MustRegister(connectionCountMetric)
	http.Handle("/metrics", promhttp.Handler())
}

func main() {
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	helperLog := logging.Logger("helper top-level JSON handling")

	helperLog.Infof("libp2p_helper has the following logging subsystems active: %v", logging.GetSubsystems())

	// === Set subsystem log levels ===
	// All subsystems that have been considered are explicitly listed. Any that
	// are added when modifying this code should be considered and added to
	// this list.
	// The levels below set the **minimum** log level for each subsystem.
	// Messages emitted at lower levels than the given level will not be
	// emitted.
	_ = logging.SetLogLevel("mplex", "debug")
	_ = logging.SetLogLevel("addrutil", "info")     // Logs every resolve call at debug
	_ = logging.SetLogLevel("net/identify", "info") // Logs every message sent/received at debug
	_ = logging.SetLogLevel("ping", "info")         // Logs every ping timeout at debug
	_ = logging.SetLogLevel("basichost", "info")    // Spammy at debug
	_ = logging.SetLogLevel("test-logger", "debug")
	_ = logging.SetLogLevel("blankhost", "debug")
	_ = logging.SetLogLevel("connmgr", "debug")
	_ = logging.SetLogLevel("eventlog", "debug")
	_ = logging.SetLogLevel("p2p-config", "debug")
	_ = logging.SetLogLevel("ipns", "debug")
	_ = logging.SetLogLevel("nat", "debug")
	_ = logging.SetLogLevel("autorelay", "info") // Logs relayed byte counts spammily
	_ = logging.SetLogLevel("providers", "debug")
	_ = logging.SetLogLevel("dht/RtRefreshManager", "warn") // Ping logs are spammy at debug, cpl logs are spammy at info
	_ = logging.SetLogLevel("dht", "info")                  // Logs every operation to debug
	_ = logging.SetLogLevel("peerstore", "debug")
	_ = logging.SetLogLevel("diversityFilter", "debug")
	_ = logging.SetLogLevel("table", "debug")
	_ = logging.SetLogLevel("stream-upgrader", "debug")
	_ = logging.SetLogLevel("helper top-level JSON handling", "debug")
	_ = logging.SetLogLevel("dht.pb", "debug")
	_ = logging.SetLogLevel("tcp-tpt", "debug")
	_ = logging.SetLogLevel("autonat", "debug")
	_ = logging.SetLogLevel("discovery", "debug")
	_ = logging.SetLogLevel("routing/record", "debug")
	_ = logging.SetLogLevel("pubsub", "debug") // Spammy about blacklisted peers, maybe should be info?
	_ = logging.SetLogLevel("badger", "debug")
	_ = logging.SetLogLevel("relay", "info") // Log relayed byte counts spammily
	_ = logging.SetLogLevel("routedhost", "debug")
	_ = logging.SetLogLevel("swarm2", "info") // Logs a new stream to each peer when opended at debug
	_ = logging.SetLogLevel("peerstore/ds", "debug")
	_ = logging.SetLogLevel("mdns", "info") // Logs each mdns call
	_ = logging.SetLogLevel("bootstrap", "debug")
	_ = logging.SetLogLevel("reuseport-transport", "debug")

	go func() {
		i := 0
		for {
			seqs <- i
			i++
		}
	}()

	lines := bufio.NewScanner(os.Stdin)
	// 22MiB buffer size, larger than the 21.33MB minimum for 16MiB to be b64'd
	// 4 * (2^24/3) / 2^20 = 21.33
	bufsize := (1024 * 1024) * 1024
	lines.Buffer(make([]byte, bufsize), bufsize)

	app := newApp()

	go func() {
		for {
			msg := <-app.OutChan
			bytes, err := json.Marshal(msg)
			if err != nil {
				panic(err)
			}

			n, err := app.Out.Write(bytes)
			if err != nil {
				panic(err)
			}

			if n != len(bytes) {
				// TODO: handle this correctly.
				panic("short write :(")
			}

			err = app.Out.WriteByte(0x0a)
			if err != nil {
				panic(err)
			}

			if err := app.Out.Flush(); err != nil {
				panic(err)
			}
		}
	}()

	var line string

	defer func() {
		if r := recover(); r != nil {
			helperLog.Error("While handling RPC:", line, "\nThe following panic occurred: ", r, "\nstack:\n", string(debug.Stack()))
		}
	}()

	for lines.Scan() {
		line = lines.Text()
		helperLog.Debugf("message size is %d", len(line))
		var raw json.RawMessage
		env := envelope{
			Body: &raw,
		}
		if err := json.Unmarshal([]byte(line), &env); err != nil {
			log.Print("when unmarshaling the envelope...")
			log.Panic(err)
		}
		msg := msgHandlers[env.Method]()
		if err := json.Unmarshal(raw, msg); err != nil {
			log.Print("when unmarshaling the method invocation...")
			log.Panic(err)
		}

		go func() {
			start := time.Now()
			ret, err := msg.run(app)
			if err != nil {
				app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
				return
			}

			res, err := json.Marshal(ret)
			if err != nil {
				app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
				return
			}

			app.writeMsg(successResult{Seqno: env.Seqno, Success: res, Duration: time.Since(start).String()})
		}()
	}
	app.writeMsg(errorResult{Seqno: 0, Errorr: fmt.Sprintf("helper stdin scanning stopped because %v", lines.Err())})
	// we never want the helper to get here, it should be killed or gracefully
	// shut down instead of stdin closed.
	os.Exit(1)
}

var _ json.Marshaler = (*methodIdx)(nil)
