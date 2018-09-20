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
  Signature_lib.Checked.Message_intf
  with type ('a, 'b) checked := ('a, 'b) Tick.Checked.t
   and type boolean_var := Tick.Boolean.var
   and type curve_scalar := Inner_curve.Scalar.t
   and type curve_scalar_var := Inner_curve.Scalar.var
   and type t = t
   and type var = var

module Signature :
  Signature_lib.Checked.S
  with type ('a, 'b) typ := ('a, 'b) Tick.Typ.t
   and type ('a, 'b) checked := ('a, 'b) Tick.Checked.t
   and type boolean_var := Tick.Boolean.var
   and type curve := Snark_params.Tick.Inner_curve.t
   and type curve_var := Snark_params.Tick.Inner_curve.var
   and type curve_scalar := Snark_params.Tick.Inner_curve.Scalar.t
   and type curve_scalar_var := Snark_params.Tick.Inner_curve.Scalar.var
   and module Message := Message
   and module Shifted := Snark_params.Tick.Inner_curve.Checked.Shifted
