open Import
open Snark_params
open Snarky
open Tick

module type S = sig
  type t

  module Stack : sig
    type t

    val push_exn : t -> Coinbase.t -> t
  end

  module Hash : sig
    type t
  end
end
