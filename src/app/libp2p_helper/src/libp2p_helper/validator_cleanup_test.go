package main

import (
	"testing"
	"time"

	logging "github.com/ipfs/go-log/v2"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/stretchr/testify/require"
)

func newValidatorTestApp() *app {
	return &app{_validators: make(map[uint64]*validationStatus)}
}

// Regression test: validators whose grace period elapsed after timing out
// must be swept; ones inside the grace period must be kept.
func TestCleanupTimedOutValidatorsAfterGrace(t *testing.T) {
	testApp := newValidatorTestApp()

	staleSeqno, _ := testApp.AddValidator()
	freshSeqno, _ := testApp.AddValidator()
	pendingSeqno, _ := testApp.AddValidator()

	stale := time.Now().Add(-ValidatorCleanupGrace - time.Minute)
	testApp._validators[staleSeqno].TimedOutAt = &stale
	testApp.TimeoutValidator(freshSeqno)

	testApp.cleanupTimedOutValidators(logging.Logger("test"))

	_, staleFound := testApp._validators[staleSeqno]
	require.False(t, staleFound, "validator past its grace period must be removed")
	_, freshFound := testApp._validators[freshSeqno]
	require.True(t, freshFound, "recently timed-out validator must be kept")
	_, pendingFound := testApp._validators[pendingSeqno]
	require.True(t, pendingFound, "pending validator must be kept")
}

// Regression test: a Validation push arriving after the validate goroutine
// timed out (and stopped receiving) must not block the sender forever. A
// permanently blocked sender leaks the goroutine handling the push.
func TestLateValidationPushSendDoesNotBlock(t *testing.T) {
	testApp := newValidatorTestApp()

	seqno, _ := testApp.AddValidator()
	// The validate goroutine timed out and returned: nobody receives.
	testApp.TimeoutValidator(seqno)

	// A late Validation push arrives from the daemon.
	st, found := testApp.RemoveValidator(seqno)
	require.True(t, found)
	sent := make(chan struct{})
	go func() {
		st.Completion <- pubsub.ValidationAccept
		close(sent)
	}()
	select {
	case <-sent:
	case <-time.After(2 * time.Second):
		t.Fatal("late validation send blocked; Completion channel must be buffered")
	}
}

// Regression test: a Validation push can remove a validator entry in the
// window between the validate goroutine observing ctx.Done() and calling
// TimeoutValidator. Marking a missing entry must not panic.
func TestTimeoutValidatorAfterRemovalDoesNotPanic(t *testing.T) {
	testApp := newValidatorTestApp()

	seqno, _ := testApp.AddValidator()
	_, found := testApp.RemoveValidator(seqno)
	require.True(t, found)

	require.NotPanics(t, func() { testApp.TimeoutValidator(seqno) })
}

func TestInitDurationEnvRejectsInvalid(t *testing.T) {
	def := 42 * time.Second
	t.Setenv("LIBP2P_TEST_DURATION_ENV", "bogus")
	require.Equal(t, def, initDurationEnv("LIBP2P_TEST_DURATION_ENV", def))
	t.Setenv("LIBP2P_TEST_DURATION_ENV", "-5s")
	require.Equal(t, def, initDurationEnv("LIBP2P_TEST_DURATION_ENV", def))
	t.Setenv("LIBP2P_TEST_DURATION_ENV", "0s")
	require.Equal(t, def, initDurationEnv("LIBP2P_TEST_DURATION_ENV", def))
	t.Setenv("LIBP2P_TEST_DURATION_ENV", "90s")
	require.Equal(t, 90*time.Second, initDurationEnv("LIBP2P_TEST_DURATION_ENV", def))
}
