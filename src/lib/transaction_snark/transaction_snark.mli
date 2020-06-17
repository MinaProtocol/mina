open Core
open Coda_base
open Snark_params

module Pending_coinbase_stack_state : sig
  module Init_stack : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, eq, yojson]
      end
    end]

    type t = Stable.Latest.t = Base of Pending_coinbase.Stack.t | Merge
    [@@deriving sexp, hash, compare, yojson]
  end

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type 's t = {source: 's; target: 's}
        [@@deriving bin_io, compare, eq, fields, hash, sexp, version, yojson]
      end

      module Latest = V1
    end
  end

  module Stable : sig
    module V1 : sig
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving bin_io, compare, eq, hash, sexp, version, yojson]
    end

    module Latest = V1
  end

  type 's t_ = 's Poly.Stable.Latest.t = {source: 's; target: 's}
  [@@deriving sexp, hash, compare, eq, fields, yojson]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq, yojson]
end

module Statement : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('lh, 'amt, 'pc, 'signed_amt, 'sok) t =
          { source: 'lh
          ; target: 'lh
          ; supply_increase: 'amt
          ; pending_coinbase_stack_state:
              'pc Pending_coinbase_stack_state.Poly.Stable.V1.t
          ; fee_excess: 'signed_amt
          ; sok_digest: 'sok }
        [@@deriving compare, equal, hash, sexp, yojson]
      end
    end]
  end

  type ('lh, 'amt, 'pc, 'signed_amt, 'sok) t_ =
        ('lh, 'amt, 'pc, 'signed_amt, 'sok) Poly.Stable.Latest.t =
    { source: 'lh
    ; target: 'lh
    ; supply_increase: 'amt
    ; pending_coinbase_stack_state:
        'pc Pending_coinbase_stack_state.Poly.Stable.V1.t
    ; fee_excess: 'signed_amt
    ; sok_digest: 'sok }

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , unit )
        Poly.Stable.V1.t
      [@@deriving bin_io, compare, equal, hash, sexp, yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving compare, equal, hash, sexp, yojson]

  module With_sok : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , Pending_coinbase.Stack_versioned.Stable.V1.t
          , Fee_excess.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, compare, equal, hash, sexp, yojson]
      end
    end]

    type t = Stable.Latest.t [@@deriving compare, equal, hash, sexp, yojson]

    module Checked : sig
      type t =
        ( Frozen_ledger_hash.var
        , Currency.Amount.var
        , Pending_coinbase.Stack.var
        , Fee_excess.var
        , Sok_message.Digest.Checked.t )
        t_
    end

    val typ : (Checked.t, t) Tick.Typ.t
  end

  val gen : t Quickcheck.Generator.t

  val merge : t -> t -> t Or_error.t

  include Hashable.S_binable with type t := t

  include Comparable.S with type t := t
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving compare, sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, to_yojson]

val create :
     source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> supply_increase:Currency.Amount.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> fee_excess:Fee_excess.t
  -> sok_digest:Sok_message.Digest.t
  -> proof:Coda_base.Proof.t
  -> t

val proof : t -> Coda_base.Proof.t

val statement : t -> Statement.t

val sok_digest : t -> Sok_message.Digest.t

open Pickles_types

type tag =
  ( Statement.With_sok.Checked.t
  , Statement.With_sok.t
  , Nat.N2.n
  , Nat.N2.n )
  Pickles.Tag.t

val verify : (t * Sok_message.t) list -> key:Pickles.Verification_key.t -> bool

module Verification : sig
  module type S = sig
    val tag : tag

    val verify : (t * Sok_message.t) list -> bool

    val id : Pickles.Verification_key.Id.t Lazy.t

    val verification_key : Pickles.Verification_key.t Lazy.t

    val verify_against_digest : t -> bool
  end
end

val check_transaction :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
  -> init_stack:Pending_coinbase.Stack.t
  -> Transaction.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val check_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> Pending_coinbase_stack_state.t
  -> init_stack:Pending_coinbase.Stack.t
  -> User_command.With_valid_signature.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

val generate_transaction_witness :
     ?preeval:bool
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> sok_message:Sok_message.t
  -> source:Frozen_ledger_hash.t
  -> target:Frozen_ledger_hash.t
  -> init_stack:Pending_coinbase.Stack.t
  -> Pending_coinbase_stack_state.t
  -> Transaction.t Transaction_protocol_state.t
  -> Tick.Handler.t
  -> unit

module type S = sig
  include Verification.S

  val cache_handle : Pickles.Cache_handle.t

  val of_transaction :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Transaction.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> User_command.With_valid_signature.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> init_stack:Pending_coinbase.Stack.t
    -> Fee_transfer.t Transaction_protocol_state.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

module Make () : S

val constraint_system_digests : unit -> (string * Md5.t) list
