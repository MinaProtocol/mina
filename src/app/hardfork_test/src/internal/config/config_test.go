package config

import "testing"

func TestPlainDaemonUsesMinaLocalNetworkPlainNaming(t *testing.T) {
	cfg := DefaultConfig()
	cfg.NumNodes = 1
	if err := cfg.ForkMethods.Set("legacy"); err != nil {
		t.Fatalf("failed to set fork method: %v", err)
	}
	if err := cfg.InitDaemonInfos(); err != nil {
		t.Fatalf("failed to initialize daemon infos: %v", err)
	}

	for _, daemon := range cfg.DaemonInfos {
		if daemon.Name == "plain_0" {
			if got, want := daemon.NodeDirRel("/root"), "/root/nodes/plain_0"; got != want {
				t.Fatalf("plain daemon dir = %q, want %q", got, want)
			}
			return
		}
	}
	t.Fatal("plain_0 daemon was not initialized")
}

func TestSeedNeverGetsAutoForkMethod(t *testing.T) {
	cfg := DefaultConfig()
	cfg.NumNodes = 1
	for _, method := range []string{"legacy", "advanced", "auto"} {
		if err := cfg.ForkMethods.Set(method); err != nil {
			t.Fatalf("failed to set fork method %q: %v", method, err)
		}
	}

	for i := 0; i < 100; i++ {
		if err := cfg.InitDaemonInfos(); err != nil {
			t.Fatalf("failed to initialize daemon infos: %v", err)
		}
		if got := cfg.DaemonInfos[0].ForkMethod; got == Auto {
			t.Fatalf("seed daemon got Auto fork method on iteration %d", i)
		}
	}
}
