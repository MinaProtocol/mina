package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

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

// query sends a GraphQL query to the specified port with retry logic
func (c *Client) query(port int, query string) (gjson.Result, error) {
	url := fmt.Sprintf("http://localhost:%d/graphql", port)

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

// Blocks gets blocks data as in the original shell script
const blocksQuery = `
bestChain {
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

func (c *Client) GenesisBlock(port int) (*BlockData, error) {
	result, err := c.query(port, genesisBlockQuery)
	if err != nil {
		return nil, err
	}
	return parseBlock(result.Get("data.genesisBlock")), nil
}

func (c *Client) RecentBlocks(port int, limit int) ([]BlockData, error) {
	result, err := c.query(port, fmt.Sprintf(blocksQueryWithLimit, limit))
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

func (c *Client) BestTip(port int) (*BlockData, error) {
	blocks, err := c.RecentBlocks(port, 1)
	if err != nil {
		return nil, err
	}
	if len(blocks) == 0 {
		return nil, fmt.Errorf("No best tip found! at port %d", port)
	}

	return &blocks[0], nil
}

// NOTE: This only returns the block in a node's best chain, if a node has age
// over k-slot it won't be present.
func (c *Client) GetAllBlocks(port int) ([]BlockData, error) {
	result, err := c.query(port, blocksQuery)
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

func (c *Client) ForkConfig(port int) (gjson.Result, error) {
	result, err := c.query(port, "fork_config")
	if err != nil {
		return gjson.Result{}, err
	}

	return result.Get("data.fork_config"), nil
}

func (c *Client) NumUserCommandsInBestChain(port int) (int, error) {
	result, err := c.query(port, "bestChain { commandTransactionCount }")
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
