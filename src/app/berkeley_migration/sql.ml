(* sql.ml -- for reading the mainnet and berkeley databases (no writing!) *)

open Core
open Caqti_async

module Mainnet = struct
  module Public_key = struct
    let typ : Signature_lib.Public_key.Compressed.t Caqti_type.t =
      let encode c = Ok (Signature_lib.Public_key.Compressed.to_base58_check c) in
      let decode s = Result.map_error ~f:Error.to_string_hum @@ Signature_lib.Public_key.Compressed.of_base58_check s in
      Caqti_type.custom ~encode ~decode Caqti_type.string

    let table_name = "public_keys"

    let find_by_id (module Conn : CONNECTION) id =
      Conn.find
        (Caqti_request.find Caqti_type.int Caqti_type.string
           "SELECT value FROM public_keys WHERE id = ?" )
        id
  end

  module Snarked_ledger_hash = struct
    let find_by_id (module Conn : CONNECTION) id =
      Conn.find
        (Caqti_request.find Caqti_type.int Caqti_type.string
           "SELECT value FROM snarked_ledger_hashes WHERE id = ?" )
        id
  end

  module Block = struct
    type t =
      { id : int
      ; state_hash : string
      ; parent_id : int option
      ; parent_hash : string
      ; creator_id : int
      ; block_winner_id : int
      ; snarked_ledger_hash_id : int
      ; staking_epoch_data_id : int
      ; next_epoch_data_id : int
      ; ledger_hash : string
      ; height : int64
      ; global_slot_since_genesis : int64
      ; global_slot_since_hard_fork : int64
      ; timestamp : int64
      ; chain_status : string
      }
    [@@deriving hlist]

    let typ =
      let open Mina_caqti.Type_spec in
      let spec =
        Caqti_type.
          [ int
          ; string
          ; option int
          ; string
          ; int
          ; int
          ; int
          ; int
          ; int
          ; string
          ; int64
          ; int64
          ; int64
          ; int64
          ; string
          ]
      in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let id_from_state_hash (module Conn : CONNECTION) state_hash =
      Conn.find
        (Caqti_request.find Caqti_type.string Caqti_type.int
           {sql| SELECT id
                 FROM blocks
                 WHERE state_hash = ?
         |sql} )
        state_hash

    let load (module Conn : CONNECTION) ~(id : int) =
      Conn.find
        (Caqti_request.find Caqti_type.int typ
           {sql| SELECT id, state_hash, parent_id, parent_hash, creator_id,
                        block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id,
                        next_epoch_data_id, ledger_hash, height, global_slot,
                        global_slot_since_genesis, timestamp, chain_status FROM blocks
                 WHERE id = ?                                                                                                    |sql} )
        id

    let canonical_blocks (module Conn : CONNECTION) =
      Conn.collect_list
        (Caqti_request.collect Caqti_type.unit Caqti_type.int
           {sql| SELECT id
                 FROM blocks
                 WHERE chain_status = 'canonical'
         |sql} )

    let full_canonical_blocks (module Conn : CONNECTION) =
      Conn.collect_list
        (Caqti_request.collect Caqti_type.unit typ
           {sql| SELECT id, state_hash, parent_id, parent_hash, creator_id,
                        block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id,
                        next_epoch_data_id, ledger_hash, height, global_slot,
                        global_slot_since_genesis, timestamp, chain_status
                 FROM blocks
                 WHERE chain_status = 'canonical'
                 ORDER BY height ASC
         |sql} )

    let mark_as_canonical (module Conn : CONNECTION) id =
      Conn.exec
        (Caqti_request.exec Caqti_type.int
           "UPDATE blocks SET chain_status='canonical' WHERE id = ?" )
        id

    let get_highest_canonical_block (module Conn : CONNECTION) =
      Conn.find
        (Caqti_request.find Caqti_type.unit Caqti_type.int
           "SELECT id FROM blocks WHERE chain_status='canonical' ORDER BY \
            height DESC LIMIT 1" )

    let get_subchain (module Conn : CONNECTION) ~start_block_id ~end_block_id =
      (* derive query from type `t` *)
      Conn.collect_list
        (Caqti_request.collect
           Caqti_type.(tup2 int int)
           Caqti_type.int
           {sql| WITH RECURSIVE chain AS (
                    SELECT id, parent_id, height
                    FROM blocks b WHERE b.id = $1

                    UNION ALL

                    SELECT b.id, b.parent_id, b.height
                    FROM blocks b

                    INNER JOIN chain

                    ON b.id = chain.parent_id AND (chain.id <> $2 OR b.id = $2)

                 )

                 SELECT id
                 FROM chain ORDER BY height ASC
               |sql} )
        (end_block_id, start_block_id)
  end

  module Block_user_command = struct
    type t =
      { block_id : int
      ; user_command_id : int
      ; sequence_no : int
      ; status : string
      ; failure_reason : string option
      ; fee_payer_account_creation_fee_paid : int64 option
      ; receiver_account_creation_fee_paid : int64 option
      ; created_token : int64 option
      ; fee_payer_balance : int
      ; source_balance : int option
      ; receiver_balance : int option
      }
    [@@deriving hlist, fields]

    let table_name = "blocks_user_commands"

    let typ =
      let open Mina_caqti.Type_spec in
      let spec =
        Caqti_type.
          [ int
          ; int
          ; int
          ; string
          ; option string
          ; option int64
          ; option int64
          ; option int64
          ; int
          ; option int
          ; option int
          ]
      in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let load_block (module Conn : CONNECTION) ~block_id =
      Conn.collect_list
        (Caqti_request.collect Caqti_type.int typ
           {sql| SELECT block_id, user_command_id,
               sequence_no,
               status,failure_reason,
               fee_payer_account_creation_fee_paid,
               receiver_account_creation_fee_paid,
               created_token,
               fee_payer_balance,
               source_balance,
               receiver_balance
               FROM blocks_user_commands
               WHERE block_id = $1
               ORDER BY sequence_no
             |sql} )
        block_id
  end

  module Block_internal_command = struct
    type t =
      { block_id : int
      ; internal_command_id : int
      ; sequence_no : int
      ; secondary_sequence_no : int
      ; receiver_account_creation_fee_paid : int64 option
      ; receiver_balance : int
      }
    [@@deriving hlist, fields]

    let table_name = "blocks_internal_commands"

    let typ =
      let open Mina_caqti.Type_spec in
      let spec = Caqti_type.[ int; int; int; int; option int64; int ] in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let load_block (module Conn : CONNECTION) ~block_id =
      Conn.collect_list
        (Caqti_request.collect Caqti_type.int typ
           {sql| SELECT block_id, internal_command_id,
                 sequence_no, secondary_sequence_no,
                 receiver_account_creation_fee_paid,
                receiver_balance
                FROM blocks_internal_commands
                WHERE block_id = $1
                ORDER BY sequence_no, secondary_sequence_no
           |sql} )
        block_id
  end

  module Internal_command = struct
    type t =
      { typ : string
      ; receiver_id : int
      ; fee : int64
      ; token : int64
      ; hash : string
      }

    (* cannot be derived from Fields.names because `type` is an invalid identifier in ocaml *)
    let field_names =
      [ "type"
      ; "receiver_id"
      ; "fee"
      ; "token"
      ; "hash"
      ]

    let table_name = "internal_commands"

    let typ =
      let encode t = Ok ((t.typ, t.receiver_id, t.fee, t.token), t.hash) in
      let decode ((typ, receiver_id, fee, token), hash) =
        Ok { typ; receiver_id; fee; token; hash }
      in
      let rep = Caqti_type.(tup2 (tup4 string int int64 int64) string) in
      Caqti_type.custom ~encode ~decode rep

    let load (module Conn : CONNECTION) ~(id : int) =
      Conn.find
        (Caqti_request.find Caqti_type.int typ
           {sql| SELECT type,receiver_id,fee,token,hash
                 FROM internal_commands
                 WHERE id = ?
           |sql} )
        id
  end

  module User_command = struct
    type t =
      { typ : string
      ; fee_payer_id : int
      ; source_id : int
      ; receiver_id : int
      ; fee_token : int64
      ; token : int64
      ; nonce : int
      ; amount : int64 option
      ; fee : int64
      ; valid_until : int64 option
      ; memo : string
      ; hash : string
      }
    [@@deriving hlist]

    (* cannot be derived from Fields.names because `type` is an invalid identifier in ocaml *)
    let field_names =
      [ "type"
      ; "fee_payer_id"
      ; "source_id"
      ; "receiver_id"
      ; "fee_token"
      ; "token"
      ; "nonce"
      ; "amount"
      ; "fee"
      ; "valid_until"
      ; "memo"
      ; "hash"
      ]

    let table_name = "user_commands"

    let typ =
      let open Mina_caqti.Type_spec in
      let spec =
        Caqti_type.
          [ string
          ; int
          ; int
          ; int
          ; int64
          ; int64
          ; int
          ; option int64
          ; int64
          ; option int64
          ; string
          ; string
          ]
      in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let load (module Conn : CONNECTION) ~(id : int) =
      Conn.find
        (Caqti_request.find Caqti_type.int typ
           {sql| SELECT type,fee_payer_id,source_id,receiver_id,
                 fee_token,token,
                 nonce,amount,fee,valid_until,memo,hash
                 FROM user_commands
                 WHERE id = ?                                                                                                                                                                                                                           |sql} )
        id
  end
end

module Berkeley = struct
  module Block = struct
    let count (module Conn : CONNECTION) =
      Conn.find
        (Caqti_request.find Caqti_type.unit Caqti_type.int
           {sql| SELECT count (*)
                 FROM blocks
           |sql} )

    let greatest_block_height (module Conn : CONNECTION) =
      Conn.find
        (Caqti_request.find Caqti_type.unit Caqti_type.int64
           {sql| SELECT height
                 FROM blocks
                 WHERE chain_status <> 'orphaned'
                 ORDER BY height DESC
                 LIMIT 1
           |sql} )
  end
end
