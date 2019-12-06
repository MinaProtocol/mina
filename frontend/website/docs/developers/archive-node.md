# Archive Node

## Background

Since Coda nodes are by default succinct, if you need to preserve historical state, you'll want to run an `archive node`. Start the daemon using this command to run an archive process reachable at port `3086`:
```
coda daemon -propose-key ~/keys/my_wallet -rest 3085 -archive-port 3086
```

## Architecture

<img width="100%" src="https://cdn.codaprotocol.com/website/static/img/archive-node-diagram-c5424a1f7a6993488f3337f81b7b929ae2cfeb9d2656413106606f7ecc804e06.png" alt="Coda archive node architecture diagram" />

**Writes:**

- Coda daemon pushes diff into Archive process
- Archive process transforms diff into [GraphQL](https://graphql.org/) query
- Archive process sends GraphQL query to [Hasura process](https://hasura.io/)
- Hasura transforms GraphQL query into SQL write
- Hasura issues SQL write to Postgres DB

**Reads**

- Client issues GraphQL command to Hasura
- Hasura transforms GraphQL query into SQL read
- Hasura issues SQL read to Postgres DB
- Hasura returns SQL rows as GraphQL formatted response

## Issuing Queries to an Archive Node

See the <a href="/docs/archive-node/" target="_blank">archive node schema docs</a> for the full API.

!!! warning
    - The archive node GraphQL API is still in development, so these endpoints may change

### Example Query

Hypothetical query issued by a client -- get the first five blocks that a specific block producer (`creator: "8Sujk2UD4faWu98TzK6zaeMdo3qngi1G8CRrByULiBgEytSb3sAJudxaUPv45thdBg"`) and the number of transactions in those blocks:
```graphql
query GetNumTransactionOfTheOldestBlocksFromCreator {
  blocks(limit: 5, order_by: {block_length: asc}, where: {public_key: {value: {_eq: "8Sujk2UD4faWu98TzK6zaeMdo3qngi1G8CRrByULiBgEytSb3sAJudxaUPv45thdBg"}}}) {
    stateHashByStateHash {
      value
    }
    blocks_user_commands_aggregate {
      aggregate {
        count
      }
    }
  }
}

```

Transpiled SQL query (automatically done by Hasura):
```sql
SELECT
  coalesce(
    json_agg(
      "root"
      ORDER BY
        "root.pg.block_length" ASC NULLS LAST
    ),
    '[]'
  ) AS "root"
FROM
  (
    SELECT
      "_1_root.base"."block_length" AS "root.pg.block_length",
      row_to_json(
        (
          SELECT
            "_8_e"
          FROM
            (
              SELECT
                "_4_root.or.stateHashByStateHash"."stateHashByStateHash" AS "stateHashByStateHash",
                "_7_root.ar.root.blocks_user_commands_aggregate"."blocks_user_commands_aggregate" AS "blocks_user_commands_aggregate"
            ) AS "_8_e"
        )
      ) AS "root"
    FROM
      (
        SELECT
          *
        FROM
          "public"."blocks"
        WHERE
          (
            EXISTS (
              SELECT
                1
              FROM
                "public"."public_keys" AS "_0__be_0_public_public_keys"
              WHERE
                (
                  (
                    (
                      ("_0__be_0_public_public_keys"."id") = ("public"."blocks"."creator")
                    )
                    AND ('true')
                  )
                  AND (
                    (
                      (
                        (
                          ("_0__be_0_public_public_keys"."value") = (
                            (
                              '8Sujk2UD4faWu98TzK6zaeMdo3qngi1G8CRrByULiBgEytSb3sAJudxaUPv45thdBg'
                            ) :: text
                          )
                        )
                        AND ('true')
                      )
                      AND ('true')
                    )
                    AND (
                      ('true')
                      AND ('true')
                    )
                  )
                )
            )
          )
      ) AS "_1_root.base"
      LEFT OUTER JOIN LATERAL (
        SELECT
          row_to_json(
            (
              SELECT
                "_3_e"
              FROM
                (
                  SELECT
                    "_2_root.or.stateHashByStateHash.base"."value" AS "value"
                ) AS "_3_e"
            )
          ) AS "stateHashByStateHash"
        FROM
          (
            SELECT
              *
            FROM
              "public"."state_hashes"
            WHERE
              (("_1_root.base"."state_hash") = ("id"))
          ) AS "_2_root.or.stateHashByStateHash.base"
      ) AS "_4_root.or.stateHashByStateHash" ON ('true')
      LEFT OUTER JOIN LATERAL (
        SELECT
          json_build_object(
            'aggregate',
            json_build_object('count', COUNT(*))
          ) AS "blocks_user_commands_aggregate"
        FROM
          (
            SELECT
              1 AS "root.ar.root.blocks_user_commands_aggregate__one"
            FROM
              (
                SELECT
                  *
                FROM
                  "public"."blocks_user_commands"
                WHERE
                  (("_1_root.base"."state_hash") = ("block_id"))
              ) AS "_5_root.ar.root.blocks_user_commands_aggregate.base"
          ) AS "_6_root.ar.root.blocks_user_commands_aggregate"
      ) AS "_7_root.ar.root.blocks_user_commands_aggregate" ON ('true')
    ORDER BY
      "root.pg.block_length" ASC NULLS LAST
    LIMIT
      5
  ) AS "_9_root"
```

Result from query:
```json
{
  "data": {
    "blocks": [
      {
        "stateHashByStateHash": {
          "value": "TWogQ6hEszqvpn6mfv2Pqda8HeeRbJBWjjfsDVBgn3wBz18Z3AkaGfu4yGe9eKFR"
        },
        "blocks_user_commands_aggregate": {
          "aggregate": {
            "count": 10
          }
        }
      },
      {
        "stateHashByStateHash": {
          "value": "TWogp1RXHWne4G4i5NJj4wLRWKetZxwgya5ByFaJPUyKdq3UW8sbdDEMLW3RNsi4"
        },
        "blocks_user_commands_aggregate": {
          "aggregate": {
            "count": 10
          }
        }
      },
      {
        "stateHashByStateHash": {
          "value": "TWogPJdEZVKphupQ8KTtnjTLjmtSri826QLM6eBS8M9XDr6c8r6zpCfCzSRR3kHk"
        },
        "blocks_user_commands_aggregate": {
          "aggregate": {
            "count": 8
          }
        }
      },
      {
        "stateHashByStateHash": {
          "value": "TWogfYKJ2fj2KYJLqMgynhxL9CDeZfHYvzwVRdpvcUcifLZFURB5bfLHiJto3dqx"
        },
        "blocks_user_commands_aggregate": {
          "aggregate": {
            "count": 11
          }
        }
      },
      {
        "stateHashByStateHash": {
          "value": "TWogHxtf6aZQ2Bynrxpw5DBR8T5mZLjRCV49Uen5EstU4H6XRKkwSy6F7KgEMBPG"
        },
        "blocks_user_commands_aggregate": {
          "aggregate": {
            "count": 10
          }
        }
      }
    ]
  }
}
```

## Appendix

**Tables in Postgres:**

- blocks
- fee_transfers
- user_commands
- public_keys
- snark_work
- receipt_chain

**Daemon representation of a new block (the diff pushed to Archive process):**
```
{
  "protocol_state":{
      "previous_state_hash":"471764816410381875562078664112022517870653866027141366117039751898972709923085604689661840",
      "body":{
        "blockchain_state":{
          "staged_ledger_hash":{
            "non_snark":{
              "ledger_hash":"324039319920316409986163158067504192361667752758651973323692525124541619978527385734186907",
              "aux_hash":"PNexkGCETXiF8p2RBhmdJLpan3oPFPuriYBCAYY7M5CrBXz76q","pending_coinbase_aux":"5Lt1pKMfAPWAaqbW3mvNUy5w1ZbHaYtdNNEjLUAvVnAYDfqKZ2M"
            },"pending_coinbase_hash":"323935532354232778373191741954498420817351102641286976362355667703643603277118563699070469"
          },"snarked_ledger_hash":"94871860058829511941197580965871251548732616230752454083325990670651814240808931418260785",
          "timestamp":"1575589140000"
        },
        "consensus_state":{
          "blockchain_length":"3",
          "epoch_count":"0",
          "min_window_density":"17280",
          "sub_window_densities":["0","2160","2160","2160","2160","2160","2160","2160"],
          "total_currency":10016100,
          "curr_global_slot":"876",
          "staking_epoch_data":{
            "ledger":{
              "hash":"94871860058829511941197580965871251548732616230752454083325990670651814240808931418260785","total_currency":"10016100"
            },
            "seed":"332637027557984585263317650500984572911029666110240270052776816409842001629441009391914692",
            "start_checkpoint":"332637027557984585263317650500984572911029666110240270052776816409842001629441009391914692",
            "lock_checkpoint":"332637027557984585263317650500984572911029666110240270052776816409842001629441009391914692",
            "epoch_length":"1"
          },
          "next_epoch_data":{
            "ledger":{
              "hash":"94871860058829511941197580965871251548732616230752454083325990670651814240808931418260785",
              "total_currency":"10016100"
            },
            "seed":"462413487290368418989241362526884989663742417695158096492844578975424787118345008659892827",
            "start_checkpoint":"332637027557984585263317650500984572911029666110240270052776816409842001629441009391914692",
            "lock_checkpoint":"471764816410381875562078664112022517870653866027141366117039751898972709923085604689661840",
            "epoch_length":"4"
          },
          "has_ancestor_in_same_checkpoint_window":true
        }
      }
    }
  }
}
```
