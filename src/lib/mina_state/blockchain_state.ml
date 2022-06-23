open Core_kernel
open Mina_base
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ( 'staged_ledger_hash
           , 'snarked_ledger_hash
           , 'local_state
           , 'time
           , 'body_reference )
           t =
        { staged_ledger_hash : 'staged_ledger_hash
        ; genesis_ledger_hash : 'snarked_ledger_hash
        ; registers :
            ('snarked_ledger_hash, unit, 'local_state) Registers.Stable.V1.t
        ; timestamp : 'time
        ; body_reference : 'body_reference
        }
      [@@deriving sexp, fields, equal, compare, hash, yojson, hlist]
    end
  end]
end

[%%define_locally
Poly.
  ( staged_ledger_hash
  , genesis_ledger_hash
  , timestamp
  , body_reference
  , registers
  , to_hlist
  , of_hlist )]

let snarked_ledger_hash (t : _ Poly.t) = t.registers.ledger

module Value = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Staged_ledger_hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t
        , Local_state.Stable.V1.t
        , Block_time.Stable.V1.t
        , Consensus.Body_reference.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

type var =
  ( Staged_ledger_hash.var
  , Frozen_ledger_hash.var
  , Local_state.Checked.t
  , Block_time.Checked.t
  , Consensus.Body_reference.var )
  Poly.t

let create_value ~staged_ledger_hash ~genesis_ledger_hash ~registers ~timestamp
    ~body_reference =
  { Poly.staged_ledger_hash
  ; timestamp
  ; genesis_ledger_hash
  ; registers
  ; body_reference
  }

let data_spec =
  let open Data_spec in
  [ Staged_ledger_hash.typ
  ; Frozen_ledger_hash.typ
  ; Registers.typ [ Frozen_ledger_hash.typ; Typ.unit; Local_state.typ ]
  ; Block_time.Checked.typ
  ; Consensus.Body_reference.typ
  ]

let typ : (var, Value.t) Typ.t =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

module Impl = Pickles.Impls.Step

let var_to_input
    ({ staged_ledger_hash
     ; genesis_ledger_hash
     ; registers
     ; timestamp
     ; body_reference
     } :
      var ) : Field.Var.t Random_oracle.Input.Chunked.t =
  let open Random_oracle.Input.Chunked in
  let registers =
    (* TODO: If this were the actual Registers itself (without the unit arg)
       then we could more efficiently deal with the transaction SNARK input
       (as we could reuse the hash)
    *)
    let { ledger; pending_coinbase_stack = (); local_state } = registers in
    Array.reduce_exn ~f:append
      [| Frozen_ledger_hash.var_to_input ledger
       ; Local_state.Checked.to_input local_state
      |]
  in
  List.reduce_exn ~f:append
    [ Staged_ledger_hash.var_to_input staged_ledger_hash
    ; Frozen_ledger_hash.var_to_input genesis_ledger_hash
    ; registers
    ; Block_time.Checked.to_input timestamp
    ; Consensus.Body_reference.var_to_input body_reference
    ]

let to_input
    ({ staged_ledger_hash
     ; genesis_ledger_hash
     ; registers
     ; timestamp
     ; body_reference
     } :
      Value.t ) =
  let open Random_oracle.Input.Chunked in
  let registers =
    (* TODO: If this were the actual Registers itself (without the unit arg)
       then we could more efficiently deal with the transaction SNARK input
       (as we could reuse the hash)
    *)
    let { ledger; pending_coinbase_stack = (); local_state } = registers in
    Array.reduce_exn ~f:append
      [| Frozen_ledger_hash.to_input ledger; Local_state.to_input local_state |]
  in
  List.reduce_exn ~f:append
    [ Staged_ledger_hash.to_input staged_ledger_hash
    ; Frozen_ledger_hash.to_input genesis_ledger_hash
    ; registers
    ; Block_time.to_input timestamp
    ; Consensus.Body_reference.to_input body_reference
    ]

let set_timestamp t timestamp = { t with Poly.timestamp }

let negative_one
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(consensus_constants : Consensus.Constants.t) ~genesis_ledger_hash
    ~genesis_body_reference : Value.t =
  { staged_ledger_hash =
      Staged_ledger_hash.genesis ~constraint_constants ~genesis_ledger_hash
  ; genesis_ledger_hash
  ; registers =
      { ledger = genesis_ledger_hash
      ; pending_coinbase_stack = ()
      ; local_state = Local_state.dummy ()
      }
  ; timestamp = consensus_constants.genesis_state_timestamp
  ; body_reference = genesis_body_reference
  }

(* negative_one and genesis blockchain states are equivalent *)
let genesis = negative_one

type display = (string, string, Local_state.display, string, string) Poly.t
[@@deriving yojson]

let display
    ({ staged_ledger_hash
     ; genesis_ledger_hash
     ; registers = { ledger; pending_coinbase_stack = (); local_state }
     ; timestamp
     ; body_reference
     } :
      Value.t ) : display =
  { Poly.staged_ledger_hash =
      Visualization.display_prefix_of_string @@ Ledger_hash.to_base58_check
      @@ Staged_ledger_hash.ledger_hash staged_ledger_hash
  ; genesis_ledger_hash =
      Visualization.display_prefix_of_string
      @@ Frozen_ledger_hash.to_base58_check @@ genesis_ledger_hash
  ; registers =
      { ledger =
          Visualization.display_prefix_of_string
          @@ Frozen_ledger_hash.to_base58_check ledger
      ; pending_coinbase_stack = ()
      ; local_state = Local_state.display local_state
      }
  ; timestamp =
      Time.to_string_trimmed ~zone:Time.Zone.utc (Block_time.to_time timestamp)
  ; body_reference =
      Visualization.display_prefix_of_string
      @@ Consensus.Body_reference.to_hex body_reference
  }
