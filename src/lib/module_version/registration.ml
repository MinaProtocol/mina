(* registration.ml -- register module versions *)

(* see RFC 0014 for design discussion; see tests below for usage
 *)

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

  module With_version : sig
    type nonrec t = {version: int; t: t} [@@deriving bin_io]
  end
end

module type Version_intf = sig
  type t [@@deriving bin_io]

  val version : int
end

(* functor to create a registrar that can

     - register versioned modules
     - deserialize data to latest version

   N.B.: data must be serialized using registered modules

   see tests below for an example of usage
 *)

module Make (Module_decl : Module_decl_intf) = struct
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
        (* rely on layout, first element of record is first item in buf *)
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        (* sanity check *)
        if not (is_registered_version version) then
          failwith
            (sprintf
               "deserialize_binary_opt: version %d in serialized data is not \
                a registered version"
               version) ;
        if Int.equal version M.version then
          (* start at 0 again, because M.bin_read_t is reading the version *)
          let pos_ref = ref 0 in
          Some (M.bin_read_t ~pos_ref buf |> M.to_latest)
        else None )

  module Register (Versioned_module : Versioned_with_latest_intf) = struct
    open Versioned_module

    let () =
      if is_registered_version Versioned_module.version then
        failwith
          (sprintf "Already found a registered module \"%s\" with version %d"
             name Versioned_module.version) ;
      registered_versions :=
        Int.Set.add !registered_versions Versioned_module.version ;
      registered := (module Versioned_module) :: !registered

    module With_version = struct
      type nonrec t = {version: int; t: Versioned_module.t} [@@deriving bin_io]

      let create t = {version; t}
    end
  end
end

(* functor to generate With_version and bin_io boilerplate *)
module Make_version (Version : Version_intf) = struct
  module With_version = struct
    type nonrec t = {version: int; t: Version.t} [@@deriving bin_io]

    let create t = {version= Version.version; t}
  end

  (* shadow derived bin_io code for Version.t

     serializing an instance of Version.t includes the version number,
      for use by deserialize_binary_opt, above

     deserializing gives back just t, without the version

     that allows use of a versioned module in data structures that themselves
       derive bin_io
   *)

  let bin_read_t buf ~pos_ref =
    let With_version.({version= read_version; t}) =
      With_version.bin_read_t buf ~pos_ref
    in
    (* sanity check *)
    assert (Int.equal read_version Version.version) ;
    t

  let __bin_read_t__ = With_version.__bin_read_t__

  let bin_reader_t =
    Bin_prot.Type_class.{read= bin_read_t; vtag_read= __bin_read_t__}

  let bin_size_t t = With_version.create t |> With_version.bin_size_t

  let bin_write_t buf ~pos t =
    With_version.create t |> With_version.bin_write_t buf ~pos

  let bin_writer_t = Bin_prot.Type_class.{size= bin_size_t; write= bin_write_t}

  let bin_shape_t = With_version.bin_shape_t

  let bin_t =
    Bin_prot.Type_class.
      {shape= bin_shape_t; writer= bin_writer_t; reader= bin_reader_t}
end

(* like Make_version, but for special case of latest version *)
module Make_latest_version (Version : Version_intf) = struct
  type latest = Version.t

  let to_latest t = t

  include Make_version (Version)
end

let%test_module "Test versioned modules" =
  ( module struct
    module Stable = struct
      (* define module versions *)

      module V2 = struct
        module T = struct
          let version = 2

          (* string, int swapped in tuple from V1's t *)
          type t = string * int [@@deriving bin_io]
        end

        include T
        include Make_latest_version (T)
      end

      module Latest = V2

      module V1 = struct
        module T = struct
          let version = 1

          type t = int * string [@@deriving bin_io]
        end

        include T

        (* latest and to_latest need to be defined for older versions *)

        type latest = Latest.t

        let to_latest (n, s) = (s, n)

        include Make_version (T)
      end

      (* declare the module, register the versions *)

      module Module_decl = struct
        let name = "module_version_example"

        type latest = Latest.t
      end

      module Registrar = Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
      module Registered_V2 = Registrar.Register (V2)
    end

    open Stable

    let%test "serialize, deserialize with latest version" =
      let ((s, n) as t) = ("hello, world", 42) in
      let sz = Latest.bin_size_t t in
      let buf = Bin_prot.Common.create_buf sz in
      ignore (Latest.bin_write_t buf ~pos:0 t) ;
      match Registrar.deserialize_binary_opt buf with
      | None -> false
      | Some (s', n') -> String.equal s s' && Int.equal n n'

    let%test "serialize with older version, deserialize to latest version" =
      let ((n, s) as t) = (42, "hello, world") in
      (* serialize as V1.t *)
      let sz = V1.bin_size_t t in
      let buf = Bin_prot.Common.create_buf sz in
      ignore (V1.bin_write_t buf ~pos:0 t) ;
      (* but deserialized to Latest.t *)
      match Registrar.deserialize_binary_opt buf with
      | None -> false
      | Some (s', n') -> String.equal s s' && Int.equal n n'
  end )
