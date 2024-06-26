package delegation_backend

import "sync"

type Whitelist map[Pk]struct{}

type WhitelistMVar struct {
	whitelistMutex sync.RWMutex
	whitelistSet   Whitelist
}

func (mvar *WhitelistMVar) Replace(wl Whitelist) {
	mvar.whitelistMutex.Lock()
	defer mvar.whitelistMutex.Unlock()
	mvar.whitelistSet = wl
}

func (mvar *WhitelistMVar) ReadWhitelist() (wl Whitelist) {
	mvar.whitelistMutex.RLock()
	defer mvar.whitelistMutex.RUnlock()
	return mvar.whitelistSet
}
