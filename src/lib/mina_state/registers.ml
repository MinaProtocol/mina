open Core
open Mina_base
module Impl = Pickles.Impls.Step

[%%versioned
module Stable = struct
  module V1 = struct
    type ('ledger, 'pending_coinbase_stack, 'local_state) t =
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

module Blockchain = struct
  type ('ledger, 'pending_coinbase_stack, 'local_state) full_poly =
    ('ledger, 'pending_coinbase_stack, 'local_state) Stable.Latest.t

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('ledger, 'pending_coinbase_stack) t =
        { ledger : 'ledger; pending_coinbase_stack : 'pending_coinbase_stack }
      [@@deriving compare, equal, hash, sexp, yojson, hlist, fields]
    end
  end]

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map ledger = Frozen_ledger_hash.gen
    and pending_coinbase_stack = Pending_coinbase.Stack.gen in
    { ledger; pending_coinbase_stack }

  let to_input { ledger; pending_coinbase_stack } =
    Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [| Frozen_ledger_hash.to_input ledger
       ; Pending_coinbase.Stack.to_input pending_coinbase_stack
      |]

  let typ spec =
    Impl.Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let of_full ({ ledger; pending_coinbase_stack; _ } : _ full_poly) : _ t =
    { ledger; pending_coinbase_stack }

  module Value = struct
    type t = (Frozen_ledger_hash.t, Pending_coinbase.Stack.t) Stable.Latest.t
    [@@deriving compare, equal, sexp, yojson, hash]

    let connected t t' =
      let module Without_pending_coinbase_stack = struct
        type t = (Frozen_ledger_hash.t, unit) Stable.Latest.t
        [@@deriving compare, equal, sexp, yojson, hash]
      end in
      Without_pending_coinbase_stack.equal
        { t with pending_coinbase_stack = () }
        { t' with pending_coinbase_stack = () }
      && Pending_coinbase.Stack.connected ~first:t.pending_coinbase_stack
           ~second:t'.pending_coinbase_stack ()

    let to_full { ledger; pending_coinbase_stack } : _ full_poly =
      { ledger; pending_coinbase_stack; local_state = Local_state.empty () }

    let of_full = of_full
  end

  module Checked = struct
    type nonrec t = (Ledger_hash.var, Pending_coinbase.Stack.var) t

    let to_input { ledger; pending_coinbase_stack } =
      Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
        [| Frozen_ledger_hash.var_to_input ledger
         ; Pending_coinbase.Stack.var_to_input pending_coinbase_stack
        |]

    let equal t1 t2 =
      let ( ! ) eq x1 x2 = Impl.run_checked (eq x1 x2) in
      let f eq acc field =
        eq (Field.get field t1) (Field.get field t2) :: acc
      in
      Fields.fold ~init:[]
        ~ledger:(f !Frozen_ledger_hash.equal_var)
        ~pending_coinbase_stack:(f !Pending_coinbase.Stack.equal_var)
      |> Impl.Boolean.all

    let to_full { ledger; pending_coinbase_stack } : _ full_poly =
      let local_state =
        (* TODO: Use universal 'constant' function when
           https://github.com/o1-labs/snarky/pull/621 is merged.
        *)
        let (Typ typ) = Local_state.typ in
        let fields, aux = typ.value_to_fields (Local_state.empty ()) in
        let fields = Array.map ~f:Snark_params.Tick.Field.Var.constant fields in
        typ.var_of_fields (fields, aux)
      in
      { ledger; pending_coinbase_stack; local_state }

    let of_full = of_full
  end
end
