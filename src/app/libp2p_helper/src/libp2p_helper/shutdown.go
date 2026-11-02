package main

import (
	"os"
	"os/signal"
	"syscall"
	"time"

	logging "github.com/ipfs/go-log/v2"
)

var shutdownLog = logging.Logger("helper shutdown")

// helperCloseTimeout bounds how long shutdown waits for the helper to close,
// so that a stuck close cannot keep the process alive.
const helperCloseTimeout = 5 * time.Second

// closeHelper closes the configured helper, if there is one, giving up after
// helperCloseTimeout.
func (app *app) closeHelper() {
	if app.P2p == nil {
		return
	}
	done := make(chan error, 1)
	go func() { done <- app.P2p.Close() }()
	select {
	case err := <-done:
		if err != nil {
			shutdownLog.Errorf("Error closing helper: %s", err)
		}
	case <-time.After(helperCloseTimeout):
		shutdownLog.Errorf("Timed out closing helper after %s", helperCloseTimeout)
	}
}

// closeHelperOnSignal closes the helper when the process receives SIGTERM or
// SIGINT, and then dies of the same signal, so that the daemon still sees the
// helper killed by a signal rather than exiting by itself.
func (app *app) closeHelperOnSignal() {
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		sig := <-sigs
		shutdownLog.Infof("Received %s, closing helper", sig)
		app.closeHelper()
		signal.Reset(sig)
		if err := syscall.Kill(os.Getpid(), sig.(syscall.Signal)); err != nil {
			shutdownLog.Errorf("Error re-raising %s: %s", sig, err)
			os.Exit(1)
		}
	}()
}
