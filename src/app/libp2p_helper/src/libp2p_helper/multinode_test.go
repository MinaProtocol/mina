package main

import (
	"bytes"
	"context"
	"fmt"
	"io/ioutil"
	ipc "libp2p_ipc"
	"math/rand"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	logging "github.com/ipfs/go-log/v2"
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/peer"
	kb "github.com/libp2p/go-libp2p-kbucket"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/stretchr/testify/require"
)

const (
	CONNS_LO   = 2
	CONNS_HI   = 15
	PUBSUB_D   = 4
	PUBSUB_Dlo = 1
	PUBSUB_Dhi = 6
)

type testNode struct {
	node *app
	trap *upcallTrap
}

func beginAdvertisingOnNodes(t *testing.T, nodes []testNode) {
	resultChan := make(chan *capnp.Message)
	_ = resultChan
	var resMsgErr error
	for _, n := range nodes {
		var resMsg *capnp.Message
		resMsg, err := beginAdvertisingSendAndCheckDo(n.node, 123)
		if err != nil {
			resMsgErr = err
		}
		n.node.P2p.Logger.Debug("beginAdvertising: got response")
		require.NoError(t, resMsgErr)
		checkBeginAdvertisingResponse(t, 123, resMsg)
	}
}

func initNodes(t *testing.T, numNodes int, upcallMask uint32) ([]testNode, []context.CancelFunc) {
	nodes := make([]testNode, numNodes)
	cancels := make([]context.CancelFunc, numNodes)
	keys := make([]crypto.PrivKey, numNodes)
	ids := make([]kb.ID, numNodes)
	for ni := 0; ni < numNodes; ni++ {
		keys[ni] = newTestKey(t)
		pid, err := peer.IDFromPrivateKey(keys[ni])
		require.NoError(t, err)
		ids[ni] = kb.ConvertPeerID(pid)
	}
	errChan := make(chan error, numNodes)
	topCtx, topCtxCancel := context.WithCancel(context.Background())
	for ni := range nodes {
		trap := newUpcallTrap(fmt.Sprintf("node %d", ni), 64, upcallMask)
		ctx, cancelF := context.WithCancel(topCtx)
		cancels[ni] = cancelF
		node := newTestAppWithMaxConnsAndCtx(t, keys[ni], nil, false, CONNS_LO, CONNS_HI, .2, nextPort(), ctx)
		node.NoMDNS = true
		node.P2p.Logger = logging.Logger(fmt.Sprintf("node%d", ni))
		node.SetConnectionHandlers()
		launchFeedUpcallTrap(node.P2p.Logger, node.OutChan, trap, errChan, ctx)
		nodes[ni].node = node
		nodes[ni].trap = trap
	}
	handleErrChan(t, errChan, topCtxCancel)
	return nodes, cancels
}

func iteratePrevNextPeers(t *testing.T, nodes []testNode, f func(node testNode, ni int, prev, next peer.AddrInfo)) {
	numNodes := len(nodes)
	for ni, node := range nodes {
		prevInfos, err := addrInfos(nodes[(ni-1+numNodes)%numNodes].node.P2p.Host)
		require.NoError(t, err)
		nextInfos, err := addrInfos(nodes[(ni+1)%numNodes].node.P2p.Host)
		require.NoError(t, err)
		f(node, ni, prevInfos[0], nextInfos[0])
	}

}

func connectRingTopology(t *testing.T, nodes []testNode, protect bool) {
	iteratePrevNextPeers(t, nodes, func(node testNode, _ int, prev, next peer.AddrInfo) {
		testAddPeerImplDo(t, node.node, next, true)
		// to ensure connectivity is not lost
		if protect {
			node.node.P2p.ConnectionManager.Protect(next.ID, "seed")
			node.node.P2p.ConnectionManager.Protect(prev.ID, "seed")
		}
	})
}

func testBroadcast(t *testing.T, nodes []testNode, sender *app, timeout time.Duration, topic string, msg []byte) {
	sender.P2p.Logger.Infof("Sending broadcast message")
	testPublishDo(t, sender, topic, msg, 102)
	ctx, cancelF := context.WithTimeout(context.Background(), timeout)
	defer cancelF()
	counter := int32(len(nodes))
	grError := make(chan error)
	for _, n := range nodes {
		if n.node.P2p.Me == sender.P2p.Me {
			nc := atomic.AddInt32(&counter, -1)
			n.node.P2p.Logger.Infof("Skipping sender: %d remained", nc)
			if nc == 0 {
				cancelF()
			}
			continue
		}
		go func(n testNode) {
			select {
			case <-ctx.Done():
			case gr := <-n.trap.GossipReceived:
				err := func() error {
					bs, err := gr.Data()
					if err != nil {
						return err
					}
					if !bytes.Equal(bs, msg) {
						return fmt.Errorf("Unexpected gossip on %s: %s", n.node.P2p.Me.Pretty(), string(bs))
					}
					vid, err := gr.ValidationId()
					if err != nil {
						return err
					}
					_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
					if err != nil {
						return err
					}
					m, err := ipc.NewRootLibp2pHelperInterface_Validation(seg)
					if err != nil {
						return err
					}
					m.SetValidationId(vid)
					m.SetResult(ipc.ValidationResult_accept)
					ValidationPush(m).handle(n.node)
					return nil
				}()
				if err != nil {
					grError <- err
					return
				}
				nc := atomic.AddInt32(&counter, -1)
				n.node.P2p.Logger.Infof("Received broadcast message: %d remained", nc)
				if nc == 0 {
					cancelF()
				}
			}
		}(n)
	}
	select {
	case <-ctx.Done():
		require.Equal(t, context.Canceled, ctx.Err())
	case err := <-grError:
		t.Fatal(err)
	}
}

type messageWithPeerId interface {
	PeerId() (ipc.PeerId, error)
}

func LogConnections(nodes []testNode, status map[int]map[int]bool, lock *sync.Mutex) context.CancelFunc {
	ctx, cancelF := context.WithCancel(context.Background())
	pidToIx := map[string]int{}
	for ni, n := range nodes {
		pid := n.node.P2p.Me.String()
		pidToIx[pid] = ni
	}
	getIx := func(m messageWithPeerId) (int, error) {
		pid_, err := m.PeerId()
		if err != nil {
			return -1, err
		}
		pid, err := pid_.Id()
		if err != nil {
			return -1, err
		}
		ix, has := pidToIx[pid]
		if !has {
			return -1, fmt.Errorf("unknown peer %s", pid)
		}
		return ix, nil
	}

	updateStatus := func(x, y int, st bool) (bool, int, int) {
		lock.Lock()
		defer lock.Unlock()
		if _, has := status[y]; !has {
			status[y] = make(map[int]bool)
		}
		if _, has := status[x]; !has {
			status[x] = make(map[int]bool)
		}
		st_, has := status[x][y]
		status[x][y] = st
		status[y][x] = st
		return !has || st_ != st, x, y
	}
	for ni, node := range nodes {
		ni_ := ni
		n := node
		go func() {
			for {
				select {
				case m := <-n.trap.PeerConnected:
					ix, err := getIx(m)
					if ok, x, y := updateStatus(ni_, ix, true); ok {
						n.node.P2p.Logger.Infof("%d ↔ %d %v", x, y, err)
					}
				case m := <-n.trap.PeerDisconnected:
					ix, err := getIx(m)
					if ok, x, y := updateStatus(ni_, ix, false); ok {
						n.node.P2p.Logger.Infof("%d ⊝ %d %v", x, y, err)
					}
				case <-ctx.Done():
					return
				}
			}
		}()
	}
	return cancelF
}

func printConnectionGraph(graph map[int]map[int]bool) {
	file, err := ioutil.TempFile("", "connections-*.dot")
	if err != nil {
		fmt.Println("Failed to create a tmp dot file")
		return
	}
	fmt.Printf("Writing to %s\n", file.Name())
	defer file.Close()
	file.WriteString(fmt.Sprintln("graph conns{"))
	for i, st := range graph {
		for j, has := range st {
			if j < i || !has {
				continue // print each edge only once, ignore false edges
			}
			file.WriteString(fmt.Sprintf("\tn%d -- n%d;\n", i, j))
		}
	}
	file.WriteString(fmt.Sprintln("}"))
}

func printPeers(nodes []testNode) {
	for _, n := range nodes {
		cm := n.node.P2p.ConnectionManager
		cm.ViewProtected(func(m map[peer.ID]map[string]interface{}) {
			for _, peer := range n.node.P2p.Host.Network().Peers() {
				pm, has := m[peer]
				protectedTags := []string{}
				if has {
					for tag := range pm {
						protectedTags = append(protectedTags, tag)
					}
				}
				info := cm.GetTagInfo(peer)
				n.node.P2p.Logger.Infof("%s protected:%s info:%v", peer, strings.Join(protectedTags, ","), info)
			}
		})
	}
}

func trimConnections(nodes []testNode) {
	for _, n := range nodes {
		connMgr := n.node.P2p.ConnectionManager
		n.node.P2p.Logger.Infof("connmgr status: %v", connMgr.GetInfo())
		connMgr.TrimOpenConns(context.Background())
		n.node.P2p.Logger.Infof("connmgr status after trimming: %v", connMgr.GetInfo())
	}
}

func checkConnectionGraph(t *testing.T, numNodes int, connectionGraph map[int]map[int]bool, expectConnected bool) {
	visited := make([]bool, numNodes)
	// BFS traversal of connection graph
	for nextIx := 0; nextIx < numNodes; nextIx++ {
		if visited[nextIx] {
			continue
		}
		if nextIx > 0 && expectConnected {
			t.Errorf("Disconnected graph: at leats two roots 0 and %d", nextIx)
		}
		q := []int{nextIx}
		for ; len(q) > 0; q = q[1:] {
			n := q[0]
			if visited[n] {
				continue
			}
			visited[n] = true
			st, hasSt := connectionGraph[n]
			if !hasSt {
				continue
			}
			childCount := 0
			for m, c := range st {
				if !c {
					continue
				}
				childCount++
				q = append(q, m)
			}
			if childCount > CONNS_HI {
				t.Errorf("Node %d: %d connections exceed highwater %d", n, childCount, CONNS_HI)
			}
		}
	}
}

func buildConnectionGraph(nodes []testNode) map[int]map[int]bool {
	graph := make(map[int]map[int]bool)
	pidToIx := map[peer.ID]int{}
	for ni, n := range nodes {
		pid := n.node.P2p.Me
		pidToIx[pid] = ni
	}
	for ni, n := range nodes {
		for _, pid := range n.node.P2p.Host.Network().Peers() {
			pi, has := pidToIx[pid]
			if !has {
				pi = 1000
			}
			_, hasP := graph[pi]
			_, hasN := graph[ni]
			if !hasP {
				graph[pi] = make(map[int]bool)
			}
			if !hasN {
				graph[ni] = make(map[int]bool)
			}
			graph[pi][ni] = true
			graph[ni][pi] = true
		}
	}
	return graph
}

func TestBroadcastInNotFullConnectedNetwork(t *testing.T) {
	nodes, _ := initNodes(t, 10, upcallDropAllMask^(1<<GossipReceivedChan)^(1<<PeerConnectedChan)^(1<<PeerDisconnectedChan))
	// Connection graph is represented by map from node x to node y mapped to boolean (false entries are to be discraded)
	// invariant: connectionGraph[x][y] == connectionGraph[y][x]
	connectionGraph := make(map[int]map[int]bool)
	var lock sync.Mutex
	logCancel := LogConnections(nodes, connectionGraph, &lock)
	defer logCancel()
	// Parameters for mesh
	gossipSubp := pubsub.DefaultGossipSubParams()
	gossipSubp.D = PUBSUB_D
	gossipSubp.Dlo = PUBSUB_Dlo
	gossipSubp.Dhi = PUBSUB_Dhi
	iteratePrevNextPeers(t, nodes, func(n testNode, _ int, prev, next peer.AddrInfo) {
		configurePubsub(n.node, 100, []peer.AddrInfo{next, prev}, nil,
			pubsub.WithGossipSubParams(gossipSubp))
		testSubscribeDo(t, n.node, "test", 0, 101)
	})
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	time.Sleep(11 * time.Second) // wait for network topology to stabilize
	trimConnections(nodes)
	lock.Lock()
	checkConnectionGraph(t, len(nodes), connectionGraph, true)
	if t.Failed() {
		printConnectionGraph(connectionGraph)
		printPeers(nodes)
	}
	lock.Unlock()
	r := rand.New(rand.NewSource(0))
	for i := 0; i < 3; i++ {
		time.Sleep(11 * time.Second)
		trimConnections(nodes)
		msg := []byte(fmt.Sprintf("msg %d", i))
		testBroadcast(t, nodes, nodes[r.Intn(len(nodes))].node, 2*time.Minute, "test", msg)
	}
}

func TestTwoTopicLevels(t *testing.T) {
	levels := topicLevelConf{
		"old/a": topicLevelEntry{1, 1},
		"new/b": topicLevelEntry{2, 2},
		"new/c": topicLevelEntry{2, 2},
		"old/d": topicLevelEntry{1, 2}, // topic that is available on both levels
	}
	oldN := 5  // number of old nodes
	newN := 13 // number of new nodes
	// `nodes`: <`oldN` old nodes><`len(nodes)-newN-oldN` regular nodes><`newN` new nodes>
	// we have the following node topology:
	// 	* regular nodes listen to both "new/b" and "old/a" topics and may connect to any topic
	//	* old nodes listen to "old/a" and may connect only to regular and old nodes
	//	* new nodes listen to both topics and may connect only to regular and new nodes
	//  * each regular node is connected to at least one old node
	//  * nodes are connected in a ring topology (except for link between last new and first old node, which is omitted)
	//  (i.e. each old node has each new node banned and vice versa)
	nodes, _ := initNodes(t, 30, upcallDropAllMask^(1<<GossipReceivedChan))
	// seds := []string{}
	// for ni, n := range nodes {
	// 	pid := n.node.P2p.Me.String()
	// 	seds = append(seds, fmt.Sprintf("sed 's/%s/node%d/g'", pid, ni))
	// }
	// fmt.Println(strings.Join(seds, " | "))
	newIds := make([]string, 0, newN)
	for _, n := range nodes[len(nodes)-newN:] {
		newIds = append(newIds, n.node.P2p.Me.String())
	}
	for _, n := range nodes[:oldN] {
		// ban all new nodes
		setGatingConfigImpl(t, n.node, nil, nil, nil, newIds)
	}
	gossipSubp := pubsub.DefaultGossipSubParams()
	gossipSubp.D = PUBSUB_D
	gossipSubp.Dlo = PUBSUB_Dlo
	gossipSubp.Dhi = PUBSUB_Dhi
	getNodeAddr := func(ni int) peer.AddrInfo {
		addr, err := addrInfos(nodes[ni].node.P2p.Host)
		require.NoError(t, err)
		return addr[0]
	}
	iteratePrevNextPeers(t, nodes, func(n testNode, ni int, prev, next peer.AddrInfo) {
		lvls := levels
		peers := []peer.AddrInfo{next, prev}
		if ni == len(nodes)-1 {
			peers = []peer.AddrInfo{prev}
		} else if ni == 0 {
			peers = []peer.AddrInfo{next}
		}
		if ni < oldN {
			lvls = nil
			for otherNodeI := ni + oldN; otherNodeI < len(nodes)-newN; otherNodeI += oldN {
				peers = append(peers, getNodeAddr(otherNodeI))
			}
		} else if ni < len(nodes)-newN {
			peers = append(peers, getNodeAddr(ni%oldN))
		}
		configurePubsub(n.node, 100, peers, lvls, pubsub.WithGossipSubParams(gossipSubp))
		if ni >= oldN {
			testSubscribeDo(t, n.node, "new/b", 1, 101)
		}
		testSubscribeDo(t, n.node, "old/a", 0, 101)
		testSubscribeDo(t, n.node, "old/d", 2, 101)
	})
	iteratePrevNextPeers(t, nodes, func(node testNode, ni int, prev, next peer.AddrInfo) {
		if ni < len(nodes)-1 {
			testAddPeerImplDo(t, node.node, next, true)
		}
		if ni >= oldN && ni < len(nodes)-newN {
			testAddPeerImplDo(t, node.node, getNodeAddr(ni%oldN), true)
		}
	})
	beginAdvertisingOnNodes(t, nodes)
	time.Sleep(11 * time.Second) // wait for network topology to stabilize
	trimConnections(nodes)
	r := rand.New(rand.NewSource(0))
	for i := 0; i < 10; i++ {
		t.Logf("Attempt %d: trim connections", i)
		time.Sleep(11 * time.Second)
		trimConnections(nodes)
		t.Logf("Attempt %d: message a", i)
		sender1 := nodes[r.Intn(len(nodes)-newN)].node
		testBroadcast(t, nodes[:len(nodes)-newN], sender1, 2*time.Minute, "old/a", []byte(fmt.Sprintf("a %d", i)))
		// Check that new nodes received no gossip
		for _, n := range nodes[len(nodes)-newN:] {
			select {
			case gr, h := <-n.trap.GossipReceived:
				if h {
					bs, _ := gr.Data()
					subId, _ := gr.SubscriptionId()
					t.Fatal("unexpected gossip", string(bs), subId.Id(), n.node.P2p.Me.String())
				}
			default:
			}
		}
		t.Logf("Attempt %d: message b", i)
		sender2 := nodes[r.Intn(len(nodes))].node
		testBroadcast(t, nodes[oldN:], sender2, 2*time.Minute, "new/b", []byte(fmt.Sprintf("b %d", i)))
		// Check that old nodes received no gossip
		for _, n := range nodes[:oldN] {
			select {
			case gr, h := <-n.trap.GossipReceived:
				if h {
					bs, _ := gr.Data()
					subId, _ := gr.SubscriptionId()
					t.Fatal("unexpected gossip", string(bs), subId.Id(), n.node.P2p.Me.String())
				}
			default:
			}
		}
		t.Logf("Attempt %d: message c", i)
		sender3 := nodes[r.Intn(len(nodes))].node
		testBroadcast(t, nodes, sender3, 2*time.Minute, "old/d", []byte(fmt.Sprintf("c %d", i)))
	}
}
