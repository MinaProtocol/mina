module type Full = sig
  open Core_kernel
  open Mina_base
  open Snark_params.Tick

  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('state_hash, 'body) t =
          { previous_state_hash : 'state_hash; body : 'body }
        [@@deriving equal, ord, hash, sexp, to_yojson]
      end
    end]
  end

  val hashes_abstract :
       hash_body:('body -> State_body_hash.t)
    -> (State_hash.t, 'body) Poly.t
    -> State_hash.State_hashes.t

  module Body : sig
    module Poly : sig
      [%%versioned:
      module Stable : sig
        module V1 : sig
          type ('a, 'b, 'c, 'd) t [@@deriving sexp]
        end
      end]
    end

    module Value : sig
      [%%versioned:
      module Stable : sig
        module V2 : sig
          type t =
            ( State_hash.Stable.V1.t
            , Blockchain_state.Value.Stable.V2.t
            , Consensus.Data.Consensus_state.Value.Stable.V2.t
            , Protocol_constants_checked.Value.Stable.V1.t )
            Poly.Stable.V1.t
          [@@deriving equal, ord, bin_io, hash, sexp, yojson, version]
        end
      end]
    end

    type var =
      ( State_hash.var
      , Blockchain_state.var
      , Consensus.Data.Consensus_state.var
      , Protocol_constants_checked.var )
      Poly.t

    type ('a, 'b, 'c, 'd) t = ('a, 'b, 'c, 'd) Poly.t

    val typ :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> (var, Value.t) Typ.t

    val hash : Value.t -> State_body_hash.t

    val hash_checked : var -> State_body_hash.var Checked.t

    val consensus_state : (_, _, 'a, _) Poly.t -> 'a

    val view : Value.t -> Zkapp_precondition.Protocol_state.View.t

    val view_checked : var -> Zkapp_precondition.Protocol_state.View.Checked.t

    module For_tests : sig
      val with_consensus_state :
        Value.t -> Consensus.Data.Consensus_state.Value.t -> Value.t
    end
  end

  module Value : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t =
          (State_hash.Stable.V1.t, Body.Value.Stable.V2.t) Poly.Stable.V1.t
        [@@deriving sexp, compare, equal, yojson]
      end
    end]

    include Hashable.S with type t := t
  end

  type value = Value.t [@@deriving sexp, yojson]

  type var = (State_hash.var, Body.var) Poly.t

  val typ :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> (var, value) Typ.t

  val create : previous_state_hash:'a -> body:'b -> ('a, 'b) Poly.t

  val create_value :
       previous_state_hash:State_hash.t
    -> genesis_state_hash:State_hash.t
    -> blockchain_state:Blockchain_state.Value.t
    -> consensus_state:Consensus.Data.Consensus_state.Value.t
    -> constants:Protocol_constants_checked.Value.t
    -> Value.t

  val create_var :
       previous_state_hash:State_hash.var
    -> genesis_state_hash:State_hash.var
    -> blockchain_state:Blockchain_state.var
    -> consensus_state:Consensus.Data.Consensus_state.var
    -> constants:Protocol_constants_checked.var
    -> var

  val previous_state_hash : ('a, _) Poly.t -> 'a

  val body : (_, 'a) Poly.t -> 'a

  val blockchain_state : (_, (_, 'a, _, _) Body.t) Poly.t -> 'a

  val genesis_state_hash :
    ?state_hash:State_hash.t option -> Value.t -> State_hash.t

  val genesis_state_hash_checked :
    state_hash:State_hash.var -> var -> State_hash.var Checked.t

  val consensus_state : (_, (_, _, 'a, _) Body.t) Poly.t -> 'a

  val constants : (_, (_, _, _, 'a) Body.t) Poly.t -> 'a

  val negative_one :
       genesis_ledger:Mina_ledger.Ledger.t Lazy.t
    -> genesis_epoch_data:Consensus.Genesis_epoch_data.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> genesis_body_reference:Consensus.Body_reference.t
    -> Value.t

  val hash_checked : var -> (State_hash.var * State_body_hash.var) Checked.t

  val hashes : Value.t -> State_hash.State_hashes.t

  (** Same as [hash], but accept the [body_hash] directly to avoid re-computing
      it.
   *)
  val hashes_with_body :
    Value.t -> body_hash:State_body_hash.t -> State_hash.State_hashes.t
end
