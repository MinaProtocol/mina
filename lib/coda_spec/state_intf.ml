open Core_kernel
open Tuple_lib
open Fold_lib
open Coda_numbers
open Snark_params.Tick

module Blockchain = struct
  module type S = sig
    module Time : Time_intf.S

    module Ledger_builder_hash : Ledger_builder_hash_intf.S

    module Frozen_ledger_hash : Ledger_hash_intf.Frozen.S

    module Hash : Hash_intf.Full_size.S

    type ('ledger_builder_hash, 'ledger_hash, 'time) t_ =
      { ledger_builder_hash: 'ledger_builder_hash
      ; ledger_hash: 'ledger_hash
      ; timestamp: 'time }
    [@@deriving sexp, eq, compare]

    val ledger_builder_hash : ('a, _, _) t_ -> 'a

    val ledger_hash : (_, 'a, _) t_ -> 'a

    val timestamp : (_, _, 'a) t_ -> 'a

    type t = (Ledger_builder_hash.t, Frozen_ledger_hash.t, Time.t) t_
    [@@deriving sexp, eq, compare, hash]

    module Stable : sig
      module V1 : sig
        type nonrec ('a, 'b, 'c) t_ = ('a, 'b, 'c) t_
        [@@deriving bin_io, sexp, eq, compare, hash]

        type nonrec t =
          ( Ledger_builder_hash.Stable.V1.t
          , Frozen_ledger_hash.Stable.V1.t
          , Time.Stable.V1.t )
          t_
        [@@deriving bin_io, sexp, eq, compare, hash]
      end
    end

    type value = t [@@deriving bin_io, sexp, eq, compare, hash]

    include Snarkable.S
            with type var =
                        ( Ledger_builder_hash.var
                        , Frozen_ledger_hash.var
                        , Time.Unpacked.var )
                        t_
             and type value := value

    val create_value :
         ledger_builder_hash:Ledger_builder_hash.Stable.V1.t
      -> ledger_hash:Frozen_ledger_hash.Stable.V1.t
      -> timestamp:Time.Stable.V1.t
      -> value

    val length_in_triples : int

    val genesis : t

    val set_timestamp : ('a, 'b, 'c) t_ -> 'c -> ('a, 'b, 'c) t_

    val fold : t -> bool Triple.t Fold.t

    val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    module Message :
      Signature_intf.Message.S
      with type Payload.t = t
       and type Payload.var = var
       and type var = var

    module Signature : Signature_intf.S with module Message = Message
  end
end

module Consensus = struct
  module type S = sig
    type value [@@deriving hash, eq, compare, bin_io, sexp]

    include Snark_params.Tick.Snarkable.S with type value := value

    val genesis : value

    val length_in_triples : int

    val var_to_triples :
         var
      -> ( Snark_params.Tick.Boolean.var Triple.t list
         , _ )
         Snark_params.Tick.Checked.t

    val fold : value -> bool Triple.t Fold.t

    val length : value -> Length.t

    val to_lite : (value -> Lite_base.Consensus_state.t) option
  end
end

module Protocol = struct
  module type S = sig
    module Hash : Hash_intf.Full_size.S

    module Blockchain_state : Blockchain.S

    module Consensus_state : Consensus.S

    type ('a, 'b, 'c) t [@@deriving bin_io, sexp]

    type value =
      (Hash.Stable.V1.t, Blockchain_state.value, Consensus_state.value) t
    [@@deriving bin_io, sexp]

    type var = (Hash.var, Blockchain_state.var, Consensus_state.var) t

    include Snarkable.S with type value := value and type var := var

    include Hashable.S with type t := value

    val equal_value : value -> value -> bool

    val compare_value : value -> value -> int

    val create_value :
         previous_state_hash:Hash.Stable.V1.t
      -> blockchain_state:Blockchain_state.t
      -> consensus_state:Consensus_state.value
      -> value

    val create_var :
         previous_state_hash:Hash.var
      -> blockchain_state:Blockchain_state.var
      -> consensus_state:Consensus_state.var
      -> var

    val previous_state_hash : ('a, _, _) t -> 'a

    val blockchain_state : (_, 'a, _) t -> 'a

    val consensus_state : (_, _, 'a) t -> 'a

    val negative_one : value

    val length_in_triples : int

    val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    val hash : value -> Hash.Stable.V1.t
  end
end
