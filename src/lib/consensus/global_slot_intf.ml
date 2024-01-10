module type Full = sig
  [%%import "/src/config.mlh"]

  open Core_kernel

  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('slot_number, 'slots_per_epoch) t
        [@@deriving sexp, equal, compare, hash, yojson]
      end
    end]
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
        , Mina_numbers.Length.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, equal, sexp, hash, yojson]
    end
  end]

  val to_input : t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t

  val of_slot_number :
    constants:Constants.t -> Mina_numbers.Global_slot_since_hard_fork.t -> t

  val gen : constants:Constants.t -> t Quickcheck.Generator.t

  val add : t -> Mina_numbers.Global_slot_span.t -> t

  val ( + ) : t -> int -> t

  val ( < ) : t -> t -> bool

  val diff_slots : t -> t -> Mina_numbers.Global_slot_span.t option

  val max : t -> t -> t

  val succ : t -> t

  val create : constants:Constants.t -> epoch:Epoch.t -> slot:Slot.t -> t

  val of_epoch_and_slot : constants:Constants.t -> Epoch.t * Slot.t -> t

  val zero : constants:Constants.t -> t

  val epoch : t -> Epoch.t

  val slot : t -> Slot.t

  val start_time : constants:Constants.t -> t -> Block_time.t

  val end_time : constants:Constants.t -> t -> Block_time.t

  val time_hum : t -> string

  val to_epoch_and_slot : t -> Epoch.t * Slot.t

  val of_time_exn : constants:Constants.t -> Block_time.t -> t

  val diff : constants:Constants.t -> t -> Epoch.t * Slot.t -> t

  [%%ifdef consensus_mechanism]

  open Snark_params.Tick

  module Checked : sig
    open Snark_params.Tick

    type t =
      ( Mina_numbers.Global_slot_since_hard_fork.Checked.t
      , Mina_numbers.Length.Checked.t )
      Poly.t

    val ( < ) : t -> t -> Boolean.var Checked.t

    val of_slot_number :
         constants:Constants.var
      -> Mina_numbers.Global_slot_since_hard_fork.Checked.t
      -> t

    val to_input : t -> Field.Var.t Random_oracle.Input.Chunked.t

    val to_epoch_and_slot : t -> (Epoch.Checked.t * Slot.Checked.t) Checked.t

    val diff_slots : t -> t -> Mina_numbers.Global_slot_span.Checked.t Checked.t
  end

  val typ : (Checked.t, t) Typ.t

  [%%endif]

  val slot_number : ('a, _) Poly.t -> 'a

  val slots_per_epoch : (_, 'b) Poly.t -> 'b

  module For_tests : sig
    val of_global_slot : t -> Mina_numbers.Global_slot_since_hard_fork.t -> t
  end
end
