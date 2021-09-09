open Mina_base

module Insert =
[%graphql
{|
    mutation insert(
        $blocks: [blocks_insert_input!]!
        ) {
        insert_blocks(objects: $blocks, on_conflict: {constraint: blocks_state_hash_key, update_columns: state_hash_id}) {
          returning {
            state_hash {
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
    update_blocks(where: {state_hash: {value: {_eq: $hash}}}, _set: {status: $status}) {
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
      state_hash  {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
      parent_hash {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
    }
  }
|}]

module Get_stale_block_confirmations =
[%graphql
{|
  query query($parent_hash: String!) {
    get_stale_block_confirmations(args: {new_block_parent_hash: $parent_hash}) {
      state_hash {
        value @bsDecoder(fn: "State_hash.of_base58_check_exn")
      }
      status
    }
  }
|}]
