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

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	"go.uber.org/zap/zapcore"

	lib "itn_orchestrator"
)

var actions map[string]lib.Action

func addAction(actions map[string]lib.Action, action lib.Action) {
	actions[action.Name()] = action
}

func init() {
	actions = map[string]lib.Action{}
	addAction(actions, lib.DiscoveryAction{})
	addAction(actions, lib.PaymentsAction{})
	addAction(actions, lib.KeyloaderAction{})
	addAction(actions, lib.StopAction{})
	addAction(actions, lib.WaitAction{})
	addAction(actions, lib.FundAction{})
	addAction(actions, lib.ZkappCommandsAction{})
	addAction(actions, lib.SlotsWonAction{})
	addAction(actions, lib.ResetGatingAction{})
	addAction(actions, lib.IsolateAction{})
	addAction(actions, lib.AllocateSlotsAction{})
	addAction(actions, lib.RestartAction{})
	addAction(actions, lib.JoinAction{})
	addAction(actions, lib.SampleAction{})
	addAction(actions, lib.ExceptAction{})
	addAction(actions, lib.StopDaemonAction{})
	addAction(actions, lib.RotateAction{})

}

type AwsConfig struct {
	Region    string `json:"region"`
	AccountId string `json:"account_id"`
	Prefix    string `json:"prefix"`
}

type AwsCredentials struct {
	AccessKeyId     string `json:"access_key_id"`
	SecretAccessKey string `json:"secret_access_key"`
}

func loadAwsCredentials(filename string, log logging.EventLogger) {
	file, err := os.Open(filename)
	if err != nil {
		log.Fatalf("Error loading credentials file: %s", err)
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	var credentials AwsCredentials
	err = decoder.Decode(&credentials)
	if err != nil {
		log.Fatalf("Error loading credentials file: %s", err)
	}
	os.Setenv("AWS_ACCESS_KEY_ID", credentials.AccessKeyId)
	os.Setenv("AWS_SECRET_ACCESS_KEY", credentials.SecretAccessKey)
}

type AppConfig struct {
	LogLevel         zapcore.Level `json:",omitempty"`
	LogFile          string        `json:",omitempty"`
	Key              itn_json_types.Ed25519Privkey
	Aws              AwsConfig `json:"aws"`
	FundDaemonPorts  []string  `json:",omitempty"`
	MinaExec         string    `json:",omitempty"`
	SlotDurationMs   int
	GenesisTimestamp itn_json_types.Time
	ControlExec      string `json:",omitempty"`
}

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
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

type CommandOrComment struct {
	command *lib.Command
	comment string
}

func (v *CommandOrComment) UnmarshalJSON(data []byte) error {
	if err := json.Unmarshal(data, &v.comment); err == nil {
		return nil
	}
	cmd := lib.Command{}
	if err := json.Unmarshal(data, &cmd); err != nil {
		return err
	}
	v.command = &cmd
	return nil
}

type outCacheT = map[string]map[int]map[string]lib.OutputCacheEntry

func outputF(outCache outCacheT, log logging.StandardLogger, step int) func(string, any, bool, bool) {
	return func(name string, value_ any, multiple bool, sensitive bool) {
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
			json, err := json.Marshal(lib.Output{
				Name:  name,
				Multi: multiple,
				Value: value,
				Step:  step,
				Time:  time.Now().UTC(),
			})
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
	}
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

	awsCredentialsFile := os.Getenv("AWS_CREDENTIALS_FILE")
	if awsCredentialsFile != "" {
		loadAwsCredentials(awsCredentialsFile, log)
	}
	ctx := context.Background()
	awsCfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(appConfig.Aws.Region))
	if err != nil {
		log.Fatalf("Error loading AWS configuration: %v", err)
	}
	client := s3.NewFromConfig(awsCfg)
	nodeData := make(map[lib.NodeAddress]lib.NodeEntry)
	awsctx := lib.AwsContext{Client: client, BucketName: aws.String(GetBucketName(appConfig)), Prefix: appConfig.Aws.Prefix}
	config := lib.Config{
		Ctx:              ctx,
		AwsContext:       awsctx,
		Sk:               ed25519.PrivateKey(appConfig.Key),
		Log:              log,
		FundDaemonPorts:  appConfig.FundDaemonPorts,
		MinaExec:         appConfig.MinaExec,
		NodeData:         nodeData,
		SlotDurationMs:   appConfig.SlotDurationMs,
		GenesisTimestamp: time.Time(appConfig.GenesisTimestamp),
		ControlExec:      appConfig.ControlExec,
	}
	if config.MinaExec == "" {
		config.MinaExec = "mina"
	}
	if config.StopDaemonDelaySec == 0 {
		config.StopDaemonDelaySec = 10
	}
	outCache := map[string]map[int]map[string]lib.OutputCacheEntry{
		"": {},
	}
	rconfig := lib.ResolutionConfig{
		OutputCache: outCache,
	}
	inDecoder := json.NewDecoder(os.Stdin)
	step := 0
	var prevAction lib.BatchAction
	var actionAccum []lib.ActionIO
	handlePrevAction := func() {
		log.Infof("Performing steps %s (%d-%d)", prevAction.Name(), step-len(actionAccum), step-1)
		err = prevAction.RunMany(config, actionAccum)
		if err != nil {
			log.Errorf("Error running steps %d-%d: %v", step-len(actionAccum), step-1, err)
			os.Exit(9)
			return
		}
		prevAction = nil
		actionAccum = nil
	}
	for {
		var commandOrComment CommandOrComment
		if err := inDecoder.Decode(&commandOrComment); err != nil {
			if err != io.EOF {
				log.Errorf("Error decoding command for step %d: %v", step, err)
				os.Exit(5)
			}
			break
		}
		if commandOrComment.command == nil {
			fmt.Fprintln(os.Stderr, commandOrComment.comment)
			continue
		}
		cmd := *commandOrComment.command
		if prevAction != nil && prevAction.Name() != cmd.Action {
			handlePrevAction()
		}
		params, err := lib.ResolveParams(rconfig, step, cmd.Params)
		if err != nil {
			log.Errorf("Error resolving params for step %d: %v", step, err)
			os.Exit(6)
			return
		}
		action := actions[cmd.Action]
		if action == nil {
			log.Errorf("Unknown action name: %d", cmd.Action)
			os.Exit(10)
			return
		}
		batchAction, isBatchAction := action.(lib.BatchAction)
		if isBatchAction {
			prevAction = batchAction
			actionAccum = append(actionAccum, lib.ActionIO{
				Params: params,
				Output: outputF(outCache, log, step),
			})
		} else {
			log.Infof("Performing step %s (%d)", cmd.Action, step)
			err = action.Run(config, params, outputF(outCache, log, step))
			if err != nil {
				log.Errorf("Error running step %d: %v", step, err)
				os.Exit(9)
				return
			}
		}
		step++
	}
	if prevAction != nil {
		handlePrevAction()
	}
}
