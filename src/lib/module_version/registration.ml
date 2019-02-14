(* registration.ml -- register module versions *)

open Core_kernel

module type Module_decl_intf = sig
  type latest

  val name : string
end

module type Versioned_module_intf = sig
  type t [@@deriving bin_io]

  type latest

  val version : int

  val to_latest : t -> latest
end

module Make (Module_decl : Module_decl_intf) = struct
  (* creates a registrar that can

     - register versioned modules
     - deserialize data to latest version

   N.B.: data must be serialized using registered modules

   see tests below for an example of usage
  *)

  module type Versioned_with_latest_intf =
    Versioned_module_intf with type latest = Module_decl.latest

  let registered : (module Versioned_with_latest_intf) list ref = ref []

  let registered_versions = ref Int.Set.empty

  let name = Module_decl.name

  let is_registered_version version = Int.Set.mem !registered_versions version

  (** deserializes data to the latest module version's type *)
  let deserialize_binary_opt (buf : Bigstring.t) =
    List.find_map !registered
      ~f:(fun (module M : Versioned_with_latest_intf) ->
        let pos_ref = ref 0 in
        let data_version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        (* sanity check *)
        if not (is_registered_version data_version) then
          failwith
            (sprintf
               "deserialize_binary_opt: version %d in serialized data is not \
                a registered version"
               data_version) ;
        if Int.equal data_version M.version then
          Some (M.bin_read_t ~pos_ref buf |> M.to_latest)
        else None )

  module Register (Versioned_module : Versioned_with_latest_intf) = struct
    let () =
      if is_registered_version Versioned_module.version then
        failwith
          (sprintf "Already found a registered module \"%s\" with version %d"
             name Versioned_module.version) ;
      registered_versions :=
        Int.Set.add !registered_versions Versioned_module.version ;
      registered := (module Versioned_module) :: !registered

    (** creates serialized version of an instance of the date with version prepended *)
    let serialize_binary (t : Versioned_module.t) =
      let open Versioned_module in
      let sz = Bin_prot.Std.bin_size_int version + bin_size_t t in
      let buf = Bin_prot.Common.create_buf sz in
      let pos = Bin_prot.Std.bin_write_int buf ~pos:0 version in
      ignore (bin_write_t ~pos buf t) ;
      buf
  end
end

let%test_module "Test versioned modules" =
  ( module struct
    module Stable = struct
      module V2 = struct
        let version = 2

        (* string, int swapped in tuple from V1's t *)
        type t = string * int [@@deriving bin_io]

        type latest = t

        let to_latest = Fn.id
      end

      module Latest = V2

      module V1 = struct
        let version = 1

        type t = int * string [@@deriving bin_io]

        type latest = Latest.t

        let to_latest (n, s) = (s, n)
      end

      (* registration *)

      module Module_decl = struct
        let name = "module_version_example"

        type latest = Latest.t
      end

      module Registrar = Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
      module Registered_V2 = Registrar.Register (V2)
      module Registered_Latest = Registered_V2
    end

    open Stable

    let%test "serialize, deserialize with latest version" =
      let ((s, n) as t) = ("hello, world", 42) in
      let serialized = Registered_Latest.serialize_binary t in
      match Registrar.deserialize_binary_opt serialized with
      | None -> false
      | Some (s', n') -> String.equal s s' && Int.equal n n'

    let%test "serialize with older version, deserialize to latest version" =
      let ((n, s) as t) = (42, "hello, world") in
      (* serialize as V1.t *)
      let serialized = Registered_V1.serialize_binary t in
      (* but deserialized to Latest.t *)
      match Registrar.deserialize_binary_opt serialized with
      | None -> false
      | Some (s', n') -> String.equal s s' && Int.equal n n'
  end )
