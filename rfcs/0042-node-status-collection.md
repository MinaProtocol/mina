## Summary

[summary]: #summary

This RFC proposes a system that collects various stats related to node health to better understand the health of the network participants. This node status collection system would collect stats from the node and send those stats to a url (by default those info would be send to o1labs google cloud backend). And if those stats were sent to the o1labs backend, then those would be persisted and be used for debugging and monitoring purpose.

## Motivation

[motivation]: #motivation

In current version of the network, we saw some performance and scaling issues. By collecting more stats from the network, we hope to improve the speed of the mina protocol by analysize those stats.

## Protocol between the node status collection service and o1labs backend

[protocol]: #protocol

1. Node submits a payload to the backend using `POST /submit` every 5 slots
2. Server saves the request
3. Server replies with `200` with `{"status": "OK"}` if the payload is valid

## Interface design

[interface-design]: #interface-design

The node status collection system would make the following `post` request to the designated url every 5 slots.

* `POST /submit` to submit a json payload containing the following data:

```
{ "data":
  { "peer_id": "<base64 encodeing of the libp2p peer id>"
  , "ip_address": "<hash of ip address of the submitter>"
  , "mina_version": "<mina version>"
  , "git_hash": "<git hash of the mina node>"
  , "timestamp": "<current time using RFC-3339 representation>"
  , "libp2p_input_bandwidth": "<input bandwidth for libp2p helper system>"
  , "libp2p_output_bandwidth": "<output bandwith for libp2p helper system>"
  , "libp2p_cpu_usage": "<cpu usage for libp2p helper system>"
  , "pubsub_msg_received": { "new_state": { "count": "<integer, e.g. 10>"
                                          , "bandwidth": "<integer, bandwidth in bytes>" }
                           , "transaction_pool_diff": { "count": "<integer, e.g. 11>"
                                                      , "bandwidth": "<integer, bandwidth in bytes>" }
                           , "snark_pool_diff": { "count": "<integer, e.g. 9>"
                                                , "bandwidth": "<integer, bandwidth in bytes>" }
                           }
  , "pubsub_msg_broadcasted": { "new_state": { "count": "<integer, e.g. 3>"
                                             , "bandwidth": "<integer, bandwidth in bytes>" }
                              , "transaction_pool_diff": { "count": "<integer, e.g. 6>"
                                                         , "bandwidth": "<integer, bandwidth in bytes>" }
                              , "snark_pool_diff": { "count": "<integer, e.g. 1>"
                                                   , "bandwidth": "<integer, bandwidth in bytes>" }
                              }
  , "rpc_received": { "get_transition_chain_proof": { "count": "<integer>"
                                                    , "bandwidth": "<integer, bandwidth in bytes>" }
                    , ...
                    }
  , "rpc_sent": { "get_transition_chain_proof": { "count": "<integer>"
                                                , "bandwidth": "integer, bandwidth in bytes>" }
                , ...
                }
  , "block_height_at_best_tip": "<integer, e.g. 43>"
  , "max_observed_block_height": "<integer, e.g. 44>"
  , "max_observed_unvalidated_block_height": "<integer, e.g. 44>"
  , "slot_and_epoch_number_at_best_tip": { "epoch": "<integer, e.g. 8>"
                                         , "slot":  "<integer, e.g. 111>"
                                         }
  , "sync_status": "<Synced | Catchup | Bootstrap | Offline | Listening>" 
  , "catchup_job_states": { "To_initial_validate": "<integer, e.g. 10>"
                          , "Finished":            "<integer, e.g. 11>"
                          , "To_verify":           "<integer, e.g. 29>"
                          , "To_download":         "<integer, e.g. 4>"
                          }
  , "uptime_of_node": "<integer, duration of uptime in secs, e.g. 45678>"
  , "blocks_received": [ { "hash": "<base64 encoding of block hash"
                         , "sender": {"ip": "<ip address>"
                                     ,"peer_id": "<base64 encoding of peer id>"}
                         , "received_at": "<timestamp at which block is received>"
                         , "is_valid": "<bool>"
                         , "reason_for_rejection": "<null | reason for why it was rejected"
                         }
                       , ...
                       ]
  , "peer_count": "<integer, number of peers in libp2p layer, e.g. 152>"
  }
}
```

If the `post` request is made against o1labs' backend service, then there would be the following possible responses:
* `400 Bad Request` with {"error": "<description of the error"} when input is malformed
* `500 Internal Server Error` with {"error": "description of the error"} for any server error
* `200` with {"status": "OK"}

## daemon.json config to enable/disable the node status collection service

[daemon.json]: #daemon
This service would be disabled by default. It can be turned on by setting the `statusReport` field in `daemon.json` file to be true (by default it is set to be false).

## Cloud storage

[cloud-storage]: #cloud-storage

Cloud storage for o1labs backend has the following structure:

`<hash_of_ip_address>/<peer_id>/<created_at>.json`

`<hash_of_ip_address>` is the hash of the ip address of the submitter
`<peer_id>` is the base64 encoding of the libp2p peer id of the submitter
The json file contains the content of the request if the request is valid
