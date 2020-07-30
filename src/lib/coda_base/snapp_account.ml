open Core_kernel
open Snark_params.Tick
module Frozen_ledger_hash = Frozen_ledger_hash0
module Ledger_hash = Ledger_hash0

module Permissions = struct
  module Controller = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Either
          | Verification_key
          | Private_key
          | Both (* Both and either can both be subsumed in verification key.
            It is good to have "Either" as a separate thing to spare the owner from
            having to make a proof instead of a signature. Both, I'm not sure if there's
            a good justification for. *)
        [@@deriving sexp, eq, compare, hash, yojson]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t = Either | Verification_key | Private_key | Both
    [@@deriving sexp, eq, compare, hash, yojson]

    module Checked = struct
      type t = {verification_key: Boolean.var; private_key: Boolean.var}
      [@@deriving hlist]

      let to_input t =
        let [x; y] = to_hlist t in
        Random_oracle.Input.bitstring [x; y]
    end

    let to_bits : t -> (unit, _) H_list.t = function
      | Either ->
          [false; false]
      | Verification_key ->
          [false; true]
      | Private_key ->
          [true; false]
      | Both ->
          [true; true]

    let typ =
      let t =
        Typ.of_hlistable [Boolean.typ; Boolean.typ]
          ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
          ~value_to_hlist:Fn.id ~value_of_hlist:Fn.id
      in
      Typ.transport t ~there:to_bits ~back:(function
        | [false; false] ->
            Either
        | [false; true] ->
            Verification_key
        | [true; false] ->
            Private_key
        | [true; true] ->
            Both )

    let to_input t =
      let [x; y] = to_bits t in
      Random_oracle.Input.bitstring [x; y]
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('bool, 'controller) t =
          { stake: 'bool
          ; edit_state: 'controller
          ; send: 'controller
          ; set_delegate: 'controller }
        [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
      end
    end]

    let to_input controller t =
      let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
      Stable.Latest.Fields.fold ~init:[]
        ~stake:(f (fun x -> Random_oracle.Input.bitstring [x]))
        ~edit_state:(f controller) ~send:(f controller)
        ~set_delegate:(f controller)
      |> List.reduce_exn ~f:Random_oracle.Input.append
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (bool, Controller.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  module Checked = struct
    type t = (Boolean.var, Controller.Checked.t) Poly.Stable.Latest.t

    let to_input = Poly.to_input Controller.Checked.to_input
  end

  let to_input = Poly.to_input Controller.to_input

  let typ =
    let open Poly.Stable.Latest in
    Typ.of_hlistable
      [Boolean.typ; Controller.typ; Controller.typ; Controller.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Closed_interval = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {lower: 'a; upper: 'a}
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {lower: 'a; upper: 'a}
  [@@deriving sexp, eq, compare, hash, yojson, hlist]

  let typ x =
    Typ.of_hlistable [x; x] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Or_ignore = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = Check of 'a | Ignore
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = Check of 'a | Ignore

  module Checked : sig
    type 'a t

    val typ :
         equal:('a -> 'a -> bool)
      -> ignore:'a
      -> ('a_var, 'a) Typ.t
      -> ('a_var t, 'a Stable.Latest.t) Typ.t
  end = struct
    type 'a t = 'a

    let typ ~equal ~ignore t =
      Typ.transport t
        ~there:(function Check x -> x | Ignore -> ignore)
        ~back:(fun x -> if equal x ignore then Ignore else Check x)
  end

  let typ = Checked.typ
end

(* Proofs are produced against a predicate on the protocol state. For the
   transaction to go through, the predicate must be satisfied of the protocol
   state at the time of transaction application. *)
module Protocol_state_predicate = struct
  (* On each numeric field, you may assert a range
     On each hash field, you may assert an equality
  *)

  module Numeric = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'a t = 'a Closed_interval.Stable.V1.t Or_ignore.Stable.V1.t
        [@@deriving eq]
      end
    end]

    type 'a t = 'a Stable.Latest.t [@@deriving eq]

    module Checked = struct
      type 'a t = 'a Closed_interval.t Or_ignore.Checked.t
    end

    let typ n ~equal:eq ~zero ~max_value =
      Or_ignore.typ (Closed_interval.typ n) ~equal:(Closed_interval.equal eq)
        ~ignore:{Closed_interval.lower= zero; upper= max_value}
  end

  module Hash = Or_ignore

  module Epoch_data = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             t =
          { ledger: 'epoch_ledger
          ; seed: 'epoch_seed
          ; start_checkpoint: 'start_checkpoint
          ; lock_checkpoint: 'lock_checkpoint
          ; epoch_length: 'length }
        [@@deriving hlist]
      end
    end]

    type ( 'epoch_ledger
         , 'epoch_seed
         , 'start_checkpoint
         , 'lock_checkpoint
         , 'length )
         t =
          ( 'epoch_ledger
          , 'epoch_seed
          , 'start_checkpoint
          , 'lock_checkpoint
          , 'length )
          Stable.Latest.t =
      { ledger: 'epoch_ledger
      ; seed: 'epoch_seed
      ; start_checkpoint: 'start_checkpoint
      ; lock_checkpoint: 'lock_checkpoint
      ; epoch_length: 'length }
    [@@deriving hlist]
  end

  module Leafs = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'staged_ledger_hash_ledger_hash
             , 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t =
          { staged_ledger_hash_ledger_hash: 'staged_ledger_hash_ledger_hash
          ; snarked_ledger_hash: 'snarked_ledger_hash
          ; snarked_next_available_token: 'token_id
          ; timestamp: 'time
          ; blockchain_length: 'length
          ; epoch_count: 'length
          ; min_window_density: 'length
          ; last_vrf_output: 'vrf_output
          ; total_currency: 'amount
          ; curr_global_slot: 'global_slot
          ; staking_epoch_data: 'epoch_data
          ; next_epoch_data: 'epoch_data }
        [@@deriving hlist]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Ledger_hash.Stable.V1.t Hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t Hash.Stable.V1.t
        , Token_id.Stable.V1.t Numeric.Stable.V1.t
        , Block_time.Stable.V1.t Numeric.Stable.V1.t
        , Coda_numbers.Length.Stable.V1.t Numeric.Stable.V1.t
        , unit (* TODO *)
        , Coda_numbers.Global_slot.Stable.V1.t Numeric.Stable.V1.t
        , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t
        (* TODO: Not sure if this should be frozen ledger hash or not *)
        , ( ( Frozen_ledger_hash.Stable.V1.t Hash.Stable.V1.t
            , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t )
            Epoch_ledger.Poly.Stable.V1.t
          , unit (* TODO *)
          , State_hash.Stable.V1.t Hash.Stable.V1.t
          , State_hash.Stable.V1.t Hash.Stable.V1.t
          , Coda_numbers.Length.Stable.V1.t Numeric.Stable.V1.t )
          Epoch_data.Stable.V1.t )
        Leafs.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  module Checked = struct
    type t =
      ( Ledger_hash.var Hash.Checked.t
      , Frozen_ledger_hash.var Hash.Checked.t
      , Token_id.var Numeric.Checked.t
      , Block_time.Unpacked.var Numeric.Checked.t
      , Coda_numbers.Length.Checked.t Numeric.Checked.t
      , unit (* TODO *)
      , Coda_numbers.Global_slot.Checked.t Numeric.Checked.t
      , Currency.Amount.var Numeric.Checked.t
      , ( ( Frozen_ledger_hash.var Hash.Checked.t
          , Currency.Amount.var Numeric.Checked.t )
          Epoch_ledger.Poly.t
        , unit (* TODO *)
        , State_hash.var Hash.Checked.t
        , State_hash.var Hash.Checked.t
        , Coda_numbers.Length.Checked.t Numeric.Checked.t )
        Epoch_data.t )
      Leafs.Stable.Latest.t
  end

  let typ : (Checked.t, Stable.Latest.t) Typ.t =
    let open Coda_numbers in
    let open Leafs.Stable.Latest in
    let ledger_hash = Ledger_hash.(Hash.typ ~ignore:Field.zero ~equal typ) in
    let frozen_ledger_hash =
      Frozen_ledger_hash.(Hash.typ ~ignore:Field.zero ~equal typ)
    in
    let state_hash = State_hash.(Hash.typ ~ignore:Field.zero ~equal typ) in
    let length = Length.(Numeric.typ ~equal ~zero ~max_value typ) in
    let time = Block_time.(Numeric.typ ~equal ~zero ~max_value Unpacked.typ) in
    let amount =
      Currency.Amount.(Numeric.typ ~equal ~zero ~max_value:max_int typ)
    in
    let global_slot =
      Coda_numbers.Global_slot.(Numeric.typ ~equal ~zero ~max_value typ)
    in
    let token_id =
      Token_id.(
        Numeric.typ ~equal
          ~zero:(of_uint64 Unsigned.UInt64.zero)
          ~max_value:(of_uint64 Unsigned.UInt64.max_int)
          typ)
    in
    let epoch_data =
      let epoch_ledger =
        let open Epoch_ledger.Poly in
        Typ.of_hlistable
          [frozen_ledger_hash; amount]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      in
      let open Epoch_data in
      Typ.of_hlistable
        [epoch_ledger; Typ.unit; state_hash; state_hash; length]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
    in
    Typ.of_hlistable
      [ ledger_hash
      ; frozen_ledger_hash
      ; token_id
      ; time
      ; length
      ; length
      ; length
      ; Typ.unit
      ; amount
      ; global_slot
      ; epoch_data
      ; epoch_data ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

open Pickles_types
module Max_state_size = Nat.N4
module App_state = Vector.With_length (Max_state_size)

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('app_state, 'perms, 'vk) t =
        {app_state: 'app_state; permissions: 'perms; verification_key: 'vk}
      [@@deriving sexp, eq, compare, hash, yojson, hlist]
    end
  end]

  type ('app_state, 'perms, 'vk) t =
        ('app_state, 'perms, 'vk) Stable.Latest.t =
    {app_state: 'app_state; permissions: 'perms; verification_key: 'vk}
  [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Pickles.Backend.Tick.Field.Stable.V1.t App_state.Stable.V1.t
      , Permissions.Stable.V1.t
      , Pickles.Side_loaded.Verification_key.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]

module Checked = struct
  type t =
    ( (Pickles.Impls.Step.Field.t, Max_state_size.n) Vector.t
    , Permissions.Checked.t
    , Pickles.Side_loaded.Verification_key.Checked.t )
    Poly.t

  let to_input (t : t) =
    let open Random_oracle.Input in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
    Poly.Fields.fold ~init:[]
      ~permissions:(f Permissions.Checked.to_input)
      ~app_state:(f app_state)
      ~verification_key:
        (f Pickles.Side_loaded.Verification_key.Checked.to_input)
    |> List.reduce_exn ~f:append
end

let typ : (Checked.t, t) Typ.t =
  let open Poly in
  Typ.of_hlistable
    [ Vector.typ Field.typ Max_state_size.n
    ; Permissions.typ
    ; Pickles.Side_loaded.Verification_key.typ ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
  Poly.Fields.fold ~init:[] ~permissions:(f Permissions.to_input)
    ~app_state:(f app_state)
    ~verification_key:(f Pickles.Side_loaded.Verification_key.to_input)
  |> List.reduce_exn ~f:append
