package node_status_collection_backend

import (
	"time"
)

type nodeStatusRequest struct {
	Data nodeStatusRequestData `json:"data"`
}

type nodeStatusRequestData struct {
	BlockHeightAtBestTip              int64            `json:"block_height_at_best_tip"`
	MaxObservedBlockHeight            int64            `json:"max_observed_block_height"`
	MaxObservedUnvalidatedBlockHeight int64            `json:"max_observed_unvalidated_block_height"`
	CatchupJobStates                  catchupJobStates `json:"catchup_job_states"`
	SyncStatus                        string           `json:"sync_status"`
	Libp2pInputBandwidth              float64          `json:"libp2p_input_bandwidth"`
	Libp2pOutputBandwidth             float64          `json:"libp2p_output_bandwidth"`
	Libp2pCpuUsage                    float64          `json:"libp2p_cpu_usage"`
	CommitHash                        string           `json:"commit_hash"`
	GitBranch                         string           `json:"git_branch"`
	PeerId                            string           `json:"peer_id"`
	IpAddress                         string           `json:"ip_address"`
	Timestamp                         time.Time        `json:"timestamp"`
	UptimeOfNode                      float64          `json:"uptime_of_node"`
	PeerCount                         int64            `json:"peer_count"`
	RpcReceived                       rpcCount         `json:"rpc_received"`
	RpcSent                           rpcCount         `json:"rpc_sent"`
	PubsubMsgReceived                 gossipCount      `json:"pubsub_msg_received"`
	PubsubMsgBroadcasted              gossipCount      `json:"pubsub_msg_broadcasted"`
	ReceivedBlocks                    []block          `json:"received_blocks"`
}

type catchupJobStates struct {
	ToBuildBreadcrumb int64 `json:"to_build_breadcrumb"`
	ToInitialValidate int64 `json:"to_initial_validate"`
	Finished          int64 `json:"finished"`
	ToVerify          int64 `json:"to_verify"`
	ToDownload        int64 `json:"to_download"`
	WaitForParent     int64 `json:"wait_for_parent"`
}

type rpcCount struct {
	GetSomeInitialPeers                         int64 `json:"get_some_initial_peers"`
	GetStagedLedgerAuxAndPendingCoinbasesAtHash int64 `json:"get_staged_ledger_aux_and_pending_coinbases_at_hash`
	AnswerSyncLedgerQuery                       int64 `json:"answer_sync_ledger_query"`
	GetTransitionChain                          int64 `json:"get_transition_chain"`
	GetTransitionKnowledge                      int64 `json:"get_transition_knowledge"`
	GetTransitionChainProof                     int64 `json:"get_transition_chain_proof"`
	GetNodeStatus                               int64 `json:"get_node_status"`
	GetAncestry                                 int64 `json:"get_ancestry"`
	BanNotify                                   int64 `json:"ban_notify"`
	GetBestTip                                  int64 `json:"get_best_tip"`
	GetEpochLedger                              int64 `json:"get_epoch_ledger"`
}

type gossipCount struct {
	NewState            int64 `json:"new_state"`
	TransactionPoolDiff int64 `json:"transaction_pool_diff"`
	SnarkPoolDiff       int64 `json:"snark_pool_diff"`
}

type block struct {
	Hash               string `json:"hash"`
	Sender             string `json:"sender"`
	ReceivedAt         string `json:"received_at"`
	IsValid            bool   `json:"is_valid"`
	ReasonForRejection string `json:"reason_for_rejection"`
}
