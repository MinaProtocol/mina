package main

import (
	"testing"

	logging "github.com/ipfs/go-log/v2"
	"github.com/stretchr/testify/require"
)

// Smoke test for the periodic leak monitor: exercises the lock/log paths
// both below and above the warning thresholds.
func TestReportCollectionSizes(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	seqno, _ := testApp.AddValidator()
	testApp.AddSubscription(1, subscription{})
	require.NotPanics(t, func() { testApp.reportCollectionSizes(logging.Logger("test")) })

	origWarn := LeakWarnValidators
	LeakWarnValidators = 0 // force the over-threshold warning branch
	defer func() { LeakWarnValidators = origWarn }()
	require.NotPanics(t, func() { testApp.reportCollectionSizes(logging.Logger("test")) })

	testApp.RemoveValidator(seqno)
	testApp.RemoveSubscription(1)
}
