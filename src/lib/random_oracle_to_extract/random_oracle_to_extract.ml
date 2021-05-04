open Core_kernel
module Input = Random_oracle_input
module Intf = Intf
module Checked = Checked

(** interfaces *)

module State = Intf.State

(** functions to create a hash from a configuration or permutation *)
module From_poseidong_config (Inputs : Sponge.Intf.Inputs.Poseidon) :
  Sponge.Intf.Hash with module State := State and module Field := Inputs.Field =
struct
  include Sponge.Make_hash (Sponge.Poseidon (Inputs))
end

module From_permutation (P : Sponge.Intf.Permutation) :
  Sponge.Intf.Hash with module State := State and module Field := P.Field =
struct
  include Sponge.Make_hash (P)
end

(** field required to create a hash *)
module type Field = sig
  include Sponge.Intf.Field

  val unpack : t -> bool list

  val size_in_bits : int

  val project : bool list -> t
end

(** config required to create a hash *)
module type Config = sig
  type field

  val params : field Sponge.Params.t (* = 'a Sponge.Params.t *)
end

(** create a hash following the interface defined in intf.ml *)
module Make_hash
    (Field : Field)
    (Config : Config with type field := Field.t)
    (Hash : Sponge.Intf.Hash
            with module State := State
             and module Field := Field) :
  Intf.S
  with type field := Field.t
   and type field_constant := Field.t
   and type boolean := bool
   and module State := State = struct
  module Digest = struct
    type t = Field.t

    let to_bits ?length x =
      let open Field in
      match length with
      | None ->
          unpack x
      | Some length ->
          List.take (unpack x) length
  end

  include Hash

  let update ~state = update Config.params ~state

  let hash ?init = hash ?init Config.params

  (* pack_input hash digest initial_state *)
  let pack_input =
    let open Field in
    Input.pack_to_fields ~size_in_bits ~pack:project
end
