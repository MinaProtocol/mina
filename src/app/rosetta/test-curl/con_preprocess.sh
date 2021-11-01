#!/bin/bash

. lib.sh

req '/construction/preprocess' '{"network_identifier": { "blockchain": "mina", "network": "debug" }, "max_fee": [{ "value": "100000000", "currency": { "symbol": "MINA", "decimals": 9 }}], "operations": [{"operation_identifier":{"index":0},"related_operations":[],"type":"fee_payment","status":"Pending","account":{"address":"B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV","metadata":{"token_id":"1"}},"amount":{"value":"-2000000000","currency":{"symbol":"MINA","decimals":9}}},{"operation_identifier":{"index":1},"related_operations":[],"type":"payment_source_dec","status":"Pending","account":{"address":"B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV","metadata":{"token_id":"1"}},"amount":{"value":"-5000000000","currency":{"symbol":"MINA","decimals":9}}},{"operation_identifier":{"index":2},"related_operations":[{"index":1}],"type":"payment_receiver_inc","status":"Pending","account":{"address":"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv","metadata":{"token_id":"1"}},"amount":{"value":"5000000000","currency":{"symbol":"MINA","decimals":9}}}]}'

