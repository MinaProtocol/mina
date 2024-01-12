open Unsigned
open Core
open Snark_params.Tick
module Wire_types = Mina_wire_types.Consensus_global_slot

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Global_slot_intf.Full
      with type ('slot_number, 'slots_per_epoch) Poly.Stable.V1.t =
        ('slot_number, 'slots_per_epoch) A.Poly.V1.t
       and type Stable.V1.t = A.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  module T = Mina_numbers.Global_slot_since_hard_fork
  module Length = Mina_numbers.Length

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('slot_number, 'slots_per_epoch) t =
              ('slot_number, 'slots_per_epoch) A.Poly.V1.t =
          { slot_number : 'slot_number; slots_per_epoch : 'slots_per_epoch }
        [@@deriving sexp, equal, compare, hash, yojson, hlist]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (T.Stable.V1.t, Length.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type value = t [@@deriving sexp, compare, hash, yojson]

  type var = (T.Checked.t, Length.Checked.t) Poly.t

  let typ =
    Typ.of_hlistable
      [ T.Checked.typ; Length.Checked.typ ]
      ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
      ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

  let to_input (t : value) =
    Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [| T.to_input t.slot_number; Length.to_input t.slots_per_epoch |]

  let gen ~(constants : Constants.t) =
    let open Quickcheck.Let_syntax in
    let slots_per_epoch = constants.slots_per_epoch in
    let%map slot_number = T.gen in
    { Poly.slot_number; slots_per_epoch }

  let create ~(constants : Constants.t) ~(epoch : Epoch.t) ~(slot : Slot.t) : t
      =
    { slot_number =
        T.of_uint32 UInt32.Infix.(slot + (constants.slots_per_epoch * epoch))
    ; slots_per_epoch = constants.slots_per_epoch
    }

  let of_epoch_and_slot ~(constants : Constants.t) (epoch, slot) =
    create ~epoch ~slot ~constants

  let zero ~(constants : Constants.t) : t =
    { slot_number = T.zero; slots_per_epoch = constants.slots_per_epoch }

  let slot_number { Poly.slot_number; _ } = slot_number

  let slots_per_epoch { Poly.slots_per_epoch; _ } = slots_per_epoch

  let epoch (t : t) =
    let slot_number_u32 = T.to_uint32 t.slot_number in
    UInt32.Infix.(slot_number_u32 / t.slots_per_epoch)

  let slot (t : t) =
    let slot_number_u32 = T.to_uint32 t.slot_number in
    UInt32.Infix.(slot_number_u32 mod t.slots_per_epoch)

  let to_epoch_and_slot t = (epoch t, slot t)

  let add (t : t) (span : Mina_numbers.Global_slot_span.t) =
    { t with slot_number = T.add t.slot_number span }

  let ( + ) (t : t) n : t = add t (Mina_numbers.Global_slot_span.of_int n)

  let ( < ) (t : t) (t' : t) = T.compare t.slot_number t'.slot_number < 0

  let diff_slots (t1 : t) (t2 : t) = T.diff t1.slot_number t2.slot_number

  let max (t1 : t) (t2 : t) = if t1 < t2 then t2 else t1

  let succ (t : t) = { t with slot_number = T.succ t.slot_number }

  let of_slot_number ~(constants : Constants.t) slot_number =
    { Poly.slot_number; slots_per_epoch = constants.slots_per_epoch }

  let start_time ~(constants : Constants.t) t =
    let epoch, slot = to_epoch_and_slot t in
    Epoch.slot_start_time epoch slot ~constants

  let end_time ~(constants : Constants.t) t =
    let epoch, slot = to_epoch_and_slot t in
    Epoch.slot_end_time epoch slot ~constants

  let time_hum t =
    let epoch, slot = to_epoch_and_slot t in
    sprintf "epoch=%d, slot=%d" (Epoch.to_int epoch) (Slot.to_int slot)

  let of_time_exn ~(constants : Constants.t) time =
    of_epoch_and_slot
      (Epoch.epoch_and_slot_of_time_exn time ~constants)
      ~constants

  let diff ~(constants : Constants.t) (t : t) (other_epoch, other_slot) =
    let open UInt32.Infix in
    let epoch, slot = to_epoch_and_slot t in
    let old_epoch =
      epoch - other_epoch
      - UInt32.(of_int @@ if compare other_slot slot > 0 then 1 else 0)
    in
    let old_slot =
      (slot - other_slot) mod Length.to_uint32 constants.slots_per_epoch
    in
    of_epoch_and_slot (old_epoch, old_slot) ~constants

  module Checked = struct
    type t = var

    let ( < ) (t : t) (t' : t) = T.Checked.(t.slot_number < t'.slot_number)

    let of_slot_number ~(constants : Constants.var) slot_number : t =
      { slot_number; slots_per_epoch = constants.slots_per_epoch }

    let to_input (var : t) =
      Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
        [| T.Checked.to_input var.slot_number
         ; Length.Checked.to_input var.slots_per_epoch
        |]

    let to_epoch_and_slot (t : t) : (Epoch.Checked.t * Slot.Checked.t) Checked.t
        =
      let%map epoch, slot =
        T.Checked.div_mod t.slot_number
          (T.Checked.Unsafe.of_field
             (Length.Checked.to_field t.slots_per_epoch) )
      in
      ( Epoch.Checked.Unsafe.of_field (T.Checked.to_field epoch)
      , Slot.Checked.Unsafe.of_field (T.Checked.to_field slot) )

    let diff_slots (t : t) (t' : t) =
      T.Checked.diff t.slot_number t'.slot_number
  end

  module For_tests = struct
    let of_global_slot (t : t) slot_number : t = { t with slot_number }
  end
end

include Wire_types.Make (Make_sig) (Make_str)
