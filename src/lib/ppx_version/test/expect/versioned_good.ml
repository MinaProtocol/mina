open Core_kernel

module type Some_intf = sig
  type t = Quux | Zzz [@@deriving bin_io, version]

  include sig
    [@@@ocaml.warning "-32"]

    include Bin_prot.Binable.S with type t := t

    val __versioned__ : unit
  end
  [@@ocaml.doc "@inline"]
end

module M0 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = int [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           fun (x : Ppx_deriving_runtime.int) -> `Int x) [@ocaml.warning "-A"]
          )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `Int x ->
               Result.Ok x
           | _ ->
               Result.Error "Versioned_good.M0.Stable.V1.t")
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:12:6")
              [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_int) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_int

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = bin_write_int

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          __bin_read_int__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = bin_read_int

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:12:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:12:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M0.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t [@@deriving yojson]

    let rec (to_yojson : t -> Yojson.Safe.t) =
      ((let open! Ppx_deriving_yojson_runtime in
       fun x -> Stable.Latest.to_yojson x) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or) =
      ((let open! Ppx_deriving_yojson_runtime in
       fun x -> Stable.Latest.of_yojson x) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    let _ = to_yojson

    let _ = of_yojson

    let _ = fun (_ : t) -> ()
  end
end

module M1 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = M0.Stable.V1.t [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x -> M0.Stable.V1.to_yojson x) [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x -> M0.Stable.V1.of_yojson x) [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:24:6")
              [ (Bin_prot.Shape.Tid.of_string "t", [], M0.Stable.V1.bin_shape_t)
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = M0.Stable.V1.bin_size_t

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = M0.Stable.V1.bin_write_t

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          M0.Stable.V1.__bin_read_t__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = M0.Stable.V1.bin_read_t

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = M0.Stable.V1.__versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:24:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:24:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M1.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t [@@deriving yojson]

    let rec (to_yojson : t -> Yojson.Safe.t) =
      ((let open! Ppx_deriving_yojson_runtime in
       fun x -> Stable.Latest.to_yojson x) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or) =
      ((let open! Ppx_deriving_yojson_runtime in
       fun x -> Stable.Latest.of_yojson x) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    let _ = to_yojson

    let _ = of_yojson

    let _ = fun (_ : t) -> ()
  end
end

module M3 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = M0.Stable.V1.t * M1.Stable.V1.t [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:36:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.tuple
                    [ M0.Stable.V1.bin_shape_t; M1.Stable.V1.bin_shape_t ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | v1, v2 ->
              let size = 0 in
              let size =
                Bin_prot.Common.( + ) size (M0.Stable.V1.bin_size_t v1)
              in
              Bin_prot.Common.( + ) size (M1.Stable.V1.bin_size_t v2)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | v1, v2 ->
              let pos = M0.Stable.V1.bin_write_t buf ~pos v1 in
              M1.Stable.V1.bin_write_t buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_good.ml.M3.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v1 = M0.Stable.V1.bin_read_t buf ~pos_ref in
          let v2 = M1.Stable.V1.bin_read_t buf ~pos_ref in
          (v1, v2)

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = M0.Stable.V1.__versioned__

        let _ = M1.Stable.V1.__versioned__

        let to_latest = Fn.id [@@deriving yojson]

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:36:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:36:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M3.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end

module M4 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = { one : M0.Stable.V1.t; two : M1.Stable.V1.t }
        [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x ->
             let fields = [] in
             let fields =
               ("two", (fun x -> M1.Stable.V1.to_yojson x) x.two) :: fields
             in
             let fields =
               ("one", (fun x -> M0.Stable.V1.to_yojson x) x.one) :: fields
             in
             `Assoc fields) [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `Assoc xs ->
               let rec loop xs ((arg0, arg1) as _state) =
                 match xs with
                 | ("one", x) :: xs ->
                     loop xs ((fun x -> M0.Stable.V1.of_yojson x) x, arg1)
                 | ("two", x) :: xs ->
                     loop xs (arg0, (fun x -> M1.Stable.V1.of_yojson x) x)
                 | [] ->
                     arg1
                     >>= fun arg1 ->
                     arg0 >>= fun arg0 -> Result.Ok { one = arg0; two = arg1 }
                 | _ :: xs ->
                     Result.Error "Versioned_good.M4.Stable.V1.t"
               in
               loop xs
                 ( Result.Error "Versioned_good.M4.Stable.V1.t.one"
                 , Result.Error "Versioned_good.M4.Stable.V1.t.two" )
           | _ ->
               Result.Error "Versioned_good.M4.Stable.V1.t")
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:48:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record
                    [ ("one", M0.Stable.V1.bin_shape_t)
                    ; ("two", M1.Stable.V1.bin_shape_t)
                    ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { one = v1; two = v2 } ->
              let size = 0 in
              let size =
                Bin_prot.Common.( + ) size (M0.Stable.V1.bin_size_t v1)
              in
              Bin_prot.Common.( + ) size (M1.Stable.V1.bin_size_t v2)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { one = v1; two = v2 } ->
              let pos = M0.Stable.V1.bin_write_t buf ~pos v1 in
              M1.Stable.V1.bin_write_t buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_good.ml.M4.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_one = M0.Stable.V1.bin_read_t buf ~pos_ref in
          let v_two = M1.Stable.V1.bin_read_t buf ~pos_ref in
          { one = v_one; two = v_two }

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = M0.Stable.V1.__versioned__

        let _ = M1.Stable.V1.__versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:48:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:48:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M4.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t = { one : M0.t; two : M1.t } [@@deriving yojson]

    let rec (to_yojson : t -> Yojson.Safe.t) =
      ((let open! Ppx_deriving_yojson_runtime in
       fun x ->
         let fields = [] in
         let fields = ("two", (fun x -> M1.to_yojson x) x.two) :: fields in
         let fields = ("one", (fun x -> M0.to_yojson x) x.one) :: fields in
         `Assoc fields) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or) =
      ((let open! Ppx_deriving_yojson_runtime in
       function
       | `Assoc xs ->
           let rec loop xs ((arg0, arg1) as _state) =
             match xs with
             | ("one", x) :: xs ->
                 loop xs ((fun x -> M0.of_yojson x) x, arg1)
             | ("two", x) :: xs ->
                 loop xs (arg0, (fun x -> M1.of_yojson x) x)
             | [] ->
                 arg1
                 >>= fun arg1 ->
                 arg0 >>= fun arg0 -> Result.Ok { one = arg0; two = arg1 }
             | _ :: xs ->
                 Result.Error "Versioned_good.M4.t"
           in
           loop xs
             ( Result.Error "Versioned_good.M4.t.one"
             , Result.Error "Versioned_good.M4.t.two" )
       | _ ->
           Result.Error "Versioned_good.M4.t") [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    let _ = to_yojson

    let _ = of_yojson

    let _ = fun (_ : t) -> ()
  end
end

include struct
  module Stable = struct
    module V1 = struct
      type t = int [@@deriving bin_io, version, yojson, bin_io, version, sexp]

      let rec (to_yojson : t -> Yojson.Safe.t) =
        ((let open! Ppx_deriving_yojson_runtime in
         fun (x : Ppx_deriving_runtime.int) -> `Int x) [@ocaml.warning "-A"] )
        [@@ocaml.warning "-39"]

      and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
          =
        ((let open! Ppx_deriving_yojson_runtime in
         function
         | `Int x ->
             Result.Ok x
         | _ ->
             Result.Error "Versioned_good.Stable.V1.t") [@ocaml.warning "-A"] )
        [@@ocaml.warning "-39"]

      let _ = to_yojson

      let _ = of_yojson

      let _ = fun (_ : t) -> ()

      let bin_shape_t =
        let _group =
          Bin_prot.Shape.group
            (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:58:4")
            [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_int) ]
        in
        (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

      let _ = bin_shape_t

      let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_int

      let _ = bin_size_t

      let (bin_write_t : t Bin_prot.Write.writer) = bin_write_int

      let _ = bin_write_t

      let bin_writer_t =
        { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

      let _ = bin_writer_t

      let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) = __bin_read_int__

      let _ = __bin_read_t__

      let (bin_read_t : t Bin_prot.Read.reader) = bin_read_int

      let _ = bin_read_t

      let bin_reader_t =
        { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

      let _ = bin_reader_t

      let bin_t =
        { Bin_prot.Type_class.writer = bin_writer_t
        ; reader = bin_reader_t
        ; shape = bin_shape_t
        }

      let _ = bin_t

      let version = 1

      let _ = version

      let _ = version

      let __versioned__ = ()

      let _ = __versioned__

      let bin_shape_t =
        let _group =
          Bin_prot.Shape.group
            (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:58:4")
            [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_int) ]
        in
        (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

      let _ = bin_shape_t

      let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_int

      let _ = bin_size_t

      let (bin_write_t : t Bin_prot.Write.writer) = bin_write_int

      let _ = bin_write_t

      let bin_writer_t =
        { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

      let _ = bin_writer_t

      let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) = __bin_read_int__

      let _ = __bin_read_t__

      let (bin_read_t : t Bin_prot.Read.reader) = bin_read_int

      let _ = bin_read_t

      let bin_reader_t =
        { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

      let _ = bin_reader_t

      let bin_t =
        { Bin_prot.Type_class.writer = bin_writer_t
        ; reader = bin_reader_t
        ; shape = bin_shape_t
        }

      let _ = bin_t

      let version = 1

      let _ = version

      let _ = version

      let __versioned__ = ()

      let _ = __versioned__

      let t_of_sexp = (int_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t)

      let _ = t_of_sexp

      let sexp_of_t = (sexp_of_int : t -> Ppx_sexp_conv_lib.Sexp.t)

      let _ = sexp_of_t

      let to_latest = Fn.id

      module With_version = struct
        type typ = t [@@deriving bin_io]

        let _ = fun (_ : typ) -> ()

        let bin_shape_typ =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:58:4")
              [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "typ"))
            []

        let _ = bin_shape_typ

        let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

        let _ = bin_size_typ

        let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

        let _ = bin_write_typ

        let bin_writer_typ =
          { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

        let _ = bin_writer_typ

        let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
          __bin_read_t__

        let _ = __bin_read_typ__

        let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

        let _ = bin_read_typ

        let bin_reader_typ =
          { Bin_prot.Type_class.read = bin_read_typ
          ; vtag_read = __bin_read_typ__
          }

        let _ = bin_reader_typ

        let bin_typ =
          { Bin_prot.Type_class.writer = bin_writer_typ
          ; reader = bin_reader_typ
          ; shape = bin_shape_typ
          }

        let _ = bin_typ

        type t = { version : int; t : typ } [@@deriving bin_io]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:58:4")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record
                    [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { version = v1; t = v2 } ->
              let size = 0 in
              let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
              Bin_prot.Common.( + ) size (bin_size_typ v2)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { version = v1; t = v2 } ->
              let pos = bin_write_int buf ~pos v1 in
              bin_write_typ buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_good.ml.Stable.V1.With_version.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_version = bin_read_int buf ~pos_ref in
          let v_t = bin_read_typ buf ~pos_ref in
          { version = v_version; t = v_t }

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let create t = { t; version = 1 }
      end

      let bin_read_t buf ~pos_ref =
        let With_version.{ version = read_version; t } =
          With_version.bin_read_t buf ~pos_ref
        in
        if not (Core_kernel.Int.equal read_version version) then
          failwith
            (Core_kernel.sprintf
               "bin_read_t: version read %d does not match expected version %d"
               read_version version ) ;
        t

      let __bin_read_t__ buf ~pos_ref i =
        let With_version.{ version = read_version; t } =
          With_version.__bin_read_t__ buf ~pos_ref i
        in
        if not (Core_kernel.Int.equal read_version version) then
          failwith
            (Core_kernel.sprintf
               "__bin_read_t__: version read %d does not match expected \
                version %d"
               read_version version ) ;
        t

      let bin_size_t t = With_version.bin_size_t (With_version.create t)

      let bin_write_t buf ~pos t =
        With_version.bin_write_t buf ~pos (With_version.create t)

      let bin_shape_t = With_version.bin_shape_t

      let bin_reader_t =
        { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

      let bin_writer_t =
        { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

      let bin_t =
        { Bin_prot.Type_class.shape = bin_shape_t
        ; writer = bin_writer_t
        ; reader = bin_reader_t
        }

      let _ =
        ( bin_read_t
        , __bin_read_t__
        , bin_size_t
        , bin_write_t
        , bin_shape_t
        , bin_reader_t
        , bin_writer_t
        , bin_t )
    end

    module Latest = V1

    let (versions :
          (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t)) array
          ) =
      [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

    let bin_read_to_latest_opt buf ~pos_ref =
      let open Core_kernel in
      let saved_pos = !pos_ref in
      let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
      let pos_ref = ref saved_pos in
      Array.find_map versions ~f:(fun (i, f) ->
          if Int.equal i version then Some (f buf ~pos_ref) else None )
      [@@ocaml.doc " deserializes data to the latest module version's type "]

    let _ = bin_read_to_latest_opt
  end

  type t = Stable.Latest.t [@@deriving yojson, sexp]

  let rec (to_yojson : t -> Yojson.Safe.t) =
    ((let open! Ppx_deriving_yojson_runtime in
     fun x -> Stable.Latest.to_yojson x) [@ocaml.warning "-A"] )
    [@@ocaml.warning "-39"]

  and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or) =
    ((let open! Ppx_deriving_yojson_runtime in
     fun x -> Stable.Latest.of_yojson x) [@ocaml.warning "-A"] )
    [@@ocaml.warning "-39"]

  let _ = to_yojson

  let _ = of_yojson

  let _ = fun (_ : t) -> ()

  let t_of_sexp = (Stable.Latest.t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t)

  let _ = t_of_sexp

  let sexp_of_t = (Stable.Latest.sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t)

  let _ = sexp_of_t
end

module M5 = struct
  include struct
    module Stable = struct
      module V5 = struct
        type t = Stable.V1.t array array sexp_opaque
        [@@deriving bin_io, version, sexp]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:69:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , bin_shape_sexp_opaque
                    (bin_shape_array (bin_shape_array Stable.V1.bin_shape_t)) )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v ->
          bin_size_sexp_opaque
            (bin_size_array (bin_size_array Stable.V1.bin_size_t))
            v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v ->
          (bin_write_sexp_opaque
             (bin_write_array (bin_write_array Stable.V1.bin_write_t)) )
            buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (__bin_read_sexp_opaque__
             (bin_read_array (bin_read_array Stable.V1.bin_read_t)) )
            buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          (bin_read_sexp_opaque
             (bin_read_array (bin_read_array Stable.V1.bin_read_t)) )
            buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 5

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = Stable.V1.__versioned__

        let t_of_sexp =
          (Ppx_sexp_conv_lib.Conv.opaque_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t)

        let _ = t_of_sexp

        let sexp_of_t =
          (Ppx_sexp_conv_lib.Conv.sexp_of_opaque : t -> Ppx_sexp_conv_lib.Sexp.t)

        let _ = sexp_of_t

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:69:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:69:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M5.Stable.V5.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 5 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V5

      module V4 = struct
        type t = Stable.V1.t option sexp_opaque
        [@@deriving bin_io, version, sexp]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:75:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , bin_shape_sexp_opaque (bin_shape_option Stable.V1.bin_shape_t)
                )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> bin_size_sexp_opaque (bin_size_option Stable.V1.bin_size_t) v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v ->
          (bin_write_sexp_opaque (bin_write_option Stable.V1.bin_write_t))
            buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (__bin_read_sexp_opaque__ (bin_read_option Stable.V1.bin_read_t))
            buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          (bin_read_sexp_opaque (bin_read_option Stable.V1.bin_read_t))
            buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 4

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = Stable.V1.__versioned__

        let t_of_sexp =
          (Ppx_sexp_conv_lib.Conv.opaque_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t)

        let _ = t_of_sexp

        let sexp_of_t =
          (Ppx_sexp_conv_lib.Conv.sexp_of_opaque : t -> Ppx_sexp_conv_lib.Sexp.t)

        let _ = sexp_of_t

        let to_latest _ = [||]

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:75:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:75:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M5.Stable.V4.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 4 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module V3 = struct
        type t = Stable.V1.t ref [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x -> (fun x -> Stable.V1.to_yojson x) !x) [@ocaml.warning "-A"]
          )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x -> (fun x -> Stable.V1.of_yojson x) x >|= ref)
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:81:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , bin_shape_ref Stable.V1.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> bin_size_ref Stable.V1.bin_size_t v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v -> (bin_write_ref Stable.V1.bin_write_t) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (__bin_read_ref__ Stable.V1.bin_read_t) buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref -> (bin_read_ref Stable.V1.bin_read_t) buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 3

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = Stable.V1.__versioned__

        let to_latest _ = [||]

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:81:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:81:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M5.Stable.V3.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 3 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module V2 = struct
        type t = Stable.V1.t list [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           fun x -> `List (safe_map (fun x -> Stable.V1.to_yojson x) x))
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `List xs ->
               map_bind (fun x -> Stable.V1.of_yojson x) [] xs
           | _ ->
               Result.Error "Versioned_good.M5.Stable.V2.t")
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:87:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , bin_shape_list Stable.V1.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> bin_size_list Stable.V1.bin_size_t v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v -> (bin_write_list Stable.V1.bin_write_t) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (__bin_read_list__ Stable.V1.bin_read_t) buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref -> (bin_read_list Stable.V1.bin_read_t) buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 2

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = Stable.V1.__versioned__

        let to_latest _ = [||]

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:87:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:87:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M5.Stable.V2.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 2 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module V1 = struct
        type t = Stable.V1.t option [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | None -> `Null | Some x -> (fun x -> Stable.V1.to_yojson x) x)
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `Null ->
               Result.Ok None
           | x ->
               (fun x -> Stable.V1.of_yojson x) x >>= fun x -> Result.Ok (Some x))
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:93:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , bin_shape_option Stable.V1.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> bin_size_option Stable.V1.bin_size_t v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v -> (bin_write_option Stable.V1.bin_write_t) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (__bin_read_option__ Stable.V1.bin_read_t) buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref -> (bin_read_option Stable.V1.bin_read_t) buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = Stable.V1.__versioned__

        let to_latest _ = [||]

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:93:6")
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:93:6")
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M5.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref))
         ; (2, fun buf ~pos_ref -> V2.to_latest (V2.bin_read_t buf ~pos_ref))
         ; (3, fun buf ~pos_ref -> V3.to_latest (V3.bin_read_t buf ~pos_ref))
         ; (4, fun buf ~pos_ref -> V4.to_latest (V4.bin_read_t buf ~pos_ref))
         ; (5, fun buf ~pos_ref -> V5.to_latest (V5.bin_read_t buf ~pos_ref))
        |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t [@@deriving sexp]

    let _ = fun (_ : t) -> ()

    let t_of_sexp = (Stable.Latest.t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t)

    let _ = t_of_sexp

    let sexp_of_t = (Stable.Latest.sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t)

    let _ = sexp_of_t
  end
end

module type Intf = sig
  type t = Int.t [@@deriving version]

  include sig
    [@@@ocaml.warning "-32"]

    val __versioned__ : unit
  end
  [@@ocaml.doc "@inline"]
end

module M6 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = Leaf | Node of t * t [@@deriving bin_io, version, yojson]

        let rec (to_yojson : t -> Yojson.Safe.t) =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | Leaf ->
               `List [ `String "Leaf" ]
           | Node (arg0, arg1) ->
               `List
                 [ `String "Node"
                 ; (fun x -> to_yojson x) arg0
                 ; (fun x -> to_yojson x) arg1
                 ]) [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
            =
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `List [ `String "Leaf" ] ->
               Result.Ok Leaf
           | `List [ `String "Node"; arg0; arg1 ] ->
               (fun x -> of_yojson x) arg1
               >>= fun arg1 ->
               (fun x -> of_yojson x) arg0
               >>= fun arg0 -> Result.Ok (Node (arg0, arg1))
           | _ ->
               Result.Error "Versioned_good.M6.Stable.V1.t")
          [@ocaml.warning "-A"] )
          [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:109:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.variant
                    [ ("Leaf", [])
                    ; ( "Node"
                      , [ (Bin_prot.Shape.rec_app
                             (Bin_prot.Shape.Tid.of_string "t") )
                            []
                        ; (Bin_prot.Shape.rec_app
                             (Bin_prot.Shape.Tid.of_string "t") )
                            []
                        ] )
                    ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let rec (bin_size_t : t Bin_prot.Size.sizer) = function
          | Node (v1, v2) ->
              let size = 1 in
              let size = Bin_prot.Common.( + ) size (bin_size_t v1) in
              Bin_prot.Common.( + ) size (bin_size_t v2)
          | Leaf ->
              1

        let _ = bin_size_t

        let rec (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | Leaf ->
              Bin_prot.Write.bin_write_int_8bit buf ~pos 0
          | Node (v1, v2) ->
              let pos = Bin_prot.Write.bin_write_int_8bit buf ~pos 1 in
              let pos = bin_write_t buf ~pos v1 in
              bin_write_t buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let rec (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_good.ml.M6.Stable.V1.t" !pos_ref

        and (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          match Bin_prot.Read.bin_read_int_8bit buf ~pos_ref with
          | 0 ->
              Leaf
          | 1 ->
              let arg_1 = bin_read_t buf ~pos_ref in
              let arg_2 = bin_read_t buf ~pos_ref in
              Node (arg_1, arg_2)
          | _ ->
              Bin_prot.Common.raise_read_error
                (Bin_prot.Common.ReadError.Sum_tag
                   "test/versioned_good.ml.M6.Stable.V1.t" ) !pos_ref

        let _ = __bin_read_t__

        and _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:109:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:109:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M6.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t = Leaf | Node of t * t [@@deriving yojson]

    let rec (to_yojson : t -> Yojson.Safe.t) =
      ((let open! Ppx_deriving_yojson_runtime in
       function
       | Leaf ->
           `List [ `String "Leaf" ]
       | Node (arg0, arg1) ->
           `List
             [ `String "Node"
             ; (fun x -> to_yojson x) arg0
             ; (fun x -> to_yojson x) arg1
             ]) [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or) =
      ((let open! Ppx_deriving_yojson_runtime in
       function
       | `List [ `String "Leaf" ] ->
           Result.Ok Leaf
       | `List [ `String "Node"; arg0; arg1 ] ->
           (fun x -> of_yojson x) arg1
           >>= fun arg1 ->
           (fun x -> of_yojson x) arg0
           >>= fun arg0 -> Result.Ok (Node (arg0, arg1))
       | _ ->
           Result.Error "Versioned_good.M6.t") [@ocaml.warning "-A"] )
      [@@ocaml.warning "-39"]

    let _ = to_yojson

    let _ = of_yojson

    let _ = fun (_ : t) -> ()
  end
end

module Poly = struct
  include struct
    module Stable = struct
      module V1 = struct
        type ('a, 'b) t = Poly of 'a * 'b [@@deriving bin_io, version, yojson]

        let rec to_yojson :
                  'a 'b.
                     ('a -> Yojson.Safe.t)
                  -> ('b -> Yojson.Safe.t)
                  -> ('a, 'b) t
                  -> Yojson.Safe.t =
         fun poly_a poly_b ->
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | Poly (arg0, arg1) ->
               `List
                 [ `String "Poly"
                 ; (poly_a : _ -> Yojson.Safe.t) arg0
                 ; (poly_b : _ -> Yojson.Safe.t) arg1
                 ]) [@ocaml.warning "-A"] )
         [@@ocaml.warning "-39"]

        and of_yojson :
              'a 'b.
                 (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
              -> (Yojson.Safe.t -> 'b Ppx_deriving_yojson_runtime.error_or)
              -> Yojson.Safe.t
              -> ('a, 'b) t Ppx_deriving_yojson_runtime.error_or =
         fun poly_a poly_b ->
          ((let open! Ppx_deriving_yojson_runtime in
           function
           | `List [ `String "Poly"; arg0; arg1 ] ->
               (poly_b : Yojson.Safe.t -> _ error_or) arg1
               >>= fun arg1 ->
               (poly_a : Yojson.Safe.t -> _ error_or) arg0
               >>= fun arg0 -> Result.Ok (Poly (arg0, arg1))
           | _ ->
               Result.Error "Versioned_good.Poly.Stable.V1.t")
          [@ocaml.warning "-A"] )
         [@@ocaml.warning "-39"]

        let _ = to_yojson

        let _ = of_yojson

        let _ = fun (_ : ('a, 'b) t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:121:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , [ Bin_prot.Shape.Vid.of_string "a"
                  ; Bin_prot.Shape.Vid.of_string "b"
                  ]
                , Bin_prot.Shape.variant
                    [ ( "Poly"
                      , [ Bin_prot.Shape.var
                            (Bin_prot.Shape.Location.of_string
                               "test/versioned_good.ml:121:32" )
                            (Bin_prot.Shape.Vid.of_string "a")
                        ; Bin_prot.Shape.var
                            (Bin_prot.Shape.Location.of_string
                               "test/versioned_good.ml:121:37" )
                            (Bin_prot.Shape.Vid.of_string "b")
                        ] )
                    ] )
              ]
          in
          fun a b ->
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              [ a; b ]

        let _ = bin_shape_t

        let bin_size_t :
              'a 'b.
                 'a Bin_prot.Size.sizer
              -> 'b Bin_prot.Size.sizer
              -> ('a, 'b) t Bin_prot.Size.sizer =
         fun _size_of_a _size_of_b -> function
          | Poly (v1, v2) ->
              let size = 1 in
              let size = Bin_prot.Common.( + ) size (_size_of_a v1) in
              Bin_prot.Common.( + ) size (_size_of_b v2)

        let _ = bin_size_t

        let bin_write_t :
              'a 'b.
                 'a Bin_prot.Write.writer
              -> 'b Bin_prot.Write.writer
              -> ('a, 'b) t Bin_prot.Write.writer =
         fun _write_a _write_b buf ~pos -> function
          | Poly (v1, v2) ->
              let pos = Bin_prot.Write.bin_write_int_8bit buf ~pos 0 in
              let pos = _write_a buf ~pos v1 in
              _write_b buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t bin_writer_a bin_writer_b =
          { Bin_prot.Type_class.size =
              (fun v ->
                bin_size_t bin_writer_a.Bin_prot.Type_class.size
                  bin_writer_b.Bin_prot.Type_class.size v )
          ; write =
              (fun v ->
                bin_write_t bin_writer_a.Bin_prot.Type_class.write
                  bin_writer_b.Bin_prot.Type_class.write v )
          }

        let _ = bin_writer_t

        let __bin_read_t__ :
              'a 'b.
                 'a Bin_prot.Read.reader
              -> 'b Bin_prot.Read.reader
              -> (int -> ('a, 'b) t) Bin_prot.Read.reader =
         fun _of__a _of__b _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_good.ml.Poly.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let bin_read_t :
              'a 'b.
                 'a Bin_prot.Read.reader
              -> 'b Bin_prot.Read.reader
              -> ('a, 'b) t Bin_prot.Read.reader =
         fun _of__a _of__b buf ~pos_ref ->
          match Bin_prot.Read.bin_read_int_8bit buf ~pos_ref with
          | 0 ->
              let arg_1 = _of__a buf ~pos_ref in
              let arg_2 = _of__b buf ~pos_ref in
              Poly (arg_1, arg_2)
          | _ ->
              Bin_prot.Common.raise_read_error
                (Bin_prot.Common.ReadError.Sum_tag
                   "test/versioned_good.ml.Poly.Stable.V1.t" ) !pos_ref

        let _ = bin_read_t

        let bin_reader_t bin_reader_a bin_reader_b =
          { Bin_prot.Type_class.read =
              (fun buf ~pos_ref ->
                (bin_read_t bin_reader_a.Bin_prot.Type_class.read
                   bin_reader_b.Bin_prot.Type_class.read )
                  buf ~pos_ref )
          ; vtag_read =
              (fun buf ~pos_ref vtag ->
                (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read
                   bin_reader_b.Bin_prot.Type_class.read )
                  buf ~pos_ref vtag )
          }

        let _ = bin_reader_t

        let bin_t bin_a bin_b =
          { Bin_prot.Type_class.writer =
              bin_writer_t bin_a.Bin_prot.Type_class.writer
                bin_b.Bin_prot.Type_class.writer
          ; reader =
              bin_reader_t bin_a.Bin_prot.Type_class.reader
                bin_b.Bin_prot.Type_class.reader
          ; shape =
              bin_shape_t bin_a.Bin_prot.Type_class.shape
                bin_b.Bin_prot.Type_class.shape
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        module With_version = struct
          type ('a, 'b) typ = ('a, 'b) t [@@deriving bin_io]

          let _ = fun (_ : ('a, 'b) typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:121:6" )
                [ ( Bin_prot.Shape.Tid.of_string "typ"
                  , [ Bin_prot.Shape.Vid.of_string "a"
                    ; Bin_prot.Shape.Vid.of_string "b"
                    ]
                  , (bin_shape_t
                       (Bin_prot.Shape.var
                          (Bin_prot.Shape.Location.of_string
                             "test/versioned_good.ml:121:12" )
                          (Bin_prot.Shape.Vid.of_string "a") ) )
                      (Bin_prot.Shape.var
                         (Bin_prot.Shape.Location.of_string
                            "test/versioned_good.ml:121:16" )
                         (Bin_prot.Shape.Vid.of_string "b") ) )
                ]
            in
            fun a b ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "typ") )
                [ a; b ]

          let _ = bin_shape_typ

          let bin_size_typ :
                'a 'b.
                   'a Bin_prot.Size.sizer
                -> 'b Bin_prot.Size.sizer
                -> ('a, 'b) typ Bin_prot.Size.sizer =
           fun _size_of_a _size_of_b v -> bin_size_t _size_of_a _size_of_b v

          let _ = bin_size_typ

          let bin_write_typ :
                'a 'b.
                   'a Bin_prot.Write.writer
                -> 'b Bin_prot.Write.writer
                -> ('a, 'b) typ Bin_prot.Write.writer =
           fun _write_a _write_b buf ~pos v ->
            (bin_write_t _write_a _write_b) buf ~pos v

          let _ = bin_write_typ

          let bin_writer_typ bin_writer_a bin_writer_b =
            { Bin_prot.Type_class.size =
                (fun v ->
                  bin_size_typ bin_writer_a.Bin_prot.Type_class.size
                    bin_writer_b.Bin_prot.Type_class.size v )
            ; write =
                (fun v ->
                  bin_write_typ bin_writer_a.Bin_prot.Type_class.write
                    bin_writer_b.Bin_prot.Type_class.write v )
            }

          let _ = bin_writer_typ

          let __bin_read_typ__ :
                'a 'b.
                   'a Bin_prot.Read.reader
                -> 'b Bin_prot.Read.reader
                -> (int -> ('a, 'b) typ) Bin_prot.Read.reader =
           fun _of__a _of__b buf ~pos_ref vint ->
            (__bin_read_t__ _of__a _of__b) buf ~pos_ref vint

          let _ = __bin_read_typ__

          let bin_read_typ :
                'a 'b.
                   'a Bin_prot.Read.reader
                -> 'b Bin_prot.Read.reader
                -> ('a, 'b) typ Bin_prot.Read.reader =
           fun _of__a _of__b buf ~pos_ref ->
            (bin_read_t _of__a _of__b) buf ~pos_ref

          let _ = bin_read_typ

          let bin_reader_typ bin_reader_a bin_reader_b =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_typ bin_reader_a.Bin_prot.Type_class.read
                     bin_reader_b.Bin_prot.Type_class.read )
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_typ__ bin_reader_a.Bin_prot.Type_class.read
                     bin_reader_b.Bin_prot.Type_class.read )
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_typ

          let bin_typ bin_a bin_b =
            { Bin_prot.Type_class.writer =
                bin_writer_typ bin_a.Bin_prot.Type_class.writer
                  bin_b.Bin_prot.Type_class.writer
            ; reader =
                bin_reader_typ bin_a.Bin_prot.Type_class.reader
                  bin_b.Bin_prot.Type_class.reader
            ; shape =
                bin_shape_typ bin_a.Bin_prot.Type_class.shape
                  bin_b.Bin_prot.Type_class.shape
            }

          let _ = bin_typ

          type ('a, 'b) t = { version : int; t : ('a, 'b) typ }
          [@@deriving bin_io]

          let _ = fun (_ : ('a, 'b) t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:121:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , [ Bin_prot.Shape.Vid.of_string "a"
                    ; Bin_prot.Shape.Vid.of_string "b"
                    ]
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int)
                      ; ( "t"
                        , (bin_shape_typ
                             (Bin_prot.Shape.var
                                (Bin_prot.Shape.Location.of_string
                                   "test/versioned_good.ml:121:12" )
                                (Bin_prot.Shape.Vid.of_string "a") ) )
                            (Bin_prot.Shape.var
                               (Bin_prot.Shape.Location.of_string
                                  "test/versioned_good.ml:121:16" )
                               (Bin_prot.Shape.Vid.of_string "b") ) )
                      ] )
                ]
            in
            fun a b ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t") )
                [ a; b ]

          let _ = bin_shape_t

          let bin_size_t :
                'a 'b.
                   'a Bin_prot.Size.sizer
                -> 'b Bin_prot.Size.sizer
                -> ('a, 'b) t Bin_prot.Size.sizer =
           fun _size_of_a _size_of_b -> function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size
                  (bin_size_typ _size_of_a _size_of_b v2)

          let _ = bin_size_t

          let bin_write_t :
                'a 'b.
                   'a Bin_prot.Write.writer
                -> 'b Bin_prot.Write.writer
                -> ('a, 'b) t Bin_prot.Write.writer =
           fun _write_a _write_b buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                (bin_write_typ _write_a _write_b) buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t bin_writer_a bin_writer_b =
            { Bin_prot.Type_class.size =
                (fun v ->
                  bin_size_t bin_writer_a.Bin_prot.Type_class.size
                    bin_writer_b.Bin_prot.Type_class.size v )
            ; write =
                (fun v ->
                  bin_write_t bin_writer_a.Bin_prot.Type_class.write
                    bin_writer_b.Bin_prot.Type_class.write v )
            }

          let _ = bin_writer_t

          let __bin_read_t__ :
                'a 'b.
                   'a Bin_prot.Read.reader
                -> 'b Bin_prot.Read.reader
                -> (int -> ('a, 'b) t) Bin_prot.Read.reader =
           fun _of__a _of__b _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.Poly.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let bin_read_t :
                'a 'b.
                   'a Bin_prot.Read.reader
                -> 'b Bin_prot.Read.reader
                -> ('a, 'b) t Bin_prot.Read.reader =
           fun _of__a _of__b buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = (bin_read_typ _of__a _of__b) buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t bin_reader_a bin_reader_b =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_t bin_reader_a.Bin_prot.Type_class.read
                     bin_reader_b.Bin_prot.Type_class.read )
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read
                     bin_reader_b.Bin_prot.Type_class.read )
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_t

          let bin_t bin_a bin_b =
            { Bin_prot.Type_class.writer =
                bin_writer_t bin_a.Bin_prot.Type_class.writer
                  bin_b.Bin_prot.Type_class.writer
            ; reader =
                bin_reader_t bin_a.Bin_prot.Type_class.reader
                  bin_b.Bin_prot.Type_class.reader
            ; shape =
                bin_shape_t bin_a.Bin_prot.Type_class.shape
                  bin_b.Bin_prot.Type_class.shape
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t x0 x1 buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            (With_version.bin_read_t x0 x1) buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ x0 x1 buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            (With_version.__bin_read_t__ x0 x1) buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t x0 x1 t =
          With_version.bin_size_t x0 x1 (With_version.create t)

        let bin_write_t x0 x1 buf ~pos t =
          (With_version.bin_write_t x0 x1) buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t x0 x1 =
          { Bin_prot.Type_class.read =
              bin_read_t x0.Bin_prot.Type_class.read x1.Bin_prot.Type_class.read
          ; vtag_read =
              __bin_read_t__ x0.Bin_prot.Type_class.read
                x1.Bin_prot.Type_class.read
          }

        let bin_writer_t x0 x1 =
          { Bin_prot.Type_class.size =
              bin_size_t x0.Bin_prot.Type_class.size x1.Bin_prot.Type_class.size
          ; write =
              bin_write_t x0.Bin_prot.Type_class.write
                x1.Bin_prot.Type_class.write
          }

        let bin_t x0 x1 =
          { Bin_prot.Type_class.shape =
              bin_shape_t x0.Bin_prot.Type_class.shape
                x1.Bin_prot.Type_class.shape
          ; writer =
              bin_writer_t x0.Bin_prot.Type_class.writer
                x1.Bin_prot.Type_class.writer
          ; reader =
              bin_reader_t x0.Bin_prot.Type_class.reader
                x1.Bin_prot.Type_class.reader
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1
    end

    type ('a, 'b) t = ('a, 'b) Stable.Latest.t = Poly of 'a * 'b
    [@@deriving yojson]

    let rec to_yojson :
              'a 'b.
                 ('a -> Yojson.Safe.t)
              -> ('b -> Yojson.Safe.t)
              -> ('a, 'b) t
              -> Yojson.Safe.t =
     fun poly_a poly_b ->
      ((let open! Ppx_deriving_yojson_runtime in
       function
       | Poly (arg0, arg1) ->
           `List
             [ `String "Poly"
             ; (poly_a : _ -> Yojson.Safe.t) arg0
             ; (poly_b : _ -> Yojson.Safe.t) arg1
             ]) [@ocaml.warning "-A"] )
     [@@ocaml.warning "-39"]

    and of_yojson :
          'a 'b.
             (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'b Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('a, 'b) t Ppx_deriving_yojson_runtime.error_or =
     fun poly_a poly_b ->
      ((let open! Ppx_deriving_yojson_runtime in
       function
       | `List [ `String "Poly"; arg0; arg1 ] ->
           (poly_b : Yojson.Safe.t -> _ error_or) arg1
           >>= fun arg1 ->
           (poly_a : Yojson.Safe.t -> _ error_or) arg0
           >>= fun arg0 -> Result.Ok (Poly (arg0, arg1))
       | _ ->
           Result.Error "Versioned_good.Poly.t") [@ocaml.warning "-A"] )
     [@@ocaml.warning "-39"]

    let _ = to_yojson

    let _ = of_yojson

    let _ = fun (_ : ('a, 'b) t) -> ()
  end
end

module M7 = struct
  module M = struct
    include struct
      module Stable = struct
        module V1 = struct
          type t = (string, int) Poly.Stable.V1.t
          [@@deriving bin_io, version, yojson]

          let rec (to_yojson : t -> Yojson.Safe.t) =
            ((let open! Ppx_deriving_yojson_runtime in
             fun x ->
               (Poly.Stable.V1.to_yojson
                  (fun (x : Ppx_deriving_runtime.string) -> `String x)
                  (fun (x : Ppx_deriving_runtime.int) -> `Int x) )
                 x) [@ocaml.warning "-A"] )
            [@@ocaml.warning "-39"]

          and (of_yojson :
                Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or ) =
            ((let open! Ppx_deriving_yojson_runtime in
             fun x ->
               (Poly.Stable.V1.of_yojson
                  (function
                    | `String x ->
                        Result.Ok x
                    | _ ->
                        Result.Error "Versioned_good.M7.M.Stable.V1.t" )
                  (function
                    | `Int x ->
                        Result.Ok x
                    | _ ->
                        Result.Error "Versioned_good.M7.M.Stable.V1.t" ) )
                 x) [@ocaml.warning "-A"] )
            [@@ocaml.warning "-39"]

          let _ = to_yojson

          let _ = of_yojson

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:131:8" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , (Poly.Stable.V1.bin_shape_t bin_shape_string) bin_shape_int
                  )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) =
           fun v -> Poly.Stable.V1.bin_size_t bin_size_string bin_size_int v

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos v ->
            (Poly.Stable.V1.bin_write_t bin_write_string bin_write_int)
              buf ~pos v

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun buf ~pos_ref vint ->
            (Poly.Stable.V1.__bin_read_t__ bin_read_string bin_read_int)
              buf ~pos_ref vint

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            (Poly.Stable.V1.bin_read_t bin_read_string bin_read_int)
              buf ~pos_ref

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let version = 1

          let _ = version

          let _ = version

          let __versioned__ = ()

          let _ = __versioned__

          let _ = Poly.Stable.V1.__versioned__

          let to_latest = Fn.id

          module With_version = struct
            type typ = t [@@deriving bin_io]

            let _ = fun (_ : typ) -> ()

            let bin_shape_typ =
              let _group =
                Bin_prot.Shape.group
                  (Bin_prot.Shape.Location.of_string
                     "test/versioned_good.ml:131:8" )
                  [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
              in
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "typ") )
                []

            let _ = bin_shape_typ

            let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

            let _ = bin_size_typ

            let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

            let _ = bin_write_typ

            let bin_writer_typ =
              { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

            let _ = bin_writer_typ

            let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
              __bin_read_t__

            let _ = __bin_read_typ__

            let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

            let _ = bin_read_typ

            let bin_reader_typ =
              { Bin_prot.Type_class.read = bin_read_typ
              ; vtag_read = __bin_read_typ__
              }

            let _ = bin_reader_typ

            let bin_typ =
              { Bin_prot.Type_class.writer = bin_writer_typ
              ; reader = bin_reader_typ
              ; shape = bin_shape_typ
              }

            let _ = bin_typ

            type t = { version : int; t : typ } [@@deriving bin_io]

            let _ = fun (_ : t) -> ()

            let bin_shape_t =
              let _group =
                Bin_prot.Shape.group
                  (Bin_prot.Shape.Location.of_string
                     "test/versioned_good.ml:131:8" )
                  [ ( Bin_prot.Shape.Tid.of_string "t"
                    , []
                    , Bin_prot.Shape.record
                        [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                  ]
              in
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t") )
                []

            let _ = bin_shape_t

            let (bin_size_t : t Bin_prot.Size.sizer) = function
              | { version = v1; t = v2 } ->
                  let size = 0 in
                  let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                  Bin_prot.Common.( + ) size (bin_size_typ v2)

            let _ = bin_size_t

            let (bin_write_t : t Bin_prot.Write.writer) =
             fun buf ~pos -> function
              | { version = v1; t = v2 } ->
                  let pos = bin_write_int buf ~pos v1 in
                  bin_write_typ buf ~pos v2

            let _ = bin_write_t

            let bin_writer_t =
              { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

            let _ = bin_writer_t

            let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
             fun _buf ~pos_ref _vint ->
              Bin_prot.Common.raise_variant_wrong_type
                "test/versioned_good.ml.M7.M.Stable.V1.With_version.t" !pos_ref

            let _ = __bin_read_t__

            let (bin_read_t : t Bin_prot.Read.reader) =
             fun buf ~pos_ref ->
              let v_version = bin_read_int buf ~pos_ref in
              let v_t = bin_read_typ buf ~pos_ref in
              { version = v_version; t = v_t }

            let _ = bin_read_t

            let bin_reader_t =
              { Bin_prot.Type_class.read = bin_read_t
              ; vtag_read = __bin_read_t__
              }

            let _ = bin_reader_t

            let bin_t =
              { Bin_prot.Type_class.writer = bin_writer_t
              ; reader = bin_reader_t
              ; shape = bin_shape_t
              }

            let _ = bin_t

            let create t = { t; version = 1 }
          end

          let bin_read_t buf ~pos_ref =
            let With_version.{ version = read_version; t } =
              With_version.bin_read_t buf ~pos_ref
            in
            if not (Core_kernel.Int.equal read_version version) then
              failwith
                (Core_kernel.sprintf
                   "bin_read_t: version read %d does not match expected \
                    version %d"
                   read_version version ) ;
            t

          let __bin_read_t__ buf ~pos_ref i =
            let With_version.{ version = read_version; t } =
              With_version.__bin_read_t__ buf ~pos_ref i
            in
            if not (Core_kernel.Int.equal read_version version) then
              failwith
                (Core_kernel.sprintf
                   "__bin_read_t__: version read %d does not match expected \
                    version %d"
                   read_version version ) ;
            t

          let bin_size_t t = With_version.bin_size_t (With_version.create t)

          let bin_write_t buf ~pos t =
            With_version.bin_write_t buf ~pos (With_version.create t)

          let bin_shape_t = With_version.bin_shape_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let bin_t =
            { Bin_prot.Type_class.shape = bin_shape_t
            ; writer = bin_writer_t
            ; reader = bin_reader_t
            }

          let _ =
            ( bin_read_t
            , __bin_read_t__
            , bin_size_t
            , bin_write_t
            , bin_shape_t
            , bin_reader_t
            , bin_writer_t
            , bin_t )
        end

        module Latest = V1

        let (versions :
              (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
              array ) =
          [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref))
          |]

        let bin_read_to_latest_opt buf ~pos_ref =
          let open Core_kernel in
          let saved_pos = !pos_ref in
          let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
          let pos_ref = ref saved_pos in
          Array.find_map versions ~f:(fun (i, f) ->
              if Int.equal i version then Some (f buf ~pos_ref) else None )
          [@@ocaml.doc
            " deserializes data to the latest module version's type "]

        let _ = bin_read_to_latest_opt
      end

      type t = Stable.Latest.t [@@deriving yojson]

      let rec (to_yojson : t -> Yojson.Safe.t) =
        ((let open! Ppx_deriving_yojson_runtime in
         fun x -> Stable.Latest.to_yojson x) [@ocaml.warning "-A"] )
        [@@ocaml.warning "-39"]

      and (of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or)
          =
        ((let open! Ppx_deriving_yojson_runtime in
         fun x -> Stable.Latest.of_yojson x) [@ocaml.warning "-A"] )
        [@@ocaml.warning "-39"]

      let _ = to_yojson

      let _ = of_yojson

      let _ = fun (_ : t) -> ()
    end
  end
end

module M8 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = Int.t List.t [@@deriving bin_io, version { asserted }]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:144:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , List.bin_shape_t Int.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> List.bin_size_t Int.bin_size_t v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v -> (List.bin_write_t Int.bin_write_t) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (List.__bin_read_t__ Int.bin_read_t) buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref -> (List.bin_read_t Int.bin_read_t) buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:144:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:144:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M8.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt

      module Tests = struct end
    end

    type t = Stable.Latest.t
  end
end

module M9 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = int32 [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:158:6")
              [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_int32) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_int32

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = bin_write_int32

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          __bin_read_int32__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = bin_read_int32

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:158:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:158:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M9.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end

module M10 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = int64 [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:170:6")
              [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_int64) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_int64

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = bin_write_int64

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          __bin_read_int64__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = bin_read_int64

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:170:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:170:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M10.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end

module M11 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = bytes [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:182:6")
              [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_bytes) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_bytes

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = bin_write_bytes

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          __bin_read_bytes__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = bin_read_bytes

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:182:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:182:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M11.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end

module M12 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = int Core_kernel.Queue.Stable.V1.t [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:194:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Core_kernel.Queue.Stable.V1.bin_shape_t bin_shape_int )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> Core_kernel.Queue.Stable.V1.bin_size_t bin_size_int v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v ->
          (Core_kernel.Queue.Stable.V1.bin_write_t bin_write_int) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (Core_kernel.Queue.Stable.V1.__bin_read_t__ bin_read_int)
            buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          (Core_kernel.Queue.Stable.V1.bin_read_t bin_read_int) buf ~pos_ref

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:194:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:194:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M12.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end

module M13 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = Core_kernel.Time.Stable.Span.V1.t
        [@@deriving bin_io, version, bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:206:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Core_kernel.Time.Stable.Span.V1.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
          Core_kernel.Time.Stable.Span.V1.bin_size_t

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
          Core_kernel.Time.Stable.Span.V1.bin_write_t

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          Core_kernel.Time.Stable.Span.V1.__bin_read_t__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
          Core_kernel.Time.Stable.Span.V1.bin_read_t

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string "test/versioned_good.ml:206:6")
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Core_kernel.Time.Stable.Span.V1.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
          Core_kernel.Time.Stable.Span.V1.bin_size_t

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
          Core_kernel.Time.Stable.Span.V1.bin_write_t

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          Core_kernel.Time.Stable.Span.V1.__bin_read_t__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
          Core_kernel.Time.Stable.Span.V1.bin_read_t

        let _ = bin_read_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let _ = bin_reader_t

        let bin_t =
          { Bin_prot.Type_class.writer = bin_writer_t
          ; reader = bin_reader_t
          ; shape = bin_shape_t
          }

        let _ = bin_t

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:206:6" )
                [ (Bin_prot.Shape.Tid.of_string "typ", [], bin_shape_t) ]
            in
            (Bin_prot.Shape.top_app _group
               (Bin_prot.Shape.Tid.of_string "typ") )
              []

          let _ = bin_shape_typ

          let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t

          let _ = bin_size_typ

          let (bin_write_typ : typ Bin_prot.Write.writer) = bin_write_t

          let _ = bin_write_typ

          let bin_writer_typ =
            { Bin_prot.Type_class.size = bin_size_typ; write = bin_write_typ }

          let _ = bin_writer_typ

          let (__bin_read_typ__ : (int -> typ) Bin_prot.Read.reader) =
            __bin_read_t__

          let _ = __bin_read_typ__

          let (bin_read_typ : typ Bin_prot.Read.reader) = bin_read_t

          let _ = bin_read_typ

          let bin_reader_typ =
            { Bin_prot.Type_class.read = bin_read_typ
            ; vtag_read = __bin_read_typ__
            }

          let _ = bin_reader_typ

          let bin_typ =
            { Bin_prot.Type_class.writer = bin_writer_typ
            ; reader = bin_reader_typ
            ; shape = bin_shape_typ
            }

          let _ = bin_typ

          type t = { version : int; t : typ } [@@deriving bin_io]

          let _ = fun (_ : t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_good.ml:206:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , []
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int); ("t", bin_shape_typ) ] )
                ]
            in
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              []

          let _ = bin_shape_t

          let (bin_size_t : t Bin_prot.Size.sizer) = function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ v2)

          let _ = bin_size_t

          let (bin_write_t : t Bin_prot.Write.writer) =
           fun buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                bin_write_typ buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t =
            { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

          let _ = bin_writer_t

          let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
           fun _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_good.ml.M13.Stable.V1.With_version.t" !pos_ref

          let _ = __bin_read_t__

          let (bin_read_t : t Bin_prot.Read.reader) =
           fun buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = bin_read_typ buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t =
            { Bin_prot.Type_class.read = bin_read_t
            ; vtag_read = __bin_read_t__
            }

          let _ = bin_reader_t

          let bin_t =
            { Bin_prot.Type_class.writer = bin_writer_t
            ; reader = bin_reader_t
            ; shape = bin_shape_t
            }

          let _ = bin_t

          let create t = { t; version = 1 }
        end

        let bin_read_t buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            With_version.bin_read_t buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            With_version.__bin_read_t__ buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t t = With_version.bin_size_t (With_version.create t)

        let bin_write_t buf ~pos t =
          With_version.bin_write_t buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t =
          { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ }

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let bin_t =
          { Bin_prot.Type_class.shape = bin_shape_t
          ; writer = bin_writer_t
          ; reader = bin_reader_t
          }

        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )
      end

      module Latest = V1

      let (versions :
            (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array ) =
        [| (1, fun buf ~pos_ref -> V1.to_latest (V1.bin_read_t buf ~pos_ref)) |]

      let bin_read_to_latest_opt buf ~pos_ref =
        let open Core_kernel in
        let saved_pos = !pos_ref in
        let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
        let pos_ref = ref saved_pos in
        Array.find_map versions ~f:(fun (i, f) ->
            if Int.equal i version then Some (f buf ~pos_ref) else None )
        [@@ocaml.doc " deserializes data to the latest module version's type "]

      let _ = bin_read_to_latest_opt
    end

    type t = Stable.Latest.t
  end
end
