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

// Query sends a GraphQL query to the specified port with retry logic
func (c *Client) Query(port int, query string) (gjson.Result, error) {
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

// GetHeight gets the current block height
func (c *Client) GetHeight(port int) (int, error) {
	result, err := c.Query(port, "bestChain(maxLength: 1) { protocolState { consensusState { blockHeight } } }")
	if err != nil {
		return 0, err
	}

	height := result.Get("data.bestChain.0.protocolState.consensusState.blockHeight").Int()
	return int(height), nil
}

// GetHeightAndSlotOfEarliest gets the height and slot of the earliest block
func (c *Client) GetHeightAndSlotOfEarliest(port int) (height, slot int, err error) {
	result, err := c.Query(port, "bestChain { protocolState { consensusState { blockHeight slotSinceGenesis } } }")
	if err != nil {
		return 0, 0, err
	}

	blockHeight := result.Get("data.bestChain.0.protocolState.consensusState.blockHeight").Int()
	slotSinceGenesis := result.Get("data.bestChain.0.protocolState.consensusState.slotSinceGenesis").Int()

	return int(blockHeight), int(slotSinceGenesis), nil
}

// GetForkConfig gets the fork configuration
func (c *Client) GetForkConfig(port int) (gjson.Result, error) {
	result, err := c.Query(port, "fork_config")
	if err != nil {
		return gjson.Result{}, err
	}

	return result.Get("data.fork_config"), nil
}

// BlocksWithUserCommands gets the number of blocks with user commands
func (c *Client) BlocksWithUserCommands(port int) (int, error) {
	result, err := c.Query(port, "bestChain { commandTransactionCount }")
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

// Blocks gets blocks data as in the original shell script
const BlocksQuery = `
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

// BlockData represents the structured block data from GraphQL queries
type BlockData struct {
	StateHash     string
	BlockHeight   int
	Slot          int
	NonEmpty      bool
	CurEpochHash  string
	CurEpochSeed  string
	NextEpochHash string
	NextEpochSeed string
	StagedHash    string
	SnarkedHash   string
	Epoch         int
}

// GetBlocks retrieves block data from the node
func (c *Client) GetBlocks(port int) ([]BlockData, error) {
	result, err := c.Query(port, BlocksQuery)
	if err != nil {
		return nil, err
	}

	var blocks []BlockData

	result.Get("data.bestChain").ForEach(func(_, value gjson.Result) bool {
		block := BlockData{
			StateHash:     value.Get("stateHash").String(),
			BlockHeight:   int(value.Get("protocolState.consensusState.blockHeight").Int()),
			Slot:          int(value.Get("protocolState.consensusState.slotSinceGenesis").Int()),
			CurEpochHash:  value.Get("protocolState.consensusState.stakingEpochData.ledger.hash").String(),
			CurEpochSeed:  value.Get("protocolState.consensusState.stakingEpochData.seed").String(),
			NextEpochHash: value.Get("protocolState.consensusState.nextEpochData.ledger.hash").String(),
			NextEpochSeed: value.Get("protocolState.consensusState.nextEpochData.seed").String(),
			StagedHash:    value.Get("protocolState.blockchainState.stagedLedgerHash").String(),
			SnarkedHash:   value.Get("protocolState.blockchainState.snarkedLedgerHash").String(),
			Epoch:         int(value.Get("protocolState.consensusState.epoch").Int()),
		}

		// Calculate if the block is non-empty based on transactions
		cmdCount := value.Get("commandTransactionCount").Int()
		feeCount := value.Get("transactions.feeTransfer").Array()
		coinbase := value.Get("transactions.coinbase").String() != "0"

		block.NonEmpty = (cmdCount+int64(len(feeCount))) > 0 || coinbase

		blocks = append(blocks, block)
		return true
	})

	return blocks, nil
}
