package config

import "testing"

// Representative node names for exercising InitDaemonInfos in isolation (the real
// set is now chosen by the mln sampler and read back from the plan). The seed
// deliberately does not sort first, so a positional assumption about it shows up
// here.
var (
	testSeed  = "whale-seed+bp+coordinator-0"
	testNodes = []string{"plain-2", "whale-bp-1", testSeed}
)

func testConfig(t *testing.T, methods ...string) *Config {
	t.Helper()
	cfg := DefaultConfig()
	for _, m := range methods {
		if err := cfg.ForkMethods.Set(m); err != nil {
			t.Fatalf("failed to set fork method %q: %v", m, err)
		}
	}
	return cfg
}

func TestDaemonInfosComeFromTopologyNodes(t *testing.T) {
	cfg := testConfig(t, "legacy")
	if err := cfg.InitDaemonInfos(testNodes, testSeed); err != nil {
		t.Fatalf("InitDaemonInfos failed: %v", err)
	}

	if len(cfg.DaemonInfos) != len(testNodes) {
		t.Fatalf("got %d daemons, want %d", len(cfg.DaemonInfos), len(testNodes))
	}
	for i, name := range testNodes {
		if cfg.DaemonInfos[i].Name != name {
			t.Errorf("daemon %d = %q, want %q", i, cfg.DaemonInfos[i].Name, name)
		}
	}
}

func TestInitDaemonInfosRejectsUnknownSeed(t *testing.T) {
	cfg := testConfig(t, "legacy")
	if err := cfg.InitDaemonInfos(testNodes, "not-a-node"); err == nil {
		t.Fatal("InitDaemonInfos accepted a seed that is not among the nodes")
	}
}

// The seed is the sole P2P hub: if it takes the Auto method it exits at
// slot-chain-end and the rest of the network loses its seed. The guard must key
// off the seed's name — the daemon list is sorted, so the seed is not first,
// and a positional guard would protect the wrong daemon.
func TestSeedNeverGetsAutoForkMethod(t *testing.T) {
	cfg := testConfig(t, "legacy", "advanced", "auto")

	if testNodes[0] == testSeed {
		t.Fatal("test setup is wrong: the seed must not sort first for this to be meaningful")
	}

	for i := 0; i < 200; i++ {
		if err := cfg.InitDaemonInfos(testNodes, testSeed); err != nil {
			t.Fatalf("InitDaemonInfos failed: %v", err)
		}
		for _, di := range cfg.DaemonInfos {
			if di.Name == testSeed && di.ForkMethod == Auto {
				t.Fatalf("seed %q got Auto fork method on iteration %d", testSeed, i)
			}
		}
	}
}

// Every requested method must reach at least one daemon, or the fork path it
// covers goes untested.
func TestEveryForkMethodIsAssigned(t *testing.T) {
	cfg := testConfig(t, "legacy", "advanced", "auto")

	for i := 0; i < 50; i++ {
		if err := cfg.InitDaemonInfos(testNodes, testSeed); err != nil {
			t.Fatalf("InitDaemonInfos failed: %v", err)
		}
		seen := map[ForkMethod]bool{}
		for _, di := range cfg.DaemonInfos {
			seen[di.ForkMethod] = true
		}
		for _, m := range cfg.ForkMethods.Methods() {
			if !seen[m] {
				t.Fatalf("fork method %v was assigned to no daemon on iteration %d", m, i)
			}
		}
	}
}

// Three methods do not fit two daemons; this is why the mixed job has its own
// three-node topology.
func TestMoreMethodsThanDaemonsIsRejected(t *testing.T) {
	cfg := testConfig(t, "legacy", "advanced", "auto")
	two := []string{"whale-bp-1", testSeed}
	if err := cfg.InitDaemonInfos(two, testSeed); err == nil {
		t.Fatal("InitDaemonInfos accepted 3 fork methods for 2 daemons")
	}
}

// Auto daemons exit at slot-chain-end, so an all-auto network leaves nothing
// alive for the post-fork checks.
func TestAllAutoIsRejected(t *testing.T) {
	cfg := testConfig(t, "auto")
	if err := cfg.InitDaemonInfos(testNodes, testSeed); err == nil {
		t.Fatal("InitDaemonInfos accepted an all-auto method set")
	}
}

func TestNoForkMethodIsRejected(t *testing.T) {
	cfg := testConfig(t)
	if err := cfg.InitDaemonInfos(testNodes, testSeed); err == nil {
		t.Fatal("InitDaemonInfos accepted an empty method set")
	}
}

func TestNodeDirRel(t *testing.T) {
	di := DaemonInfo{Name: "plain-2"}
	if got, want := di.NodeDirRel("/root"), "/root/nodes/plain-2"; got != want {
		t.Errorf("NodeDirRel = %q, want %q", got, want)
	}
}
