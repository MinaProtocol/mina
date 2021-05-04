(*
open Core_kernel
module State = Intf.State
module Input = Random_oracle_input

module type Config = sig
  type boolean

  module Field : sig
    include Sponge.Intf.Field

    module Var : sig
      type t

      val pack : boolean list -> t
    end

    val unpack : t -> bool list

    val size_in_bits : int

    val project : bool list -> t

    val constant : _ -> t
  end

  val choose_preimage_var : Field.t -> length:int -> boolean list

  val params : Field.t Sponge.Params.t
end

module Make_hash
    (Config : Config)
    (Hash : Sponge.Intf.Hash
            with module State := State
             and module Field := Config.Field) :
  Intf.S
  with type field := Config.Field.Var.t
   and type field_constant := Config.Field.t
   and type boolean := Config.boolean
   and module State := State = struct
  (* digest *)
  module Digest = struct
    type t = Config.Field.Var.t

    let to_bits ?(length = Config.Field.size_in_bits) (x : t) =
      let choose_preimage_var = Config.choose_preimage_var in
      List.take
        (choose_preimage_var ~length:Config.Field.size_in_bits x)
        length
  end

  include Hash

  let update ~state = update Config.params ~state

  let hash ?init =
    hash
      ?init:(Option.map init ~f:(State.map ~f:Config.Field.constant))
      Config.params

  let pack_input =
    Input.pack_to_fields ~size_in_bits:Config.Field.size_in_bits
      ~pack:Config.Field.Var.pack
end
*)
