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
