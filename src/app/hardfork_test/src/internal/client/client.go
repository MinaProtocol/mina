package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/tidwall/gjson"
)

// Client represents a GraphQL client for querying Mina nodes
type Client struct {
	httpClient *http.Client
	maxRetries int
}

// NewClient creates a new GraphQL client with the specified timeout in seconds and max retries
func NewClient(timeoutSeconds int, maxRetries int) *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: time.Duration(timeoutSeconds) * time.Second,
		},
		maxRetries: maxRetries,
	}
}

// query sends a GraphQL query to the specified node's REST endpoint with retry
// logic. The node is named in failures; its REST port is what gets dialed.
func (c *Client) query(node *config.DaemonInfo, query string) (gjson.Result, error) {
	url := fmt.Sprintf("http://localhost:%d/graphql", node.Port(config.PORT_REST))

	// Format the query payload
	payload := map[string]string{
		"query": fmt.Sprintf("query Q {%s}", query),
	}

	// Convert payload to JSON
	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return gjson.Result{}, fmt.Errorf("failed to marshal query payload: %w", err)
	}

	var lastErr error
	for attempt := 1; attempt <= c.maxRetries; attempt++ {
		backoff := 10 * time.Duration(1<<uint(attempt-1)) * time.Second

		// Create the request
		req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
		if err != nil {
			return gjson.Result{}, fmt.Errorf("failed to create request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")

		// Send the request
		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = err
			if attempt < c.maxRetries {
				time.Sleep(backoff)
				continue
			}
			return gjson.Result{}, fmt.Errorf("failed to send request after %d attempts: %w", c.maxRetries, err)
		}
		defer resp.Body.Close()

		// Read the response
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			lastErr = err
			if attempt < c.maxRetries {
				time.Sleep(backoff)
				continue
			}
			return gjson.Result{}, fmt.Errorf("failed to read response body after %d attempts: %w", c.maxRetries, err)
		}

		// Parse the response
		result := gjson.ParseBytes(body)

		// Check for GraphQL errors in response
		if result.Get("errors").Exists() {
			lastErr = fmt.Errorf("GraphQL error: %s", result.Get("errors").String())
			if attempt < c.maxRetries {
				time.Sleep(backoff)
				continue
			}
			return gjson.Result{}, fmt.Errorf("GraphQL query failed after %d attempts: %w", c.maxRetries, lastErr)
		}

		// Success
		return result, nil
	}

	// This shouldn't be reached but included for safety
	return gjson.Result{}, fmt.Errorf("query failed after %d attempts: %w", c.maxRetries, lastErr)
}

// BlockData represents the structured block data from GraphQL queries
type BlockData struct {
	StateHash       string `json:"state_hash"`
	BlockHeight     int    `json:"block_height"`
	Slot            int    `json:"slot"`
	CurEpochHash    string `json:"cur_epoch_hash"`
	CurEpochSeed    string `json:"cur_epoch_seed"`
	NextEpochHash   string `json:"next_epoch_hash"`
	NextEpochSeed   string `json:"next_epoch_seed"`
	StagedHash      string `json:"staged_hash"`
	SnarkedHash     string `json:"snarked_hash"`
	Epoch           int    `json:"epoch"`
	NumUserCommands int    `json:"num_user_commands"`
	NumFeeTransfers int    `json:"num_fee_transfers"`
	Coinbase        string `json:"coinbase"`
}

func (block *BlockData) NonEmpty() bool {
	return block.NumUserCommands > 0 || block.NumFeeTransfers > 0 || block.Coinbase != "0"
}

func (block BlockData) String() string {
	b, err := json.MarshalIndent(block, "", "  ")
	if err != nil {
		type blockData BlockData
		return fmt.Sprintf("%+v", blockData(block))
	}
	return string(b)
}

const genesisBlockQuery = `
genesisBlock {
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
      epoch
      stakingEpochData {
        ledger { hash }
        seed
      }
      nextEpochData {
        ledger { hash }
        seed
      }
    }
    blockchainState {
      stagedLedgerHash
      snarkedLedgerHash
    }
  }
  transactions {
    coinbase
    feeTransfer { fee }
  }
  stateHash
}
`

const blocksQueryWithLimit = `
bestChain (maxLength: %d){
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
      epoch
      stakingEpochData {
        ledger { hash }
        seed
      }
      nextEpochData {
        ledger { hash }
        seed
      }
    }
    blockchainState {
      stagedLedgerHash
      snarkedLedgerHash
    }
  }
  transactions {
    coinbase
    feeTransfer { fee }
  }
  stateHash
}
`

func parseBlock(value gjson.Result) *BlockData {
	block := &BlockData{
		StateHash:       value.Get("stateHash").String(),
		BlockHeight:     int(value.Get("protocolState.consensusState.blockHeight").Int()),
		Slot:            int(value.Get("protocolState.consensusState.slotSinceGenesis").Int()),
		CurEpochHash:    value.Get("protocolState.consensusState.stakingEpochData.ledger.hash").String(),
		CurEpochSeed:    value.Get("protocolState.consensusState.stakingEpochData.seed").String(),
		NextEpochHash:   value.Get("protocolState.consensusState.nextEpochData.ledger.hash").String(),
		NextEpochSeed:   value.Get("protocolState.consensusState.nextEpochData.seed").String(),
		StagedHash:      value.Get("protocolState.blockchainState.stagedLedgerHash").String(),
		SnarkedHash:     value.Get("protocolState.blockchainState.snarkedLedgerHash").String(),
		Epoch:           int(value.Get("protocolState.consensusState.epoch").Int()),
		NumUserCommands: int(value.Get("commandTransactionCount").Int()),
		NumFeeTransfers: len(value.Get("transactions.feeTransfer").Array()),
		Coinbase:        value.Get("transactions.coinbase").String(),
	}

	return block
}

func (c *Client) GenesisBlock(node *config.DaemonInfo) (*BlockData, error) {
	result, err := c.query(node, genesisBlockQuery)
	if err != nil {
		return nil, err
	}
	return parseBlock(result.Get("data.genesisBlock")), nil
}

func (c *Client) RecentBlocks(node *config.DaemonInfo, limit int) ([]BlockData, error) {
	result, err := c.query(node, fmt.Sprintf(blocksQueryWithLimit, limit))
	if err != nil {
		return nil, err
	}

	var blocks []BlockData

	result.Get("data.bestChain").ForEach(func(_, value gjson.Result) bool {
		blocks = append(blocks, *parseBlock(value))
		return true
	})

	return blocks, nil
}

func (c *Client) BestTip(node *config.DaemonInfo) (*BlockData, error) {
	blocks, err := c.RecentBlocks(node, 1)
	if err != nil {
		return nil, err
	}
	if len(blocks) == 0 {
		return nil, fmt.Errorf("no best tip found on node %q", node.Name)
	}

	return &blocks[0], nil
}

func (c *Client) ForkConfig(node *config.DaemonInfo) (gjson.Result, error) {
	result, err := c.query(node, "fork_config")
	if err != nil {
		return gjson.Result{}, err
	}

	return result.Get("data.fork_config"), nil
}

// accountTiming mirrors the GraphQL account timing/balance response. All
// numeric fields are decoded from the stringified integers GraphQL returns:
// amounts/balances are in nanomina and times are global-slot numbers.
type accountTiming struct {
	Timing *struct {
		InitialMinimumBalance int64 `json:"initialMinimumBalance,string"`
		CliffTime             int64 `json:"cliffTime,string"`
		CliffAmount           int64 `json:"cliffAmount,string"`
		VestingPeriod         int64 `json:"vestingPeriod,string"`
		VestingIncrement      int64 `json:"vestingIncrement,string"`
	} `json:"timing"`
	Balance struct {
		Total  int64 `json:"total,string"`
		Liquid int64 `json:"liquid,string"`
	} `json:"balance"`
}

const accountTimingQuery = `
account(publicKey: "%s") {
  timing {
    initialMinimumBalance
    cliffTime
    cliffAmount
    vestingPeriod
    vestingIncrement
  }
  balance {
    total
    liquid
  }
}
`

// AccountTiming queries the timing parameters and balances of the account with
// the given public key.
func (c *Client) AccountTiming(node *config.DaemonInfo, pubKey string) (*accountTiming, error) {
	result, err := c.query(node, fmt.Sprintf(accountTimingQuery, pubKey))
	if err != nil {
		return nil, err
	}

	var response struct {
		Data struct {
			Account *accountTiming `json:"account"`
		} `json:"data"`
	}
	if err := json.Unmarshal([]byte(result.Raw), &response); err != nil {
		return nil, fmt.Errorf("failed to decode account timing response: %w", err)
	}

	if response.Data.Account == nil {
		return nil, fmt.Errorf("account %s not found on node %q", pubKey, node.Name)
	}

	return response.Data.Account, nil
}

func (c *Client) NumUserCommandsInBestChain(node *config.DaemonInfo) (int, error) {
	result, err := c.query(node, "bestChain { commandTransactionCount }")
	if err != nil {
		return 0, err
	}

	count := 0
	result.Get("data.bestChain").ForEach(func(_, value gjson.Result) bool {
		if value.Get("commandTransactionCount").Int() > 0 {
			count++
		}
		return true
	})

	return count, nil
}
