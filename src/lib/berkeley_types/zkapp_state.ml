(* The zkApp state of the Berkeley era, which had 8 elements. *)

open Core_kernel
open Pickles_types

module V = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = 'a Vector.Vector_8.Stable.V1.t
      [@@deriving equal, sexp, yojson]
    end
  end]

  type 'a t = 'a Stable.V1.t [@@deriving equal, sexp, yojson]

  (** Extends [t] to the current length, filling the new elements with
      [pad]. *)
  let to_mesa (t : 'a Stable.V1.t) ~(pad : 'a) : 'a Mina_base.Zkapp_state.V.t =
    Vector.extend_exn t Mina_base.Zkapp_state.Max_state_size.n pad
end

module Value = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Mina_base.Zkapp_basic.F.Stable.V1.t V.Stable.V1.t
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  (** An account's state is extended with zeroes, as the Mesa hard fork did. *)
  let to_mesa (t : Stable.V1.t) : Mina_base.Zkapp_state.Value.t =
    V.to_mesa t ~pad:Mina_base.Zkapp_basic.F.zero
end
