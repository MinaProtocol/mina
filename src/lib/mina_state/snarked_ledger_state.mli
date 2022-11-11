open Core
open Mina_base
open Snark_params
open Currency

module Pending_coinbase_stack_state : sig
  module Init_stack : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, equal, yojson]
      end
    end]
  end

  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'pending_coinbase t =
          { source : 'pending_coinbase; target : 'pending_coinbase }
        [@@deriving compare, equal, fields, hash, sexp, yojson]

        val to_latest :
             ('pending_coinbase -> 'pending_coinbase')
          -> 'pending_coinbase t
          -> 'pending_coinbase' t
      end
    end]

    val typ :
         ('pending_coinbase_var, 'pending_coinbase) Tick.Typ.t
      -> ('pending_coinbase_var t, 'pending_coinbase t) Tick.Typ.t
  end

  type 'pending_coinbase poly = 'pending_coinbase Poly.t =
    { source : 'pending_coinbase; target : 'pending_coinbase }
  [@@deriving sexp, hash, compare, equal, fields, yojson]

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  type var = Pending_coinbase.Stack.var Poly.t

  open Tick

  val typ : (var, t) Typ.t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ( 'ledger_hash
           , 'amount
           , 'pending_coinbase
           , 'fee_excess
           , 'sok_digest
           , 'local_state )
           t =
        { source :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state )
            Registers.Stable.V1.t
        ; target :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state )
            Registers.Stable.V1.t
        ; connecting_ledger_left : 'ledger_hash
        ; connecting_ledger_right : 'ledger_hash
        ; supply_increase : 'amount
        ; fee_excess : 'fee_excess
        ; sok_digest : 'sok_digest
        }
      [@@deriving compare, equal, hash, sexp, yojson, hlist]
    end
  end]

  val with_empty_local_state :
       supply_increase:'amount
    -> fee_excess:'fee_excess
    -> sok_digest:'sok_digest
    -> source_first_pass_ledger:'ledger_hash
    -> target_first_pass_ledger:'ledger_hash
    -> source_second_pass_ledger:'ledger_hash
    -> target_second_pass_ledger:'ledger_hash
    -> connecting_ledger_left:'ledger_hash
    -> connecting_ledger_right:'ledger_hash
    -> pending_coinbase_stack_state:
         'pending_coinbase Pending_coinbase_stack_state.poly
    -> ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'sok_digest
       , Mina_transaction_logic.Zkapp_command_logic.Local_state.Value.t )
       t
end

type ( 'ledger_hash
     , 'amount
     , 'pending_coinbase
     , 'fee_excess
     , 'sok_digest
     , 'local_state )
     poly =
      ( 'ledger_hash
      , 'amount
      , 'pending_coinbase
      , 'fee_excess
      , 'sok_digest
      , 'local_state )
      Poly.t =
  { source : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
  ; target : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
  ; connecting_ledger_left : 'ledger_hash
  ; connecting_ledger_right : 'ledger_hash
  ; supply_increase : 'amount
  ; fee_excess : 'fee_excess
  ; sok_digest : 'sok_digest
  }
[@@deriving compare, equal, hash, sexp, yojson]

module Statement_ledgers : sig
  type 'a t =
    { first_pass_ledger_source : 'a
    ; first_pass_ledger_target : 'a
    ; second_pass_ledger_source : 'a
    ; second_pass_ledger_target : 'a
    ; connecting_ledger_left : 'a
    ; connecting_ledger_right : 'a
    }
  [@@deriving compare, equal, hash, sexp, yojson]

  val of_statement : ('a, _, _, _, _, _) Poly.t -> 'a t
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Frozen_ledger_hash.Stable.V1.t
      , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
      , Pending_coinbase.Stack_versioned.Stable.V1.t
      , Fee_excess.Stable.V1.t
      , unit
      , Local_state.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving compare, equal, hash, sexp, yojson]
  end
end]

type var =
  ( Frozen_ledger_hash.var
  , Currency.Amount.Signed.var
  , Pending_coinbase.Stack.var
  , Fee_excess.var
  , unit
  , Local_state.Checked.t )
  Poly.t

val typ : (var, t) Tick.Typ.t

module With_sok : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , Sok_message.Digest.Stable.V1.t
        , Local_state.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, hash, sexp, yojson]
    end
  end]

  type display =
    (string, string, string, int, string, Local_state.display) Poly.t

  val display : Stable.Latest.t -> display

  val genesis : genesis_ledger_hash:Frozen_ledger_hash.t -> t

  type var =
    ( Frozen_ledger_hash.var
    , Amount.Signed.var
    , Pending_coinbase.Stack.var
    , Fee_excess.var
    , Sok_message.Digest.Checked.t
    , Local_state.Checked.t )
    Poly.t

  open Tick

  val typ : (var, t) Typ.t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val to_field_elements : t -> Field.t array

  module Checked : sig
    type t = var

    val to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t Checked.t

    (* This is actually a checked function. *)
    val to_field_elements : var -> Field.Var.t array
  end
end

val gen : t Quickcheck.Generator.t

val validate_ledgers_at_merge_checked :
     Frozen_ledger_hash.var Statement_ledgers.t
  -> Frozen_ledger_hash.var Statement_ledgers.t
  -> unit Tick.Checked.t

val merge : t -> t -> t Or_error.t

include Hashable.S_binable with type t := t

include Comparable.S with type t := t
