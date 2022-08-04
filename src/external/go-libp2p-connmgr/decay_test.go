package connmgr

import (
	"testing"
	"time"

	"github.com/libp2p/go-libp2p-core/connmgr"
	"github.com/libp2p/go-libp2p-core/peer"
	tu "github.com/libp2p/go-libp2p-core/test"
	"github.com/stretchr/testify/require"

	"github.com/benbjohnson/clock"
)

const TestResolution = 50 * time.Millisecond

func TestDecayExpire(t *testing.T) {
	var (
		id                    = tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
	)

	tag, err := decay.RegisterDecayingTag("pop", 250*time.Millisecond, connmgr.DecayExpireWhenInactive(1*time.Second), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	err = tag.Bump(id, 10)
	if err != nil {
		t.Fatal(err)
	}

	// give time for the bump command to process.
	<-time.After(100 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 10 {
		t.Fatalf("wrong value; expected = %d; got = %d", 10, v)
	}

	mockClock.Add(250 * time.Millisecond)
	mockClock.Add(250 * time.Millisecond)
	mockClock.Add(250 * time.Millisecond)
	mockClock.Add(250 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 0 {
		t.Fatalf("wrong value; expected = %d; got = %d", 0, v)
	}
}

func TestMultipleBumps(t *testing.T) {
	var (
		id            = tu.RandPeerIDFatal(t)
		mgr, decay, _ = testDecayTracker(t)
	)

	tag, err := decay.RegisterDecayingTag("pop", 250*time.Millisecond, connmgr.DecayExpireWhenInactive(1*time.Second), connmgr.BumpSumBounded(10, 20))
	if err != nil {
		t.Fatal(err)
	}

	err = tag.Bump(id, 5)
	if err != nil {
		t.Fatal(err)
	}

	<-time.After(100 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 10 {
		t.Fatalf("wrong value; expected = %d; got = %d", 10, v)
	}

	err = tag.Bump(id, 100)
	if err != nil {
		t.Fatal(err)
	}

	<-time.After(100 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 20 {
		t.Fatalf("wrong value; expected = %d; got = %d", 20, v)
	}
}

func TestMultipleTagsNoDecay(t *testing.T) {
	var (
		id            = tu.RandPeerIDFatal(t)
		mgr, decay, _ = testDecayTracker(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", 250*time.Millisecond, connmgr.DecayNone(), connmgr.BumpSumBounded(0, 100))
	if err != nil {
		t.Fatal(err)
	}

	tag2, err := decay.RegisterDecayingTag("bop", 250*time.Millisecond, connmgr.DecayNone(), connmgr.BumpSumBounded(0, 100))
	if err != nil {
		t.Fatal(err)
	}

	tag3, err := decay.RegisterDecayingTag("foo", 250*time.Millisecond, connmgr.DecayNone(), connmgr.BumpSumBounded(0, 100))
	if err != nil {
		t.Fatal(err)
	}

	_ = tag1.Bump(id, 100)
	_ = tag2.Bump(id, 100)
	_ = tag3.Bump(id, 100)
	_ = tag1.Bump(id, 100)
	_ = tag2.Bump(id, 100)
	_ = tag3.Bump(id, 100)

	<-time.After(500 * time.Millisecond)

	// all tags are upper-bounded, so the score must be 300
	ti := mgr.GetTagInfo(id)
	if v := ti.Value; v != 300 {
		t.Fatalf("wrong value; expected = %d; got = %d", 300, v)
	}

	for _, s := range []string{"beep", "bop", "foo"} {
		if v, ok := ti.Tags[s]; !ok || v != 100 {
			t.Fatalf("expected tag %s to be 100; was = %d", s, v)
		}
	}
}

func TestCustomFunctions(t *testing.T) {
	var (
		id                    = tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", 250*time.Millisecond, connmgr.DecayFixed(10), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	tag2, err := decay.RegisterDecayingTag("bop", 100*time.Millisecond, connmgr.DecayFixed(5), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	tag3, err := decay.RegisterDecayingTag("foo", 50*time.Millisecond, connmgr.DecayFixed(1), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	_ = tag1.Bump(id, 1000)
	_ = tag2.Bump(id, 1000)
	_ = tag3.Bump(id, 1000)

	<-time.After(500 * time.Millisecond)

	// no decay has occurred yet, so score must be 3000.
	if v := mgr.GetTagInfo(id).Value; v != 3000 {
		t.Fatalf("wrong value; expected = %d; got = %d", 3000, v)
	}

	// only tag3 should tick.
	mockClock.Add(50 * time.Millisecond)
	if v := mgr.GetTagInfo(id).Value; v != 2999 {
		t.Fatalf("wrong value; expected = %d; got = %d", 2999, v)
	}

	// tag3 will tick thrice, tag2 will tick twice.
	mockClock.Add(150 * time.Millisecond)
	if v := mgr.GetTagInfo(id).Value; v != 2986 {
		t.Fatalf("wrong value; expected = %d; got = %d", 2986, v)
	}

	// tag3 will tick once, tag1 will tick once.
	mockClock.Add(50 * time.Millisecond)
	if v := mgr.GetTagInfo(id).Value; v != 2975 {
		t.Fatalf("wrong value; expected = %d; got = %d", 2975, v)
	}
}

func TestMultiplePeers(t *testing.T) {
	var (
		ids                   = []peer.ID{tu.RandPeerIDFatal(t), tu.RandPeerIDFatal(t), tu.RandPeerIDFatal(t)}
		mgr, decay, mockClock = testDecayTracker(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", 250*time.Millisecond, connmgr.DecayFixed(10), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	tag2, err := decay.RegisterDecayingTag("bop", 100*time.Millisecond, connmgr.DecayFixed(5), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	tag3, err := decay.RegisterDecayingTag("foo", 50*time.Millisecond, connmgr.DecayFixed(1), connmgr.BumpSumUnbounded())
	if err != nil {
		t.Fatal(err)
	}

	_ = tag1.Bump(ids[0], 1000)
	_ = tag2.Bump(ids[0], 1000)
	_ = tag3.Bump(ids[0], 1000)

	_ = tag1.Bump(ids[1], 500)
	_ = tag2.Bump(ids[1], 500)
	_ = tag3.Bump(ids[1], 500)

	_ = tag1.Bump(ids[2], 100)
	_ = tag2.Bump(ids[2], 100)
	_ = tag3.Bump(ids[2], 100)

	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	mockClock.Add(3 * time.Second)

	// allow the background goroutine to process ticks.
	<-time.After(500 * time.Millisecond)

	if v := mgr.GetTagInfo(ids[0]).Value; v != 2670 {
		t.Fatalf("wrong value; expected = %d; got = %d", 2670, v)
	}

	if v := mgr.GetTagInfo(ids[1]).Value; v != 1170 {
		t.Fatalf("wrong value; expected = %d; got = %d", 1170, v)
	}

	if v := mgr.GetTagInfo(ids[2]).Value; v != 40 {
		t.Fatalf("wrong value; expected = %d; got = %d", 40, v)
	}
}

func TestLinearDecayOverwrite(t *testing.T) {
	var (
		id                    = tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", 250*time.Millisecond, connmgr.DecayLinear(0.5), connmgr.BumpOverwrite())
	if err != nil {
		t.Fatal(err)
	}

	_ = tag1.Bump(id, 1000)
	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	mockClock.Add(250 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 500 {
		t.Fatalf("value should be half; got = %d", v)
	}

	mockClock.Add(250 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 250 {
		t.Fatalf("value should be half; got = %d", v)
	}

	_ = tag1.Bump(id, 1000)
	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	if v := mgr.GetTagInfo(id).Value; v != 1000 {
		t.Fatalf("value should 1000; got = %d", v)
	}
}

func TestResolutionMisaligned(t *testing.T) {
	var (
		id                    = tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
		require               = require.New(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", time.Duration(float64(TestResolution)*1.4), connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	tag2, err := decay.RegisterDecayingTag("bop", time.Duration(float64(TestResolution)*2.4), connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	_ = tag1.Bump(id, 1000)
	_ = tag2.Bump(id, 1000)
	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	// first tick.
	mockClock.Add(TestResolution)
	require.Equal(1000, mgr.GetTagInfo(id).Tags["beep"])
	require.Equal(1000, mgr.GetTagInfo(id).Tags["bop"])

	// next tick; tag1 would've ticked.
	mockClock.Add(TestResolution)
	require.Equal(999, mgr.GetTagInfo(id).Tags["beep"])
	require.Equal(1000, mgr.GetTagInfo(id).Tags["bop"])

	// next tick; tag1 would've ticked twice, tag2 once.
	mockClock.Add(TestResolution)
	require.Equal(998, mgr.GetTagInfo(id).Tags["beep"])
	require.Equal(999, mgr.GetTagInfo(id).Tags["bop"])

	require.Equal(1997, mgr.GetTagInfo(id).Value)
}

func TestTagRemoval(t *testing.T) {
	var (
		id1, id2              = tu.RandPeerIDFatal(t), tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
		require               = require.New(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", TestResolution, connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	tag2, err := decay.RegisterDecayingTag("bop", TestResolution, connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	// id1 has both tags; id2 only has the first tag.
	_ = tag1.Bump(id1, 1000)
	_ = tag2.Bump(id1, 1000)
	_ = tag1.Bump(id2, 1000)

	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	// first tick.
	mockClock.Add(TestResolution)
	require.Equal(999, mgr.GetTagInfo(id1).Tags["beep"])
	require.Equal(999, mgr.GetTagInfo(id1).Tags["bop"])
	require.Equal(999, mgr.GetTagInfo(id2).Tags["beep"])

	require.Equal(999*2, mgr.GetTagInfo(id1).Value)
	require.Equal(999, mgr.GetTagInfo(id2).Value)

	// remove tag1 from p1.
	err = tag1.Remove(id1)

	// allow the background goroutine to process the removal.
	<-time.After(500 * time.Millisecond)
	require.NoError(err)

	// next tick. both peers only have 1 tag, both at 998 value.
	mockClock.Add(TestResolution)
	require.Zero(mgr.GetTagInfo(id1).Tags["beep"])
	require.Equal(998, mgr.GetTagInfo(id1).Tags["bop"])
	require.Equal(998, mgr.GetTagInfo(id2).Tags["beep"])

	require.Equal(998, mgr.GetTagInfo(id1).Value)
	require.Equal(998, mgr.GetTagInfo(id2).Value)

	// remove tag1 from p1 again; no error.
	err = tag1.Remove(id1)
	require.NoError(err)
}

func TestTagClosure(t *testing.T) {
	var (
		id                    = tu.RandPeerIDFatal(t)
		mgr, decay, mockClock = testDecayTracker(t)
		require               = require.New(t)
	)

	tag1, err := decay.RegisterDecayingTag("beep", TestResolution, connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	tag2, err := decay.RegisterDecayingTag("bop", TestResolution, connmgr.DecayFixed(1), connmgr.BumpOverwrite())
	require.NoError(err)

	_ = tag1.Bump(id, 1000)
	_ = tag2.Bump(id, 1000)
	// allow the background goroutine to process bumps.
	<-time.After(500 * time.Millisecond)

	// nothing has happened.
	mockClock.Add(TestResolution)
	require.Equal(999, mgr.GetTagInfo(id).Tags["beep"])
	require.Equal(999, mgr.GetTagInfo(id).Tags["bop"])
	require.Equal(999*2, mgr.GetTagInfo(id).Value)

	// next tick; tag1 would've ticked.
	mockClock.Add(TestResolution)
	require.Equal(998, mgr.GetTagInfo(id).Tags["beep"])
	require.Equal(998, mgr.GetTagInfo(id).Tags["bop"])
	require.Equal(998*2, mgr.GetTagInfo(id).Value)

	// close the tag.
	err = tag1.Close()
	require.NoError(err)

	// allow the background goroutine to process the closure.
	<-time.After(500 * time.Millisecond)
	require.Equal(998, mgr.GetTagInfo(id).Value)

	// a second closure should not error.
	err = tag1.Close()
	require.NoError(err)

	// bumping a tag after it's been closed should error.
	err = tag1.Bump(id, 5)
	require.Error(err)
}

func testDecayTracker(tb testing.TB) (*BasicConnMgr, connmgr.Decayer, *clock.Mock) {
	mockClock := clock.NewMock()
	cfg := &DecayerCfg{
		Resolution: TestResolution,
		Clock:      mockClock,
	}

	mgr := NewConnManager(10, 10, 1*time.Second, DecayerConfig(cfg))
	decay, ok := connmgr.SupportsDecay(mgr)
	if !ok {
		tb.Fatalf("connmgr does not support decay")
	}

	return mgr, decay, mockClock
}
