package main

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"fmt"
	"io"
	"itn_json_types"
	"os"
	"time"

	"cloud.google.com/go/storage"
	logging "github.com/ipfs/go-log/v2"
	"go.uber.org/zap/zapcore"

	lib "itn_orchestrator"
)

var actions map[string]lib.Action

func init() {
	actions = map[string]lib.Action{
		"discovery":      lib.DiscoverParticipantsAction{},
		"payments":       lib.PaymentsAction{},
		"load-keys":      lib.KeyloaderAction{},
		"stop":           lib.StopAction{},
		"wait":           lib.WaitAction{},
		"fund-keys":      lib.FundAction{},
		"zkapp-txs":      lib.ZkappCommandsAction{},
		"slots-won":      lib.SlotsWonAction{},
		"reset-gating":   lib.ResetGatingAction{},
		"isolate":        lib.IsolateAction{},
		"allocate-slots": lib.AllocateSlotsAction{},
	}
}

type AppConfig struct {
	LogLevel         zapcore.Level `json:",omitempty"`
	LogFile          string        `json:",omitempty"`
	Key              itn_json_types.Ed25519Privkey
	UptimeBucket     string
	Daemon           string `json:",omitempty"`
	MinaExec         string `json:",omitempty"`
	SlotDurationMs   int
	GenesisTimestamp itn_json_types.Time
}

func loadAppConfig() (res AppConfig) {
	if len(os.Args) < 2 {
		os.Stderr.WriteString("No config provided")
		os.Exit(1)
		return
	}
	configFilename := os.Args[1]
	configFile, err := os.Open(configFilename)
	if err != nil {
		os.Stderr.WriteString(fmt.Sprintf("failed to load config %s: %v", configFilename, err))
		os.Exit(2)
		return
	}
	decoder := json.NewDecoder(configFile)
	if err = decoder.Decode(&res); err != nil {
		os.Stderr.WriteString(fmt.Sprintf("failed to decode config %s: %v", configFilename, err))
		os.Exit(3)
		return
	}
	return
}

func main() {
	appConfig := loadAppConfig()
	logging.SetupLogging(logging.Config{
		Format: logging.ColorizedOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LogLevel(appConfig.LogLevel),
		File:   appConfig.LogFile,
	})
	log := logging.Logger("itn orchestrator")
	log.Infof("Launching logging: %v", logging.GetSubsystems())

	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Errorf("Error creating Cloud client: %v", err)
		os.Exit(4)
		return
	}
	nodeData := make(map[lib.NodeAddress]lib.NodeEntry)
	config := lib.Config{
		Ctx:              ctx,
		UptimeBucket:     client.Bucket(appConfig.UptimeBucket),
		GetGqlClient:     lib.GetGqlClient(ed25519.PrivateKey(appConfig.Key), nodeData),
		Log:              log,
		Daemon:           appConfig.Daemon,
		MinaExec:         appConfig.MinaExec,
		NodeData:         nodeData,
		SlotDurationMs:   appConfig.SlotDurationMs,
		GenesisTimestamp: time.Time(appConfig.GenesisTimestamp),
	}
	if config.MinaExec == "" {
		config.MinaExec = "mina"
	}
	outCache := map[string]map[int]map[string]lib.OutputCacheEntry{
		"": {},
	}
	rconfig := lib.ResolutionConfig{
		OutputCache: outCache,
	}
	inDecoder := json.NewDecoder(os.Stdin)
	for step := 0; ; step++ {
		var cmd lib.Command
		if err := inDecoder.Decode(&cmd); err != nil {
			if err != io.EOF {
				log.Errorf("Error decoding command for step %d: %v", step, err)
				os.Exit(5)
			}
			break
		}
		params, err := lib.ResolveParams(rconfig, step, cmd.Params)
		if err != nil {
			log.Errorf("Error resolving params for step %d: %v", step, err)
			os.Exit(6)
			return
		}
		log.Infof("Performing step %s (%d)", cmd.Action, step)
		err = actions[cmd.Action].Run(config, params, func(name string, value_ any, multiple bool, sensitive bool) {
			value, err := json.Marshal(value_)
			if err != nil {
				log.Errorf("Error marshalling value %s for step %d: %v", name, step, err)
				os.Exit(7)
				return
			}
			if _, has := outCache[""][step]; !has {
				outCache[""][step] = map[string]lib.OutputCacheEntry{}
			}
			prev, has := outCache[""][step][name]
			if has {
				if multiple && prev.Multi {
					outCache[""][step][name] = lib.OutputCacheEntry{Multi: true, Values: append(prev.Values, value)}
				} else {
					log.Errorf("Error outputing multiple values for %s on step %d", name, step)
					os.Exit(8)
					return
				}
			} else {
				outCache[""][step][name] = lib.OutputCacheEntry{Multi: multiple, Values: []json.RawMessage{value}}
			}
			if !sensitive {
				json, err := json.Marshal(lib.Output{Name: name, Multi: multiple, Value: value, Step: step})
				if err != nil {
					log.Errorf("Error marshalling output %s for step %d: %v", name, step, err)
					os.Exit(8)
					return
				}
				_, err = os.Stdout.Write(append(json, '\n'))
				if err != nil {
					log.Errorf("Error writing output %s for step %d: %v", name, step, err)
					os.Exit(8)
					return
				}
			}
		})
		if err != nil {
			log.Errorf("Error running step %d: %v", step, err)
			os.Exit(9)
			return
		}
	}
}
