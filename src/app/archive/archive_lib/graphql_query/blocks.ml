open Coda_base

module Insert =
[%graphql
{|
    mutation insert(
        $blocks: [blocks_insert_input!]!
        ) {
        insert_blocks(objects: $blocks, on_conflict: {constraint: blocks_state_hash_key, update_columns: state_hash}) {
          returning {
            stateHashByStateHash {
              value @bsDecoder(fn: "State_hash.of_base58_check_exn")
            }
          }
        }
      }
    |}]

module Update_block_confirmations =
[%graphql
{|
  mutation update($hash: String!, $status: Int!) {
    update_blocks(where: {stateHashByStateHash: {value: {_eq: $hash}}}, _set: {status: $status}) {
      affected_rows
    }
  }
|}]

module Get_all_pending_blocks =
[%graphql
{|
  query get_all_pending_blocks {
    blocks(where: {status: {_gte: 0}}) {
      status
      state_hash: stateHashByStateHash  {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
      parent_state_hash: stateHashByParentHash {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
    }
  }
|}]

module Query_blocks_with_confirmations =
[%graphql
{|
  query query {
    blocks {
      state_hash: stateHashByStateHash  {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
      status
    }
  }
|}]

module Batch_query_updated_block_confirmations =
[%graphql
{|
  query query($hash: String!, $new_updated_confirmation_number: Int!) {
    state_hash_path(args: {state_hash_with_new_child: $hash, new_updated_confirmation_number: $new_updated_confirmation_number}) {
      state_hash : stateHashByStateHash {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
      parent_state_hash: stateHashByParentHash {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
    }
  }
|}]
