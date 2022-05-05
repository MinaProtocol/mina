# Delegation program backend

As part of delegation program, nodes are to upload some proof of their activity. These proofs are to be accumulated and utilized for scoring. This service provides the nodes with a way to siubmit their data for score calculation.

## Constants

- `MAX_SUBMIT_PAYLOAD_SIZE` : max size (in bytes) of the `POST /submit` payload
- `REQUESTS_PER_IP_HOURLY` : max amount of requests per hour per  IP address
- `REQUESTS_PER_PK_HOURLY` : max amount of requests per hour per public key `submitter`

## Protocol

1. Node submits a payload to the Service using `POST /submit`
2. Server saves the request
3. Server replies with status `ok` and HTTP 200 if payload is correct and some other HTTP code otherwise

## Interface

Backend Service is a web server that exposes the following entrypoints:

- `POST /submit` to submit a JSON payload containing the following data:

    ```json
    { "data":
       { "peer_id": "<base58-encoded peer id of the node from libp2p library>"
       , "block": "<base64-encoded bytes of the latest known block>"
       , "created_at": "<current time>"

       // Optional argument
       , "snark_work": "<base64-encoded snark work blob>"
       }
    , "submitter": "<base58check-encoded public key of the submitter>"
    , "sig": "<base64-encoded signature of `data` contents made with public key submitter above>"
    }
    ```

    - Mina's signature scheme (as described in [https://github.com/MinaProtocol/c-reference-signer](https://github.com/MinaProtocol/c-reference-signer)) is to be used
    - Time is represented according to `RFC-3339` with mandatory `Z` suffix (i.e. in UTC), like: `1985-04-12T23:20:50.52Z`
    - Payload for signing is to be made as the following JSON (it's important that its fields are in lexicographical order and if no `snark_work` is provided, field is omitted):
       - `block`: Base64 representation of a `block` field from payload
       - `created_at`: same as in `data`
       - `peer_id`: same as in `data`
       - `snark_work`: same as in `data` (omitted if `null` or `""`)
    - There are three possible responses:
        - `400 Bad Request` with `{"error": "<machine-readable description of an error>"}` payload when the input is considered malformed
        - `401 Unauthorized`  when public key `submitter` is not on the list of allowed keys or the signature is invalid
        - `411 Length Required` when no length header is provided
        - `413 Payload Too Large` when payload exceeds `MAX_SUBMIT_PAYLOAD_SIZE` constant
        - `429 Too Many Requests` when submission from public key `submitter` is rejected due to rate-limiting policy
        - `500 Internal Server Error` with `{"error": "<machine-readable description of an error>"}` payload for any other server error
        - `503 Service Unavailable` when IP-based rate-limiting prohibits the request
        - `200` with `{"status": "ok"}`

## Cloud storage

Cloud storage has the following structure:

- `submissions`
    - `<submitted_at_date>/<submitted_at>-<submitter>.json`
      - Path contents:
        - `submitted_at_date` with server's date (of the time of submission) in format `YYYY-MM-DD`
        - `submitted_at` with server's timestamp (of the time of submission) in RFC-3339
        - `submitter` is base58check-encoded submitter's public key
      - File contents:
        - `remote_addr` with the `ip:port` address from which request has come
        - `peer_id` (as in user's JSON submission)
        - `snark_work` (optional, as in user's JSON submission)
        - `submitter` is base58check-encoded submitter's public key
        - `created_at` is UTC-based `RFC-3339` -encoded
        - `block_hash` is base58check-encoded hash of a block
- `blocks`
    - `<block-hash>.dat`
        - Contains raw block

## Validation and rate limitting

All endpoints are guarded with Nginx which acts as a:

- HTTPS proxy
- Rate-limiter (by IP address) configured with `REQUESTS_PER_IP_HOURLY`

On receiving payload on `/submit`, we perform the following validation:

- Content size doesn't exceed the limit (before reading the data)
- Payload is a JSON of valid format (also check the sizes and formats of `create_at` and `block_hash`)
- `|NOW() - created_at| < 1 min`
- `submitter` is on the list `allowed` of whitelisted public keys
- `sig` is a valid signature of `data` w.r.t. `submitter` public key
- Amount of requests by `submitter` in the last hour is not exceeding `REQUESTS_PER_PK_HOURLY`

After receiving payload on `/submit` , we update in-memory public key rate-limiting state and save the contents of `block` field as `blocks/<block_hash>.dat`.
