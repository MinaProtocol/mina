package connmgr

import "time"

// BasicConnManagerConfig is the configuration struct for the basic connection
// manager.
type BasicConnManagerConfig struct {
	highWater     int
	lowWater      int
	gracePeriod   time.Duration
	silencePeriod time.Duration
	decayer       *DecayerCfg
}

// Option represents an option for the basic connection manager.
type Option func(*BasicConnManagerConfig) error

// DecayerConfig applies a configuration for the decayer.
func DecayerConfig(opts *DecayerCfg) Option {
	return func(cfg *BasicConnManagerConfig) error {
		cfg.decayer = opts
		return nil
	}
}
