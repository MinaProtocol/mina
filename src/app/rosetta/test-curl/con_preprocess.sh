#!/bin/bash

. lib.sh

# req '/construction/preprocess' '{"network_identifier": { "blockchain": "mina", "network": "mainnet" }, "operations": [{"operation_identifier":{"index":0},"related_operations":[],"type":"fee_payment","account":{"address":"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk","metadata":{"token_id":"1"}},"amount":{"value":"-2000000000","currency":{"symbol":"MINA","decimals":9}}},{"operation_identifier":{"index":1},"related_operations":[],"type":"payment_source_dec","account":{"address":"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk","metadata":{"token_id":"1"}},"amount":{"value":"-5000000000","currency":{"symbol":"MINA","decimals":9}}},{"operation_identifier":{"index":2},"related_operations":[{"index":1}],"type":"payment_receiver_inc","account":{"address":"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv","metadata":{"token_id":"1"}},"amount":{"value":"5000000000","currency":{"symbol":"MINA","decimals":9}}}], "metadata": {"valid_until": "200000", "memo": "hello"}}'

REQ='{
  "network_identifier": {
    "blockchain": "mina",
    "network": "mainnet"
  },
  "operations": [
    {
      "operation_identifier": {
        "index": 0
      },
      "related_operations": [],
      "type": "fee_payment",
      "account": {
        "address": "B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk",
        "metadata": {
          "token_id": "1"
        }
      },
      "amount": {
        "value": "-2000000000",
        "currency": {
          "symbol": "MINA",
          "decimals": 9
        }
      }
    },
    {
      "operation_identifier": {
        "index": 1
      },
      "related_operations": [],
      "type": "payment_source_dec",
      "account": {
        "address": "B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk",
        "metadata": {
          "token_id": "1"
        }
      },
      "amount": {
        "value": "-5000000000",
        "currency": {
          "symbol": "MINA",
          "decimals": 9
        }
      }
    },
    {
      "operation_identifier": {
        "index": 2
      },
      "related_operations": [
        {
          "index": 1
        }
      ],
      "type": "payment_receiver_inc",
      "account": {
        "address": "B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv",
        "metadata": {
          "token_id": "1"
        }
      },
      "amount": {
        "value": "5000000000",
        "currency": {
          "symbol": "MINA",
          "decimals": 9
        }
      }
    }
  ],
  "metadata": {
    "valid_until": "200000",
    "memo": "hello"
  }
}'

req '/construction/preprocess' "$REQ"
