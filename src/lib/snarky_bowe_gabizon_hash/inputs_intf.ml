open Tuple_lib
open Fold_lib
open Snarky

module type S = sig
  type field

  type (_, _) checked

  module Fqe : sig
    type t

    val to_list : t -> field Cvar.t list
  end

  val pedersen :
    field Cvar.t Boolean.t Triple.t Fold.t -> (field Cvar.t, _) checked

  val params : field Group_map.Params.t
end
