open Intf

module type Scan_state_constants_S = sig
  val transaction_capacity_log_2 : int

  val work_delay : int
end

module Tick_backend = Crypto_params.Tick_backend
module Tock_backend = Crypto_params.Tock_backend

(* module Tock0 : S

module Tick0 : S

module rec Tock : sig
  include S
  include Functor.Make_sig (Curve_choice.Tick_full) (Tick)
end
and Tick : sig
  include S
  include Functor.Make_sig (Curve_choice.Tock_full) (Tock)
end
     
 *)
