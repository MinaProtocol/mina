package main

import (
	"context"
	"net/http"
	"os"
	"runtime/debug"
	"strconv"
	"sync"
	"time"

	// importing this automatically registers the pprof api to our metrics server
	_ "net/http/pprof"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	logging "github.com/ipfs/go-log/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const validationTimeout = 5 * time.Minute

func startMetricsServer(port uint16) *codaMetricsServer {
	log := logging.Logger("metrics server")
	done := &sync.WaitGroup{}
	done.Add(1)
	server := &http.Server{Addr: ":" + strconv.Itoa(int(port))}

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

const (
	latencyMeasurementTime = time.Second * 5
)

var connectionCountMetric = prometheus.NewGauge(prometheus.GaugeOpts{
	Name: "Mina_libp2p_connections_total",
	Help: "Number of active connections, according to the CodaConnectionManager.",
})

var validationTimeoutMetric = prometheus.NewCounter(prometheus.CounterOpts{
	Name: "Mina_libp2p_validation_timeout_counter",
	Help: "Number of message validation timeouts",
})

var validationTimeMetric = prometheus.NewGauge(prometheus.GaugeOpts{
	Name: "Mina_libp2p_message_validation_time_ns",
	Help: "Message validation time",
})

func init() {
	// === Register metrics collectors here ===
	prometheus.MustRegister(connectionCountMetric)
	prometheus.MustRegister(validationTimeoutMetric)
	prometheus.MustRegister(validationTimeMetric)
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

	setLogLevel := func(name, level string) {
		err := logging.SetLogLevel(name, level)
		if err != nil {
			helperLog.Errorf("failed to set log level %s for %s: %v", level, name, err)
		}
	}

	// === Set subsystem log levels ===
	// All subsystems that have been considered are explicitly listed. Any that
	// are added when modifying this code should be considered and added to
	// this list.
	// The levels below set the **minimum** log level for each subsystem.
	// Messages emitted at lower levels than the given level will not be
	// emitted.
	setLogLevel("mplex", "debug")
	setLogLevel("addrutil", "info")     // Logs every resolve call at debug
	setLogLevel("net/identify", "info") // Logs every message sent/received at debug
	setLogLevel("ping", "info")         // Logs every ping timeout at debug
	setLogLevel("basichost", "info")    // Spammy at debug
	setLogLevel("test-logger", "debug")
	setLogLevel("blankhost", "debug")
	setLogLevel("connmgr", "debug")
	setLogLevel("eventlog", "debug")
	setLogLevel("p2p-config", "debug")
	setLogLevel("ipns", "debug")
	setLogLevel("nat", "debug")
	setLogLevel("autorelay", "info") // Logs relayed byte counts spammily
	setLogLevel("providers", "debug")
	setLogLevel("dht/RtRefreshManager", "warn") // Ping logs are spammy at debug, cpl logs are spammy at info
	setLogLevel("dht", "info")                  // Logs every operation to debug
	setLogLevel("peerstore", "debug")
	setLogLevel("diversityFilter", "debug")
	setLogLevel("table", "debug")
	setLogLevel("stream-upgrader", "debug")
	setLogLevel("helper top-level JSON handling", "debug")
	setLogLevel("dht.pb", "debug")
	setLogLevel("tcp-tpt", "debug")
	setLogLevel("autonat", "debug")
	setLogLevel("discovery", "debug")
	setLogLevel("routing/record", "debug")
	setLogLevel("pubsub", "info")
	setLogLevel("badger", "debug")
	setLogLevel("relay", "info") // Log relayed byte counts spammily
	setLogLevel("routedhost", "debug")
	setLogLevel("swarm2", "info") // Logs a new stream to each peer when opended at debug
	setLogLevel("peerstore/ds", "debug")
	setLogLevel("mdns", "debug") // Logs each mdns call
	setLogLevel("reuseport-transport", "debug")

	decoder := capnp.NewDecoder(os.Stdin)

	app := newApp()

	go func() {
		for {
			msg := <-app.OutChan
			bytes, err := msg.Marshal()
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

			if err := app.Out.Flush(); err != nil {
				panic(err)
			}
		}
	}()

	defer func() {
		if r := recover(); r != nil {
			helperLog.Error("The following panic occurred: ", r, "\nstack:\n", string(debug.Stack()))
		}
	}()

	go app.bitswapCtx.Loop()

	for {
		rawMsg, err := decoder.Decode()
		if err != nil {
			helperLog.Errorf("Error decoding raw message: %w", err)
			os.Exit(2)
			return
		}
		msg, err := ipc.ReadRootLibp2pHelperInterface_Message(rawMsg)
		if err != nil {
			helperLog.Errorf("Error decoding capnp message: %w", err)
			os.Exit(3)
			return
		}

		go app.handleIncomingMsg(&msg)
	}
}
