package client

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	sdk "github.com/MinaProtocol/mina-sdk-go"
)

// retryDelay is the pause between retries of a failed GraphQL request.
//
// The SDK retries on a fixed interval, whereas this client previously backed
// off exponentially starting at 10s. We keep the initial step as the constant
// delay: the daemons under test are local, so a failure is far more often "not
// up yet" than "overloaded", and a constant delay bounds the total wait.
const retryDelay = 10 * time.Second

// Client queries Mina daemons over GraphQL.
//
// The test drives several daemons at once, addressing each by its REST port,
// while an SDK client is bound to a single endpoint. Client therefore keeps one
// SDK client per port, created on first use.
type Client struct {
	timeout    time.Duration
	maxRetries int

	mu      sync.Mutex
	clients map[int]*sdk.Client
}

// NewClient creates a new GraphQL client with the specified timeout in seconds and max retries
func NewClient(timeoutSeconds int, maxRetries int) *Client {
	return &Client{
		timeout:    time.Duration(timeoutSeconds) * time.Second,
		maxRetries: maxRetries,
		clients:    make(map[int]*sdk.Client),
	}
}

// forPort returns the SDK client addressing the daemon on the given port.
func (c *Client) forPort(port int) *sdk.Client {
	c.mu.Lock()
	defer c.mu.Unlock()

	if sdkClient, ok := c.clients[port]; ok {
		return sdkClient
	}

	sdkClient := sdk.NewClient(
		sdk.WithGraphQLURI(fmt.Sprintf("http://localhost:%d/graphql", port)),
		sdk.WithTimeout(c.timeout),
		sdk.WithRetries(c.maxRetries),
		sdk.WithRetryDelay(retryDelay),
	)
	c.clients[port] = sdkClient
	return sdkClient
}

// Close releases the connections held by every per-port client.
func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()

	for _, sdkClient := range c.clients {
		sdkClient.Close()
	}
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
		return fmt.Sprintf("%+v", block)
	}
	return string(b)
}

// fromBlockInfo projects the SDK's block representation onto the fields the
// hardfork test asserts on.
func fromBlockInfo(info sdk.BlockInfo) BlockData {
	return BlockData{
		StateHash:       info.StateHash,
		BlockHeight:     info.Height,
		Slot:            info.GlobalSlotSinceGenesis,
		CurEpochHash:    info.StakingEpochLedgerHash,
		CurEpochSeed:    info.StakingEpochSeed,
		NextEpochHash:   info.NextEpochLedgerHash,
		NextEpochSeed:   info.NextEpochSeed,
		StagedHash:      info.StagedLedgerHash,
		SnarkedHash:     info.SnarkedLedgerHash,
		Epoch:           info.Epoch,
		NumUserCommands: info.CommandTransactionCount,
		NumFeeTransfers: info.FeeTransferCount,
		Coinbase:        info.Coinbase,
	}
}

func (c *Client) GenesisBlock(port int) (*BlockData, error) {
	info, err := c.forPort(port).GetGenesisBlock()
	if err != nil {
		return nil, err
	}

	block := fromBlockInfo(*info)
	return &block, nil
}

func (c *Client) RecentBlocks(port int, limit int) ([]BlockData, error) {
	infos, err := c.forPort(port).GetBestChain(limit)
	if err != nil {
		return nil, err
	}

	var blocks []BlockData
	for _, info := range infos {
		blocks = append(blocks, fromBlockInfo(info))
	}

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

// ForkConfig returns the daemon's fork_config verbatim. The blob is large and
// version-dependent, so callers parse out only what they need; a daemon that
// has not reached the fork point yet returns the JSON literal `null`.
func (c *Client) ForkConfig(port int) ([]byte, error) {
	return c.forPort(port).GetForkConfig()
}

func (c *Client) NumUserCommandsInBestChain(port int) (int, error) {
	blocks, err := c.RecentBlocks(port, 0)
	if err != nil {
		return 0, err
	}

	count := 0
	for _, block := range blocks {
		if block.NumUserCommands > 0 {
			count++
		}
	}

	return count, nil
}
