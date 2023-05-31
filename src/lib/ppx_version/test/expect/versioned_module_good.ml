open Core_kernel

module M1 = struct
  include struct
    module Stable = struct
      module V3 = struct
        type t = int [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:8:6" )
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

        let version = 3

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
                   "test/versioned_module_good.ml:8:6" )
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
                   "test/versioned_module_good.ml:8:6" )
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
              "test/versioned_module_good.ml.M1.Stable.V3.With_version.t"
              !pos_ref

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

      module Latest = V3

      module V2 = struct
        type t = int [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:14:6" )
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

        let version = 2

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
                   "test/versioned_module_good.ml:14:6" )
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
                   "test/versioned_module_good.ml:14:6" )
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
              "test/versioned_module_good.ml.M1.Stable.V2.With_version.t"
              !pos_ref

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
        type t = bool [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:20:6" )
              [ (Bin_prot.Shape.Tid.of_string "t", [], bin_shape_bool) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_bool

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = bin_write_bool

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          __bin_read_bool__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = bin_read_bool

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

        let to_latest b = if b then 1 else 0

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:20:6" )
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
                   "test/versioned_module_good.ml:20:6" )
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
              "test/versioned_module_good.ml.M1.Stable.V1.With_version.t"
              !pos_ref

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

    type t = Stable.Latest.t
  end
end

let () =
  let x = 15 in
  let buf = Bigstring.create 10 in
  ignore (M1.Stable.V3.bin_write_t buf ~pos:0 x) ;
  let y : M1.Stable.V3.With_version.t =
    M1.Stable.V3.With_version.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (y.version = 3) ;
  assert (y.t = x) ;
  let z = M1.Stable.V3.bin_read_t buf ~pos_ref:(ref 0) in
  assert (z = x) ;
  ( try
      ignore (M1.Stable.V2.bin_read_t buf ~pos_ref:(ref 0)) ;
      assert false
    with Failure _ -> () ) ;
  match M1.Stable.bin_read_to_latest_opt buf ~pos_ref:(ref 0) with
  | Some a ->
      assert (a = x)
  | None ->
      assert false

module M2 = struct
  include struct
    module Stable = struct
      module V3 = struct
        type 'a t = { a : 'a; b : int } [@@deriving bin_io, version]

        let _ = fun (_ : 'a t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:62:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , [ Bin_prot.Shape.Vid.of_string "a" ]
                , Bin_prot.Shape.record
                    [ ( "a"
                      , Bin_prot.Shape.var
                          (Bin_prot.Shape.Location.of_string
                             "test/versioned_module_good.ml:62:22" )
                          (Bin_prot.Shape.Vid.of_string "a") )
                    ; ("b", bin_shape_int)
                    ] )
              ]
          in
          fun a ->
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              [ a ]

        let _ = bin_shape_t

        let bin_size_t : 'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
            =
         fun _size_of_a -> function
          | { a = v1; b = v2 } ->
              let size = 0 in
              let size = Bin_prot.Common.( + ) size (_size_of_a v1) in
              Bin_prot.Common.( + ) size (bin_size_int v2)

        let _ = bin_size_t

        let bin_write_t :
              'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
         fun _write_a buf ~pos -> function
          | { a = v1; b = v2 } ->
              let pos = _write_a buf ~pos v1 in
              bin_write_int buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t bin_writer_a =
          { Bin_prot.Type_class.size =
              (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
          ; write =
              (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
          }

        let _ = bin_writer_t

        let __bin_read_t__ :
              'a. 'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader
            =
         fun _of__a _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M2.Stable.V3.t" !pos_ref

        let _ = __bin_read_t__

        let bin_read_t :
              'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
         fun _of__a buf ~pos_ref ->
          let v_a = _of__a buf ~pos_ref in
          let v_b = bin_read_int buf ~pos_ref in
          { a = v_a; b = v_b }

        let _ = bin_read_t

        let bin_reader_t bin_reader_a =
          { Bin_prot.Type_class.read =
              (fun buf ~pos_ref ->
                (bin_read_t bin_reader_a.Bin_prot.Type_class.read) buf ~pos_ref
                )
          ; vtag_read =
              (fun buf ~pos_ref vtag ->
                (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                  buf ~pos_ref vtag )
          }

        let _ = bin_reader_t

        let bin_t bin_a =
          { Bin_prot.Type_class.writer =
              bin_writer_t bin_a.Bin_prot.Type_class.writer
          ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
          ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
          }

        let _ = bin_t

        let version = 3

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        module With_version = struct
          type 'a typ = 'a t [@@deriving bin_io]

          let _ = fun (_ : 'a typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:62:6" )
                [ ( Bin_prot.Shape.Tid.of_string "typ"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , bin_shape_t
                      (Bin_prot.Shape.var
                         (Bin_prot.Shape.Location.of_string
                            "test/versioned_module_good.ml:62:11" )
                         (Bin_prot.Shape.Vid.of_string "a") ) )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "typ") )
                [ a ]

          let _ = bin_shape_typ

          let bin_size_typ :
                'a. 'a Bin_prot.Size.sizer -> 'a typ Bin_prot.Size.sizer =
           fun _size_of_a v -> bin_size_t _size_of_a v

          let _ = bin_size_typ

          let bin_write_typ :
                'a. 'a Bin_prot.Write.writer -> 'a typ Bin_prot.Write.writer =
           fun _write_a buf ~pos v -> (bin_write_t _write_a) buf ~pos v

          let _ = bin_write_typ

          let bin_writer_typ bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_typ bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_typ bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_typ

          let __bin_read_typ__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a typ) Bin_prot.Read.reader
              =
           fun _of__a buf ~pos_ref vint ->
            (__bin_read_t__ _of__a) buf ~pos_ref vint

          let _ = __bin_read_typ__

          let bin_read_typ :
                'a. 'a Bin_prot.Read.reader -> 'a typ Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref -> (bin_read_t _of__a) buf ~pos_ref

          let _ = bin_read_typ

          let bin_reader_typ bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_typ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_typ__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_typ

          let bin_typ bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_typ bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_typ bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_typ bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_typ

          type 'a t = { version : int; t : 'a typ } [@@deriving bin_io]

          let _ = fun (_ : 'a t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:62:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int)
                      ; ( "t"
                        , bin_shape_typ
                            (Bin_prot.Shape.var
                               (Bin_prot.Shape.Location.of_string
                                  "test/versioned_module_good.ml:62:11" )
                               (Bin_prot.Shape.Vid.of_string "a") ) )
                      ] )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t") )
                [ a ]

          let _ = bin_shape_t

          let bin_size_t :
                'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer =
           fun _size_of_a -> function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ _size_of_a v2)

          let _ = bin_size_t

          let bin_write_t :
                'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
           fun _write_a buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                (bin_write_typ _write_a) buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_t

          let __bin_read_t__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader =
           fun _of__a _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_module_good.ml.M2.Stable.V3.With_version.t"
              !pos_ref

          let _ = __bin_read_t__

          let bin_read_t :
                'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = (bin_read_typ _of__a) buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_t bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_t

          let bin_t bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_t bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_t

          let create t = { t; version = 3 }
        end

        let bin_read_t x0 buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            (With_version.bin_read_t x0) buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ x0 buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            (With_version.__bin_read_t__ x0) buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t x0 t = With_version.bin_size_t x0 (With_version.create t)

        let bin_write_t x0 buf ~pos t =
          (With_version.bin_write_t x0) buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t x0 =
          { Bin_prot.Type_class.read = bin_read_t x0.Bin_prot.Type_class.read
          ; vtag_read = __bin_read_t__ x0.Bin_prot.Type_class.read
          }

        let bin_writer_t x0 =
          { Bin_prot.Type_class.size = bin_size_t x0.Bin_prot.Type_class.size
          ; write = bin_write_t x0.Bin_prot.Type_class.write
          }

        let bin_t x0 =
          { Bin_prot.Type_class.shape = bin_shape_t x0.Bin_prot.Type_class.shape
          ; writer = bin_writer_t x0.Bin_prot.Type_class.writer
          ; reader = bin_reader_t x0.Bin_prot.Type_class.reader
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

      module Latest = V3

      module V2 = struct
        type 'a t = { b : M1.Stable.V3.t; a : 'a } [@@deriving bin_io, version]

        let _ = fun (_ : 'a t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:66:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , [ Bin_prot.Shape.Vid.of_string "a" ]
                , Bin_prot.Shape.record
                    [ ("b", M1.Stable.V3.bin_shape_t)
                    ; ( "a"
                      , Bin_prot.Shape.var
                          (Bin_prot.Shape.Location.of_string
                             "test/versioned_module_good.ml:66:41" )
                          (Bin_prot.Shape.Vid.of_string "a") )
                    ] )
              ]
          in
          fun a ->
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              [ a ]

        let _ = bin_shape_t

        let bin_size_t : 'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
            =
         fun _size_of_a -> function
          | { b = v1; a = v2 } ->
              let size = 0 in
              let size =
                Bin_prot.Common.( + ) size (M1.Stable.V3.bin_size_t v1)
              in
              Bin_prot.Common.( + ) size (_size_of_a v2)

        let _ = bin_size_t

        let bin_write_t :
              'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
         fun _write_a buf ~pos -> function
          | { b = v1; a = v2 } ->
              let pos = M1.Stable.V3.bin_write_t buf ~pos v1 in
              _write_a buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t bin_writer_a =
          { Bin_prot.Type_class.size =
              (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
          ; write =
              (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
          }

        let _ = bin_writer_t

        let __bin_read_t__ :
              'a. 'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader
            =
         fun _of__a _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M2.Stable.V2.t" !pos_ref

        let _ = __bin_read_t__

        let bin_read_t :
              'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
         fun _of__a buf ~pos_ref ->
          let v_b = M1.Stable.V3.bin_read_t buf ~pos_ref in
          let v_a = _of__a buf ~pos_ref in
          { b = v_b; a = v_a }

        let _ = bin_read_t

        let bin_reader_t bin_reader_a =
          { Bin_prot.Type_class.read =
              (fun buf ~pos_ref ->
                (bin_read_t bin_reader_a.Bin_prot.Type_class.read) buf ~pos_ref
                )
          ; vtag_read =
              (fun buf ~pos_ref vtag ->
                (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                  buf ~pos_ref vtag )
          }

        let _ = bin_reader_t

        let bin_t bin_a =
          { Bin_prot.Type_class.writer =
              bin_writer_t bin_a.Bin_prot.Type_class.writer
          ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
          ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
          }

        let _ = bin_t

        let version = 2

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = M1.Stable.V3.__versioned__

        module With_version = struct
          type 'a typ = 'a t [@@deriving bin_io]

          let _ = fun (_ : 'a typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:66:6" )
                [ ( Bin_prot.Shape.Tid.of_string "typ"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , bin_shape_t
                      (Bin_prot.Shape.var
                         (Bin_prot.Shape.Location.of_string
                            "test/versioned_module_good.ml:66:11" )
                         (Bin_prot.Shape.Vid.of_string "a") ) )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "typ") )
                [ a ]

          let _ = bin_shape_typ

          let bin_size_typ :
                'a. 'a Bin_prot.Size.sizer -> 'a typ Bin_prot.Size.sizer =
           fun _size_of_a v -> bin_size_t _size_of_a v

          let _ = bin_size_typ

          let bin_write_typ :
                'a. 'a Bin_prot.Write.writer -> 'a typ Bin_prot.Write.writer =
           fun _write_a buf ~pos v -> (bin_write_t _write_a) buf ~pos v

          let _ = bin_write_typ

          let bin_writer_typ bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_typ bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_typ bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_typ

          let __bin_read_typ__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a typ) Bin_prot.Read.reader
              =
           fun _of__a buf ~pos_ref vint ->
            (__bin_read_t__ _of__a) buf ~pos_ref vint

          let _ = __bin_read_typ__

          let bin_read_typ :
                'a. 'a Bin_prot.Read.reader -> 'a typ Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref -> (bin_read_t _of__a) buf ~pos_ref

          let _ = bin_read_typ

          let bin_reader_typ bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_typ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_typ__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_typ

          let bin_typ bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_typ bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_typ bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_typ bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_typ

          type 'a t = { version : int; t : 'a typ } [@@deriving bin_io]

          let _ = fun (_ : 'a t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:66:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int)
                      ; ( "t"
                        , bin_shape_typ
                            (Bin_prot.Shape.var
                               (Bin_prot.Shape.Location.of_string
                                  "test/versioned_module_good.ml:66:11" )
                               (Bin_prot.Shape.Vid.of_string "a") ) )
                      ] )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t") )
                [ a ]

          let _ = bin_shape_t

          let bin_size_t :
                'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer =
           fun _size_of_a -> function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ _size_of_a v2)

          let _ = bin_size_t

          let bin_write_t :
                'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
           fun _write_a buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                (bin_write_typ _write_a) buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_t

          let __bin_read_t__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader =
           fun _of__a _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_module_good.ml.M2.Stable.V2.With_version.t"
              !pos_ref

          let _ = __bin_read_t__

          let bin_read_t :
                'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = (bin_read_typ _of__a) buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_t bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_t

          let bin_t bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_t bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_t

          let create t = { t; version = 2 }
        end

        let bin_read_t x0 buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            (With_version.bin_read_t x0) buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ x0 buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            (With_version.__bin_read_t__ x0) buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t x0 t = With_version.bin_size_t x0 (With_version.create t)

        let bin_write_t x0 buf ~pos t =
          (With_version.bin_write_t x0) buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t x0 =
          { Bin_prot.Type_class.read = bin_read_t x0.Bin_prot.Type_class.read
          ; vtag_read = __bin_read_t__ x0.Bin_prot.Type_class.read
          }

        let bin_writer_t x0 =
          { Bin_prot.Type_class.size = bin_size_t x0.Bin_prot.Type_class.size
          ; write = bin_write_t x0.Bin_prot.Type_class.write
          }

        let bin_t x0 =
          { Bin_prot.Type_class.shape = bin_shape_t x0.Bin_prot.Type_class.shape
          ; writer = bin_writer_t x0.Bin_prot.Type_class.writer
          ; reader = bin_reader_t x0.Bin_prot.Type_class.reader
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
        type t = { a : M1.Stable.V1.t } [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:70:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record [ ("a", M1.Stable.V1.bin_shape_t) ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { a = v1 } ->
              let size = 0 in
              Bin_prot.Common.( + ) size (M1.Stable.V1.bin_size_t v1)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { a = v1 } ->
              M1.Stable.V1.bin_write_t buf ~pos v1

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M2.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_a = M1.Stable.V1.bin_read_t buf ~pos_ref in
          { a = v_a }

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

        let _ = M1.Stable.V1.__versioned__

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:70:6" )
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
                   "test/versioned_module_good.ml:70:6" )
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
              "test/versioned_module_good.ml.M2.Stable.V1.With_version.t"
              !pos_ref

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
    end

    type 'a t = 'a Stable.Latest.t = { a : 'a; b : int }
  end
end

module M3 = struct
  include struct
    module Stable = struct
      module V3 = struct
        type t = { a : bool; b : int } [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:80:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record
                    [ ("a", bin_shape_bool); ("b", bin_shape_int) ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { a = v1; b = v2 } ->
              let size = 0 in
              let size = Bin_prot.Common.( + ) size (bin_size_bool v1) in
              Bin_prot.Common.( + ) size (bin_size_int v2)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { a = v1; b = v2 } ->
              let pos = bin_write_bool buf ~pos v1 in
              bin_write_int buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M3.Stable.V3.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_a = bin_read_bool buf ~pos_ref in
          let v_b = bin_read_int buf ~pos_ref in
          { a = v_a; b = v_b }

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

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:80:6" )
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
                   "test/versioned_module_good.ml:80:6" )
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
              "test/versioned_module_good.ml.M3.Stable.V3.With_version.t"
              !pos_ref

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

      module Latest = V3

      module V2 = struct
        type 'a t = { b : M1.Stable.V3.t; a : 'a } [@@deriving bin_io, version]

        let _ = fun (_ : 'a t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:86:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , [ Bin_prot.Shape.Vid.of_string "a" ]
                , Bin_prot.Shape.record
                    [ ("b", M1.Stable.V3.bin_shape_t)
                    ; ( "a"
                      , Bin_prot.Shape.var
                          (Bin_prot.Shape.Location.of_string
                             "test/versioned_module_good.ml:86:41" )
                          (Bin_prot.Shape.Vid.of_string "a") )
                    ] )
              ]
          in
          fun a ->
            (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t"))
              [ a ]

        let _ = bin_shape_t

        let bin_size_t : 'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer
            =
         fun _size_of_a -> function
          | { b = v1; a = v2 } ->
              let size = 0 in
              let size =
                Bin_prot.Common.( + ) size (M1.Stable.V3.bin_size_t v1)
              in
              Bin_prot.Common.( + ) size (_size_of_a v2)

        let _ = bin_size_t

        let bin_write_t :
              'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
         fun _write_a buf ~pos -> function
          | { b = v1; a = v2 } ->
              let pos = M1.Stable.V3.bin_write_t buf ~pos v1 in
              _write_a buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t bin_writer_a =
          { Bin_prot.Type_class.size =
              (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
          ; write =
              (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
          }

        let _ = bin_writer_t

        let __bin_read_t__ :
              'a. 'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader
            =
         fun _of__a _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M3.Stable.V2.t" !pos_ref

        let _ = __bin_read_t__

        let bin_read_t :
              'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
         fun _of__a buf ~pos_ref ->
          let v_b = M1.Stable.V3.bin_read_t buf ~pos_ref in
          let v_a = _of__a buf ~pos_ref in
          { b = v_b; a = v_a }

        let _ = bin_read_t

        let bin_reader_t bin_reader_a =
          { Bin_prot.Type_class.read =
              (fun buf ~pos_ref ->
                (bin_read_t bin_reader_a.Bin_prot.Type_class.read) buf ~pos_ref
                )
          ; vtag_read =
              (fun buf ~pos_ref vtag ->
                (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                  buf ~pos_ref vtag )
          }

        let _ = bin_reader_t

        let bin_t bin_a =
          { Bin_prot.Type_class.writer =
              bin_writer_t bin_a.Bin_prot.Type_class.writer
          ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
          ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
          }

        let _ = bin_t

        let version = 2

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let _ = M1.Stable.V3.__versioned__

        module With_version = struct
          type 'a typ = 'a t [@@deriving bin_io]

          let _ = fun (_ : 'a typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:86:6" )
                [ ( Bin_prot.Shape.Tid.of_string "typ"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , bin_shape_t
                      (Bin_prot.Shape.var
                         (Bin_prot.Shape.Location.of_string
                            "test/versioned_module_good.ml:86:11" )
                         (Bin_prot.Shape.Vid.of_string "a") ) )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "typ") )
                [ a ]

          let _ = bin_shape_typ

          let bin_size_typ :
                'a. 'a Bin_prot.Size.sizer -> 'a typ Bin_prot.Size.sizer =
           fun _size_of_a v -> bin_size_t _size_of_a v

          let _ = bin_size_typ

          let bin_write_typ :
                'a. 'a Bin_prot.Write.writer -> 'a typ Bin_prot.Write.writer =
           fun _write_a buf ~pos v -> (bin_write_t _write_a) buf ~pos v

          let _ = bin_write_typ

          let bin_writer_typ bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_typ bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_typ bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_typ

          let __bin_read_typ__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a typ) Bin_prot.Read.reader
              =
           fun _of__a buf ~pos_ref vint ->
            (__bin_read_t__ _of__a) buf ~pos_ref vint

          let _ = __bin_read_typ__

          let bin_read_typ :
                'a. 'a Bin_prot.Read.reader -> 'a typ Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref -> (bin_read_t _of__a) buf ~pos_ref

          let _ = bin_read_typ

          let bin_reader_typ bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_typ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_typ__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_typ

          let bin_typ bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_typ bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_typ bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_typ bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_typ

          type 'a t = { version : int; t : 'a typ } [@@deriving bin_io]

          let _ = fun (_ : 'a t) -> ()

          let bin_shape_t =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:86:6" )
                [ ( Bin_prot.Shape.Tid.of_string "t"
                  , [ Bin_prot.Shape.Vid.of_string "a" ]
                  , Bin_prot.Shape.record
                      [ ("version", bin_shape_int)
                      ; ( "t"
                        , bin_shape_typ
                            (Bin_prot.Shape.var
                               (Bin_prot.Shape.Location.of_string
                                  "test/versioned_module_good.ml:86:11" )
                               (Bin_prot.Shape.Vid.of_string "a") ) )
                      ] )
                ]
            in
            fun a ->
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t") )
                [ a ]

          let _ = bin_shape_t

          let bin_size_t :
                'a. 'a Bin_prot.Size.sizer -> 'a t Bin_prot.Size.sizer =
           fun _size_of_a -> function
            | { version = v1; t = v2 } ->
                let size = 0 in
                let size = Bin_prot.Common.( + ) size (bin_size_int v1) in
                Bin_prot.Common.( + ) size (bin_size_typ _size_of_a v2)

          let _ = bin_size_t

          let bin_write_t :
                'a. 'a Bin_prot.Write.writer -> 'a t Bin_prot.Write.writer =
           fun _write_a buf ~pos -> function
            | { version = v1; t = v2 } ->
                let pos = bin_write_int buf ~pos v1 in
                (bin_write_typ _write_a) buf ~pos v2

          let _ = bin_write_t

          let bin_writer_t bin_writer_a =
            { Bin_prot.Type_class.size =
                (fun v -> bin_size_t bin_writer_a.Bin_prot.Type_class.size v)
            ; write =
                (fun v -> bin_write_t bin_writer_a.Bin_prot.Type_class.write v)
            }

          let _ = bin_writer_t

          let __bin_read_t__ :
                'a.
                'a Bin_prot.Read.reader -> (int -> 'a t) Bin_prot.Read.reader =
           fun _of__a _buf ~pos_ref _vint ->
            Bin_prot.Common.raise_variant_wrong_type
              "test/versioned_module_good.ml.M3.Stable.V2.With_version.t"
              !pos_ref

          let _ = __bin_read_t__

          let bin_read_t :
                'a. 'a Bin_prot.Read.reader -> 'a t Bin_prot.Read.reader =
           fun _of__a buf ~pos_ref ->
            let v_version = bin_read_int buf ~pos_ref in
            let v_t = (bin_read_typ _of__a) buf ~pos_ref in
            { version = v_version; t = v_t }

          let _ = bin_read_t

          let bin_reader_t bin_reader_a =
            { Bin_prot.Type_class.read =
                (fun buf ~pos_ref ->
                  (bin_read_t bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref )
            ; vtag_read =
                (fun buf ~pos_ref vtag ->
                  (__bin_read_t__ bin_reader_a.Bin_prot.Type_class.read)
                    buf ~pos_ref vtag )
            }

          let _ = bin_reader_t

          let bin_t bin_a =
            { Bin_prot.Type_class.writer =
                bin_writer_t bin_a.Bin_prot.Type_class.writer
            ; reader = bin_reader_t bin_a.Bin_prot.Type_class.reader
            ; shape = bin_shape_t bin_a.Bin_prot.Type_class.shape
            }

          let _ = bin_t

          let create t = { t; version = 2 }
        end

        let bin_read_t x0 buf ~pos_ref =
          let With_version.{ version = read_version; t } =
            (With_version.bin_read_t x0) buf ~pos_ref
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "bin_read_t: version read %d does not match expected version \
                  %d"
                 read_version version ) ;
          t

        let __bin_read_t__ x0 buf ~pos_ref i =
          let With_version.{ version = read_version; t } =
            (With_version.__bin_read_t__ x0) buf ~pos_ref i
          in
          if not (Core_kernel.Int.equal read_version version) then
            failwith
              (Core_kernel.sprintf
                 "__bin_read_t__: version read %d does not match expected \
                  version %d"
                 read_version version ) ;
          t

        let bin_size_t x0 t = With_version.bin_size_t x0 (With_version.create t)

        let bin_write_t x0 buf ~pos t =
          (With_version.bin_write_t x0) buf ~pos (With_version.create t)

        let bin_shape_t = With_version.bin_shape_t

        let bin_reader_t x0 =
          { Bin_prot.Type_class.read = bin_read_t x0.Bin_prot.Type_class.read
          ; vtag_read = __bin_read_t__ x0.Bin_prot.Type_class.read
          }

        let bin_writer_t x0 =
          { Bin_prot.Type_class.size = bin_size_t x0.Bin_prot.Type_class.size
          ; write = bin_write_t x0.Bin_prot.Type_class.write
          }

        let bin_t x0 =
          { Bin_prot.Type_class.shape = bin_shape_t x0.Bin_prot.Type_class.shape
          ; writer = bin_writer_t x0.Bin_prot.Type_class.writer
          ; reader = bin_reader_t x0.Bin_prot.Type_class.reader
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
        type t = { a : M1.Stable.V1.t } [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:90:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record [ ("a", M1.Stable.V1.bin_shape_t) ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { a = v1 } ->
              let size = 0 in
              Bin_prot.Common.( + ) size (M1.Stable.V1.bin_size_t v1)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { a = v1 } ->
              M1.Stable.V1.bin_write_t buf ~pos v1

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M3.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_a = M1.Stable.V1.bin_read_t buf ~pos_ref in
          { a = v_a }

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

        let _ = M1.Stable.V1.__versioned__

        let to_latest { a } = { V3.a; b = (if a then 1 else 0) }

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:90:6" )
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
                   "test/versioned_module_good.ml:90:6" )
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
              "test/versioned_module_good.ml.M3.Stable.V1.With_version.t"
              !pos_ref

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
         ; (3, fun buf ~pos_ref -> V3.to_latest (V3.bin_read_t buf ~pos_ref))
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

    type t = Stable.Latest.t = { a : bool; b : int }
  end
end

let () =
  let x : M1.Stable.V3.t M2.Stable.V3.t = { M2.a = 15; b = 15 } in
  let buf = Bigstring.create 20 in
  ignore (M2.Stable.V3.bin_write_t M1.Stable.V3.bin_write_t buf ~pos:0 x) ;
  let y : M1.Stable.V3.t M2.Stable.V3.With_version.t =
    M2.Stable.V3.With_version.bin_read_t M1.Stable.V3.bin_read_t buf
      ~pos_ref:(ref 0)
  in
  assert (y.version = 3) ;
  assert (y.t = x) ;
  let z =
    M2.Stable.V3.bin_read_t M1.Stable.V3.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (z = x) ;
  try
    ignore (M2.Stable.V3.bin_read_t bin_read_int buf ~pos_ref:(ref 0)) ;
    assert false
  with Assert_failure _ -> ()

module M4 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = { a : bool; b : int } [@@deriving bin_io, version, sexp, equal]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:136:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , Bin_prot.Shape.record
                    [ ("a", bin_shape_bool); ("b", bin_shape_int) ] )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = function
          | { a = v1; b = v2 } ->
              let size = 0 in
              let size = Bin_prot.Common.( + ) size (bin_size_bool v1) in
              Bin_prot.Common.( + ) size (bin_size_int v2)

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos -> function
          | { a = v1; b = v2 } ->
              let pos = bin_write_bool buf ~pos v1 in
              bin_write_int buf ~pos v2

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun _buf ~pos_ref _vint ->
          Bin_prot.Common.raise_variant_wrong_type
            "test/versioned_module_good.ml.M4.Stable.V1.t" !pos_ref

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          let v_a = bin_read_bool buf ~pos_ref in
          let v_b = bin_read_int buf ~pos_ref in
          { a = v_a; b = v_b }

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

        let t_of_sexp =
          ( let _tp_loc = "test/versioned_module_good.ml.M4.Stable.V1.t" in
            function
            | Ppx_sexp_conv_lib.Sexp.List field_sexps as sexp -> (
                let a_field = ref None
                and b_field = ref None
                and duplicates = ref []
                and extra = ref [] in
                let rec iter = function
                  | Ppx_sexp_conv_lib.Sexp.List
                      [ Ppx_sexp_conv_lib.Sexp.Atom field_name; _field_sexp ]
                    :: tail ->
                      ( match field_name with
                      | "a" -> (
                          match !a_field with
                          | None ->
                              let fvalue = bool_of_sexp _field_sexp in
                              a_field := Some fvalue
                          | Some _ ->
                              duplicates := field_name :: !duplicates )
                      | "b" -> (
                          match !b_field with
                          | None ->
                              let fvalue = int_of_sexp _field_sexp in
                              b_field := Some fvalue
                          | Some _ ->
                              duplicates := field_name :: !duplicates )
                      | _ ->
                          if !Ppx_sexp_conv_lib.Conv.record_check_extra_fields
                          then extra := field_name :: !extra
                          else () ) ;
                      iter tail
                  | Ppx_sexp_conv_lib.Sexp.List
                      [ Ppx_sexp_conv_lib.Sexp.Atom field_name ]
                    :: tail ->
                      (let _ = field_name in
                       if !Ppx_sexp_conv_lib.Conv.record_check_extra_fields then
                         extra := field_name :: !extra
                       else () ) ;
                      iter tail
                  | ( ( Ppx_sexp_conv_lib.Sexp.Atom _
                      | Ppx_sexp_conv_lib.Sexp.List _ ) as sexp )
                    :: _ ->
                      Ppx_sexp_conv_lib.Conv_error.record_only_pairs_expected
                        _tp_loc sexp
                  | [] ->
                      ()
                in
                iter field_sexps ;
                match !duplicates with
                | _ :: _ ->
                    Ppx_sexp_conv_lib.Conv_error.record_duplicate_fields _tp_loc
                      !duplicates sexp
                | [] -> (
                    match !extra with
                    | _ :: _ ->
                        Ppx_sexp_conv_lib.Conv_error.record_extra_fields _tp_loc
                          !extra sexp
                    | [] -> (
                        match (!a_field, !b_field) with
                        | Some a_value, Some b_value ->
                            { a = a_value; b = b_value }
                        | _ ->
                            Ppx_sexp_conv_lib.Conv_error
                            .record_undefined_elements _tp_loc sexp
                              [ (Ppx_sexp_conv_lib.Conv.( = ) !a_field None, "a")
                              ; (Ppx_sexp_conv_lib.Conv.( = ) !b_field None, "b")
                              ] ) ) )
            | Ppx_sexp_conv_lib.Sexp.Atom _ as sexp ->
                Ppx_sexp_conv_lib.Conv_error.record_list_instead_atom _tp_loc
                  sexp
            : Ppx_sexp_conv_lib.Sexp.t -> t )

        let _ = t_of_sexp

        let sexp_of_t =
          ( function
            | { a = v_a; b = v_b } ->
                let bnds = [] in
                let bnds =
                  let arg = sexp_of_int v_b in
                  Ppx_sexp_conv_lib.Sexp.List
                    [ Ppx_sexp_conv_lib.Sexp.Atom "b"; arg ]
                  :: bnds
                in
                let bnds =
                  let arg = sexp_of_bool v_a in
                  Ppx_sexp_conv_lib.Sexp.List
                    [ Ppx_sexp_conv_lib.Sexp.Atom "a"; arg ]
                  :: bnds
                in
                Ppx_sexp_conv_lib.Sexp.List bnds
            : t -> Ppx_sexp_conv_lib.Sexp.t )

        let _ = sexp_of_t

        let equal =
          ( fun a__001_ b__002_ ->
              if Ppx_compare_lib.phys_equal a__001_ b__002_ then true
              else
                Ppx_compare_lib.( && )
                  (equal_bool a__001_.a b__002_.a)
                  (equal_int a__001_.b b__002_.b)
            : t -> t -> bool )

        let _ = equal

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:136:6" )
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
                   "test/versioned_module_good.ml:136:6" )
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
              "test/versioned_module_good.ml.M4.Stable.V1.With_version.t"
              !pos_ref

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

    type t = Stable.Latest.t = { a : bool; b : int } [@@deriving sexp, equal]

    let _ = fun (_ : t) -> ()

    let t_of_sexp =
      ( let _tp_loc = "test/versioned_module_good.ml.M4.t" in
        function
        | Ppx_sexp_conv_lib.Sexp.List field_sexps as sexp -> (
            let a_field = ref None
            and b_field = ref None
            and duplicates = ref []
            and extra = ref [] in
            let rec iter = function
              | Ppx_sexp_conv_lib.Sexp.List
                  [ Ppx_sexp_conv_lib.Sexp.Atom field_name; _field_sexp ]
                :: tail ->
                  ( match field_name with
                  | "a" -> (
                      match !a_field with
                      | None ->
                          let fvalue = bool_of_sexp _field_sexp in
                          a_field := Some fvalue
                      | Some _ ->
                          duplicates := field_name :: !duplicates )
                  | "b" -> (
                      match !b_field with
                      | None ->
                          let fvalue = int_of_sexp _field_sexp in
                          b_field := Some fvalue
                      | Some _ ->
                          duplicates := field_name :: !duplicates )
                  | _ ->
                      if !Ppx_sexp_conv_lib.Conv.record_check_extra_fields then
                        extra := field_name :: !extra
                      else () ) ;
                  iter tail
              | Ppx_sexp_conv_lib.Sexp.List
                  [ Ppx_sexp_conv_lib.Sexp.Atom field_name ]
                :: tail ->
                  (let _ = field_name in
                   if !Ppx_sexp_conv_lib.Conv.record_check_extra_fields then
                     extra := field_name :: !extra
                   else () ) ;
                  iter tail
              | ( (Ppx_sexp_conv_lib.Sexp.Atom _ | Ppx_sexp_conv_lib.Sexp.List _)
                as sexp )
                :: _ ->
                  Ppx_sexp_conv_lib.Conv_error.record_only_pairs_expected
                    _tp_loc sexp
              | [] ->
                  ()
            in
            iter field_sexps ;
            match !duplicates with
            | _ :: _ ->
                Ppx_sexp_conv_lib.Conv_error.record_duplicate_fields _tp_loc
                  !duplicates sexp
            | [] -> (
                match !extra with
                | _ :: _ ->
                    Ppx_sexp_conv_lib.Conv_error.record_extra_fields _tp_loc
                      !extra sexp
                | [] -> (
                    match (!a_field, !b_field) with
                    | Some a_value, Some b_value ->
                        { a = a_value; b = b_value }
                    | _ ->
                        Ppx_sexp_conv_lib.Conv_error.record_undefined_elements
                          _tp_loc sexp
                          [ (Ppx_sexp_conv_lib.Conv.( = ) !a_field None, "a")
                          ; (Ppx_sexp_conv_lib.Conv.( = ) !b_field None, "b")
                          ] ) ) )
        | Ppx_sexp_conv_lib.Sexp.Atom _ as sexp ->
            Ppx_sexp_conv_lib.Conv_error.record_list_instead_atom _tp_loc sexp
        : Ppx_sexp_conv_lib.Sexp.t -> t )

    let _ = t_of_sexp

    let sexp_of_t =
      ( function
        | { a = v_a; b = v_b } ->
            let bnds = [] in
            let bnds =
              let arg = sexp_of_int v_b in
              Ppx_sexp_conv_lib.Sexp.List
                [ Ppx_sexp_conv_lib.Sexp.Atom "b"; arg ]
              :: bnds
            in
            let bnds =
              let arg = sexp_of_bool v_a in
              Ppx_sexp_conv_lib.Sexp.List
                [ Ppx_sexp_conv_lib.Sexp.Atom "a"; arg ]
              :: bnds
            in
            Ppx_sexp_conv_lib.Sexp.List bnds
        : t -> Ppx_sexp_conv_lib.Sexp.t )

    let _ = sexp_of_t

    let equal =
      ( fun a__003_ b__004_ ->
          if Ppx_compare_lib.phys_equal a__003_ b__004_ then true
          else
            Ppx_compare_lib.( && )
              (equal_bool a__003_.a b__004_.a)
              (equal_int a__003_.b b__004_.b)
        : t -> t -> bool )

    let _ = equal
  end
end

module M5 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = bool [@@deriving version { binable }]

        let _ = fun (_ : t) -> ()

        let version = 1

        let _ = version

        let _ = version

        let __versioned__ = ()

        let _ = __versioned__

        let to_latest = Fn.id

        module Arg = struct
          type nonrec t = t

          let to_binable = Fn.id

          let of_binable = Fn.id
        end

        include Binable.Of_binable (Core_kernel.Bool.Stable.V1) (Arg)

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:148:6" )
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
                   "test/versioned_module_good.ml:148:6" )
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
              "test/versioned_module_good.ml.M5.Stable.V1.With_version.t"
              !pos_ref

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

module M6 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = Bool.t [@@deriving bin_io, version { asserted }]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:172:6" )
              [ (Bin_prot.Shape.Tid.of_string "t", [], Bool.bin_shape_t) ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) = Bool.bin_size_t

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) = Bool.bin_write_t

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
          Bool.__bin_read_t__

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) = Bool.bin_read_t

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
                   "test/versioned_module_good.ml:172:6" )
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
                   "test/versioned_module_good.ml:172:6" )
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
              "test/versioned_module_good.ml.M6.Stable.V1.With_version.t"
              !pos_ref

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

module M7 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = M1.Stable.V3.t M2.Stable.V3.t [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:183:6" )
              [ ( Bin_prot.Shape.Tid.of_string "t"
                , []
                , M2.Stable.V3.bin_shape_t M1.Stable.V3.bin_shape_t )
              ]
          in
          (Bin_prot.Shape.top_app _group (Bin_prot.Shape.Tid.of_string "t")) []

        let _ = bin_shape_t

        let (bin_size_t : t Bin_prot.Size.sizer) =
         fun v -> M2.Stable.V3.bin_size_t M1.Stable.V3.bin_size_t v

        let _ = bin_size_t

        let (bin_write_t : t Bin_prot.Write.writer) =
         fun buf ~pos v ->
          (M2.Stable.V3.bin_write_t M1.Stable.V3.bin_write_t) buf ~pos v

        let _ = bin_write_t

        let bin_writer_t =
          { Bin_prot.Type_class.size = bin_size_t; write = bin_write_t }

        let _ = bin_writer_t

        let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
         fun buf ~pos_ref vint ->
          (M2.Stable.V3.__bin_read_t__ M1.Stable.V3.bin_read_t)
            buf ~pos_ref vint

        let _ = __bin_read_t__

        let (bin_read_t : t Bin_prot.Read.reader) =
         fun buf ~pos_ref ->
          (M2.Stable.V3.bin_read_t M1.Stable.V3.bin_read_t) buf ~pos_ref

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

        let _ = M2.Stable.V3.__versioned__

        let _ = M1.Stable.V3.__versioned__

        let to_latest = Fn.id

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:183:6" )
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
                   "test/versioned_module_good.ml:183:6" )
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
              "test/versioned_module_good.ml.M7.Stable.V1.With_version.t"
              !pos_ref

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

let () =
  let x : M7.Stable.V1.t = { a = 15; b = 20 } in
  let buf = Bigstring.create 20 in
  ignore (M7.Stable.V1.bin_write_t buf ~pos:0 x) ;
  let y : M7.Stable.V1.With_version.t =
    M7.Stable.V1.With_version.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (y.version = 1) ;
  assert (y.t = x) ;
  let z = M7.Stable.V1.bin_read_t buf ~pos_ref:(ref 0) in
  assert (z = x)

module M8 = struct
  include struct
    module Stable = struct
      module V1 = struct
        type t = int [@@deriving bin_io, version]

        let _ = fun (_ : t) -> ()

        let bin_shape_t =
          let _group =
            Bin_prot.Shape.group
              (Bin_prot.Shape.Location.of_string
                 "test/versioned_module_good.ml:211:6" )
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

        let some = 1

        let other = 2

        let things = 3

        let _ = (some, other, things)

        let to_latest = Fn.id

        module X = struct
          type t = bool
        end

        module type Y = sig
          type t
        end

        module F (X : Y) = struct
          type y = t

          include X
        end

        include (
          F
            (X) :
              sig
                type y = t
              end )

        module With_version = struct
          type typ = t [@@deriving bin_io]

          let _ = fun (_ : typ) -> ()

          let bin_shape_typ =
            let _group =
              Bin_prot.Shape.group
                (Bin_prot.Shape.Location.of_string
                   "test/versioned_module_good.ml:211:6" )
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
                   "test/versioned_module_good.ml:211:6" )
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
              "test/versioned_module_good.ml.M8.Stable.V1.With_version.t"
              !pos_ref

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

  module X = struct
    open Stable.V1

    let _ = (some, other, things)

    module X = X

    module type Y = Y

    module F = F

    type y = Stable.V1.y
  end
end
