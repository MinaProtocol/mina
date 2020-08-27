#!/bin/bash

. lib.sh

req '/construction/preprocess' '{ network_identifier: { blockchain: "coda", network: "debug" }, max_fee: [{ value: "100000000", currency: { symbol: "CODA", decimals: 9 }}], operations: [{"operation_identifier":{"index":0},"related_operations":[],"_type":"fee_payer_dec","status":"Pending","account":{"address":"B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g","metadata":{"token_id":"1"}},"amount":{"value":"-2000000000","currency":{"symbol":"CODA","decimals":9}}},{"operation_identifier":{"index":1},"related_operations":[],"_type":"payment_source_dec","status":"Pending","account":{"address":"B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g","metadata":{"token_id":"1"}},"amount":{"value":"-5000000000","currency":{"symbol":"CODA","decimals":9}}},{"operation_identifier":{"index":2},"related_operations":[{"index":1}],"_type":"payment_receiver_inc","status":"Pending","account":{"address":"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv","metadata":{"token_id":"1"}},"amount":{"value":"5000000000","currency":{"symbol":"CODA","decimals":9}}}] }'

