(* sql.ml -- (Postgresql) SQL queries for extract_blocks app *)

module Subchain = struct
  let make_sql ~join_condition =
    let insert_commas s = Core_kernel.String.concat ~sep:"," s in
    let fields = insert_commas Archive_lib.Processor.Block.Fields.names in
    let b_fields =
      insert_commas
      @@ Core_kernel.List.map Archive_lib.Processor.Block.Fields.names
           ~f:(fun field -> "b." ^ field)
    in
    Core_kernel.sprintf
      {sql| WITH RECURSIVE chain AS (

              SELECT %s
              FROM blocks b WHERE b.state_hash = $1

              UNION ALL

              SELECT %s
              FROM blocks b

              INNER JOIN chain

              ON %s
           )

           SELECT %s
           FROM chain
      |sql}
      fields b_fields join_condition fields

  let query_unparented =
    Mina_caqti.collect_req Caqti_type.string Archive_lib.Processor.Block.typ
      (make_sql ~join_condition:"b.id = chain.parent_id")

  let query_from_start =
    Mina_caqti.collect_req
      Caqti_type.(t2 string string)
      Archive_lib.Processor.Block.typ
      (make_sql
         ~join_condition:
           "b.id = chain.parent_id AND (chain.state_hash <> $2 OR b.state_hash \
            = $2)" )

  let start_from_unparented (module Conn : Mina_caqti.CONNECTION)
      ~end_state_hash =
    Conn.collect_list query_unparented end_state_hash

  let start_from_specified (module Conn : Mina_caqti.CONNECTION)
      ~start_state_hash ~end_state_hash =
    Conn.collect_list query_from_start (end_state_hash, start_state_hash)

  let query_all =
    let open Core_kernel in
    let comma_fields =
      String.concat Archive_lib.Processor.Block.Fields.names ~sep:","
    in
    Mina_caqti.collect_req Caqti_type.unit Archive_lib.Processor.Block.typ
      (sprintf "SELECT %s FROM blocks" comma_fields)

  let all_blocks (module Conn : Mina_caqti.CONNECTION) =
    Conn.collect_list query_all ()
end

(* Archive_lib.Processor does not have the queries given here *)

module Blocks_and_user_commands = struct
  let query =
    Mina_caqti.collect_req Caqti_type.int
      Caqti_type.(t2 int int)
      {sql| SELECT user_command_id, sequence_no
            FROM blocks_user_commands
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Block_user_command_tokens = struct
  type t = Archive_lib.Processor.Token.t =
    { value : string
    ; owner_public_key_id : int option
    ; owner_token_id : int option
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; option int; option int ]

  let query =
    Mina_caqti.collect_req Caqti_type.int typ
      {sql| SELECT tokens.value, owner_public_key_id, owner_token_id
            FROM (blocks_user_commands buc
            INNER JOIN blocks
            ON blocks.id = buc.block_id)
            INNER JOIN user_commands uc
            ON buc.user_command_id = uc.id
            INNER JOIN account_identifiers ai
            ON (uc.fee_payer_id = ai.id OR uc.source_id = ai.id OR uc.receiver_id = ai.id)
            INNER JOIN tokens
            ON ai.token_id = tokens.id
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Blocks_and_internal_commands = struct
  type t =
    { internal_command_id : int
    ; sequence_no : int
    ; secondary_sequence_no : int
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ int; int; int ]

  let query =
    Mina_caqti.collect_req Caqti_type.int typ
      {sql| SELECT internal_command_id, sequence_no, secondary_sequence_no
            FROM (blocks_internal_commands
            INNER JOIN blocks
            ON blocks.id = blocks_internal_commands.block_id)
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Block_internal_command_tokens = struct
  type t = Archive_lib.Processor.Token.t =
    { value : string
    ; owner_public_key_id : int option
    ; owner_token_id : int option
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; option int; option int ]

  let query =
    Mina_caqti.collect_req Caqti_type.int typ
      {sql| SELECT tokens.value, owner_public_key_id, owner_token_id
            FROM (blocks_internal_commands bic
            INNER JOIN blocks
            ON blocks.id = bic.block_id)
            INNER JOIN internal_commands ic
            ON bic.internal_command_id = ic.id
            INNER JOIN account_identifiers ai
            ON ic.receiver_id = ai.id
            INNER JOIN tokens
            ON ai.token_id = tokens.id
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Blocks_and_zkapp_commands = struct
  let query =
    Mina_caqti.collect_req Caqti_type.int
      Caqti_type.(t2 int int)
      {sql| SELECT zkapp_command_id, sequence_no
            FROM blocks_zkapp_commands
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end

module Block_zkapp_command_tokens = struct
  type t = Archive_lib.Processor.Token.t =
    { value : string
    ; owner_public_key_id : int option
    ; owner_token_id : int option
    }
  [@@deriving hlist]

  let typ =
    Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
      Caqti_type.[ string; option int; option int ]

  let query =
    Mina_caqti.collect_req Caqti_type.int typ
      {sql| SELECT tokens.value, owner_public_key_id, owner_token_id
            FROM (blocks_zkapp_commands bzkc
            INNER JOIN blocks
            ON blocks.id = bzkc.block_id)
            INNER JOIN zkapp_commands zkc
            ON bzkc.zkapp_command_id = zkc.id
            INNER JOIN account_identifiers ai



            ON ic.receiver_id = ai.id
            INNER JOIN tokens
            ON ai.token_id = tokens.id
            WHERE block_id = ?
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) ~block_id =
    Conn.collect_list query block_id
end
