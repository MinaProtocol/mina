open Core
open Mina_base
module Impl = Pickles.Impls.Step

[%%versioned
module Stable = struct
  module V1 = struct
    type ('ledger, 'pending_coinbase_stack, 'local_state) t =
          ( 'ledger
          , 'pending_coinbase_stack
          , 'local_state )
          Mina_wire_types.Mina_state.Registers.V1.t =
      { ledger : 'ledger
      ; pending_coinbase_stack : 'pending_coinbase_stack
      ; local_state : 'local_state
      }
    [@@deriving compare, equal, hash, sexp, yojson, hlist, fields]
  end
end]

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map ledger = Frozen_ledger_hash.gen
  and pending_coinbase_stack = Pending_coinbase.Stack.gen
  and local_state = Local_state.gen in
  { ledger; pending_coinbase_stack; local_state }

let to_input { ledger; pending_coinbase_stack; local_state } =
  Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
    [| Frozen_ledger_hash.to_input ledger
     ; Pending_coinbase.Stack.to_input pending_coinbase_stack
     ; Local_state.to_input local_state
    |]

let typ spec =
  Impl.Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

module Value = struct
  type t =
    ( Frozen_ledger_hash.t
    , Pending_coinbase.Stack.t
    , Local_state.t )
    Stable.Latest.t
  [@@deriving compare, equal, sexp, yojson, hash]

  let connected t t' =
    let module Without_pending_coinbase_stack = struct
      type t = (Frozen_ledger_hash.t, unit, Local_state.t) Stable.Latest.t
      [@@deriving compare, equal, sexp, yojson, hash]
    end in
    Without_pending_coinbase_stack.equal
      { t with pending_coinbase_stack = () }
      { t' with pending_coinbase_stack = () }
    && Pending_coinbase.Stack.connected ~first:t.pending_coinbase_stack
         ~second:t'.pending_coinbase_stack ()
end

module Checked = struct
  type nonrec t =
    (Ledger_hash.var, Pending_coinbase.Stack.var, Local_state.Checked.t) t

  let to_input { ledger; pending_coinbase_stack; local_state } =
    Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [| Frozen_ledger_hash.var_to_input ledger
       ; Pending_coinbase.Stack.var_to_input pending_coinbase_stack
       ; Local_state.Checked.to_input local_state
      |]

  let equal t1 t2 =
    let ( ! ) eq x1 x2 = Impl.run_checked (eq x1 x2) in
    let f eq acc field = eq (Field.get field t1) (Field.get field t2) :: acc in
    Fields.fold ~init:[] ~ledger:(f !Frozen_ledger_hash.equal_var)
      ~pending_coinbase_stack:(f !Pending_coinbase.Stack.equal_var)
      ~local_state:(fun acc f ->
        Local_state.Checked.equal' (Field.get f t1) (Field.get f t2) @ acc )
    |> Impl.Boolean.all
end
