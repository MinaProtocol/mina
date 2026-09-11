package main

import (
	"os"
	"testing"
	"time"

	net "github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/stretchr/testify/require"
)

// stallingStream stands in for a peer that has stopped reading: every write
// runs out the deadline the caller set and fails, the way a libp2p stream
// does once the muxer's flow control window is exhausted.
type stallingStream struct {
	net.Stream
	writeDeadline time.Time
	closed        bool
}

func (s *stallingStream) SetWriteDeadline(t time.Time) error {
	s.writeDeadline = t
	return nil
}

func (s *stallingStream) Write(p []byte) (int, error) {
	if s.writeDeadline.IsZero() {
		// No deadline: a real stream would block here forever.
		select {}
	}
	return 0, os.ErrDeadlineExceeded
}

func (s *stallingStream) Close() error {
	s.closed = true
	return nil
}

func (s *stallingStream) Reset() error                  { return nil }
func (s *stallingStream) ID() string                    { return "stalling" }
func (s *stallingStream) Protocol() protocol.ID         { return "" }
func (s *stallingStream) Conn() net.Conn                { return nil }
func (s *stallingStream) Stat() net.Stats               { return net.Stats{} }
func (s *stallingStream) Scope() net.StreamScope        { return nil }
func (s *stallingStream) SetProtocol(protocol.ID) error { return nil }
func (s *stallingStream) RemotePeer() peer.ID           { return "" }

// Regression test: WriteStream must bound its write with a deadline. Without
// one a peer that stops reading blocks the caller indefinitely, holding both
// the stream mutex and a slot in the bounded worker pool.
func TestWriteStreamSetsWriteDeadline(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	peerStream := &stallingStream{}
	streamId := testApp.NextId()
	testApp.streamsMutex.Lock()
	testApp._streams[streamId] = &stream{stream: peerStream}
	testApp.streamsMutex.Unlock()

	before := time.Now()
	err := testApp.WriteStream(streamId, []byte("payload"))
	require.Error(t, err, "a stalled write must fail rather than block")

	require.False(t, peerStream.writeDeadline.IsZero(), "no write deadline was set")
	require.WithinDuration(t, before.Add(StreamWriteTimeout), peerStream.writeDeadline, time.Minute)

	// A failed write retires the stream.
	_, stillThere := testApp.getStream(streamId)
	require.False(t, stillThere, "stream must be removed after a write failure")
	require.True(t, peerStream.closed, "stream must be closed after a write failure")
}
