## Summary

[summary]: #summary

This RFC proposes a system that automates the collection of errors from Mina block producer nodes. This system would send an error report when
1. an exception occurs;
2. a fatal error occurs.
By default those error report would be sent to o1labs google cloud backend to facilitate prioritization of fixes for improving the stability of nodes.

## Motivation

[motivation]: #motivation

This system would help o1labs to identify the severity and the frequency of errors. This would greatly facitate the discovery and analysis of the bugs.

## Protocol between the node error collection service and o1labs backend

[protocol]: #protocol

1. Node submits a payload to the backend using `POST /submit` whenever an exception or a fatal error occurs
2. Server saves the request
3. Server replies with `200` with `{"status": "OK"}` if the payload is valid

## Interface design

[interface-design]: #interface-design

The node error collection system would make the following `post` request to the designated url.

* `POST /submit` to submit a json payload containing the following data:

```
{ "data":
  { "peer_id": "<base64 encoding of the libp2p peer id>"
  , "ip_address": "<hash of ip address of the submitter>"
  , "public_key": "<optional, public key of the block producer>"
  , "git_branch": "<optional, git branch of the mina node>"
  , "commit_hash": "<commit hash of the mina node>"
  , "chain_id": "<a hash string to distinguish between different networks>"
  , "contact_info": "<optional, contact info provided by the block producer>"
  , "timestamp": "<current time and date>"
  , "level": "<log level>"
  , "id": "<random UUID v4>"
  , "error": "<error message>"
  , "stacktrace": "<stack trace of the error>"
  , "cpu": "<cpu info via `lscpu`>"
  , "ram": "<ram ifo via `cat /proc/meminfo`"
  , "metadata": "<metadata field from the error message>"
  , "catchup_job_states": { "To_initial_validate": "<integer, e.g. 10>"
                          , "Finished":            "<integer, e.g. 11>"
                          , "To_verify":           "<integer, e.g. 29>"
                          , "To_download":         "<integer, e.g. 4>"
                          }
  , "sync_status": "<Synced | Catchup | Bootstrap | Offline | Listening>"
  , "block_height_at_best_tip": "<integer, e.g. 43>"
  , "max_observed_block_height": "<integer, e.g. 44>"
  , "max_observed_unvalidated_block_height": "<integer, e.g. 44>"
  , "uptime_of_node": "<integer, duration of uptime in secs, e.g. 12345>"
  , "location": "<location of the error>"
  }
}
```

If the `post` request is made against o1labs' backend service, the there would be the following possible responses:
* `400 Bad Request` with {"error": "<description of the error"} when input is malformed
* `500 Internal Server Error` with {"error": "description of the error"} for any server error
* `200` with {"status": "OK"}

## daemon.json config to enable/disable the node error collection service

[daemon.json]: #daemon
This service would be enabled by default. It turned turned off by setting the `errorReport` field in `daemon.json` file to be false.

## Cloud storage

[cloud-storage]: #cloud-storage

Cloud storage for o1labs backend has the following structure:

`<chain_id>/<hash_of_ip_address>/<peer_id>/<created_at>.json`

`<chain_id>` is the hash string taken from the corresponding field of the request
`<hash_of_ip_address>` is the hash of the ip address of the submitter
`<peer_id>` is the base64 encoding of the libp2p peer id of the submitter
The json file contains the content of the request if the request is valid
