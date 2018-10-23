
include Coda_spec.State_intf.Blockchain.S
  with module Time = Block_time
   and module Ledger_builder_hash = Ledger_builder_hash
   and module Frozen_ledger_hash = Frozen_ledger_hash
   and module Hash = State_hash
            
(*
open Core_kernel
open Coda_numbers
open Snark_params
open Tick
open Tuple_lib
open Fold_lib

type ('ledger_builder_hash, 'ledger_hash, 'time) t_ =
  { ledger_builder_hash: 'ledger_builder_hash
  ; ledger_hash: 'ledger_hash
  ; timestamp: 'time }
[@@deriving sexp, eq, compare, fields]

type t = (Ledger_builder_hash.t, Frozen_ledger_hash.t, Block_time.t) t_
[@@deriving sexp, eq, compare, hash]

module Stable : sig
  module V1 : sig
    type nonrec ('a, 'b, 'c) t_ = ('a, 'b, 'c) t_ =
      {ledger_builder_hash: 'a; ledger_hash: 'b; timestamp: 'c}
    [@@deriving bin_io, sexp, eq, compare, hash]

    type nonrec t =
      ( Ledger_builder_hash.Stable.V1.t
      , Frozen_ledger_hash.Stable.V1.t
      , Block_time.Stable.V1.t )
      t_
    [@@deriving bin_io, sexp, eq, compare, hash]
  end
end

type value = t [@@deriving bin_io, sexp, eq, compare, hash]

include Snarkable.S
        with type var =
                    ( Ledger_builder_hash.var
                    , Frozen_ledger_hash.var
                    , Block_time.Unpacked.var )
                    t_
         and type value := value

module Hash = State_hash

val create_value :
     ledger_builder_hash:Ledger_builder_hash.Stable.V1.t
  -> ledger_hash:Frozen_ledger_hash.Stable.V1.t
  -> timestamp:Block_time.Stable.V1.t
  -> value

val length_in_triples : int

val genesis : t

val set_timestamp : ('a, 'b, 'c) t_ -> 'c -> ('a, 'b, 'c) t_

val fold : t -> bool Triple.t Fold.t

val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

module Message :
  Coda_spec.Signature_intf.Message.S
  with type Payload.t = t
   and type Payload.var = var

module Signature :
  Coda_spec.Signature_intf.S with module Message = Message *)
