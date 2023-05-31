[@@@ocaml.ppwarning "Cannot use versioned extension within a functor body"]
open Core_kernel
module Functor(X:sig  end)(Y:sig val _y : int end) =
  struct
    include
      struct
        module Stable =
          struct
            module V1 =
              struct
                type t = string[@@deriving (bin_io, version, bin_io)]
                let _ = fun (_ : t) -> ()
                let bin_shape_t =
                  let _group =
                    Bin_prot.Shape.group
                      (Bin_prot.Shape.Location.of_string
                         "test/bad_versioned_in_nested_functor.ml:12:6")
                      [((Bin_prot.Shape.Tid.of_string "t"), [],
                         bin_shape_string)] in
                  (Bin_prot.Shape.top_app _group
                     (Bin_prot.Shape.Tid.of_string "t")) []
                let _ = bin_shape_t
                let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_string
                let _ = bin_size_t
                let (bin_write_t : t Bin_prot.Write.writer) =
                  bin_write_string
                let _ = bin_write_t
                let bin_writer_t =
                  {
                    Bin_prot.Type_class.size = bin_size_t;
                    write = bin_write_t
                  }
                let _ = bin_writer_t
                let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
                  __bin_read_string__
                let _ = __bin_read_t__
                let (bin_read_t : t Bin_prot.Read.reader) = bin_read_string
                let _ = bin_read_t
                let bin_reader_t =
                  {
                    Bin_prot.Type_class.read = bin_read_t;
                    vtag_read = __bin_read_t__
                  }
                let _ = bin_reader_t
                let bin_t =
                  {
                    Bin_prot.Type_class.writer = bin_writer_t;
                    reader = bin_reader_t;
                    shape = bin_shape_t
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
                      (Bin_prot.Shape.Location.of_string
                         "test/bad_versioned_in_nested_functor.ml:12:6")
                      [((Bin_prot.Shape.Tid.of_string "t"), [],
                         bin_shape_string)] in
                  (Bin_prot.Shape.top_app _group
                     (Bin_prot.Shape.Tid.of_string "t")) []
                let _ = bin_shape_t
                let (bin_size_t : t Bin_prot.Size.sizer) = bin_size_string
                let _ = bin_size_t
                let (bin_write_t : t Bin_prot.Write.writer) =
                  bin_write_string
                let _ = bin_write_t
                let bin_writer_t =
                  {
                    Bin_prot.Type_class.size = bin_size_t;
                    write = bin_write_t
                  }
                let _ = bin_writer_t
                let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
                  __bin_read_string__
                let _ = __bin_read_t__
                let (bin_read_t : t Bin_prot.Read.reader) = bin_read_string
                let _ = bin_read_t
                let bin_reader_t =
                  {
                    Bin_prot.Type_class.read = bin_read_t;
                    vtag_read = __bin_read_t__
                  }
                let _ = bin_reader_t
                let bin_t =
                  {
                    Bin_prot.Type_class.writer = bin_writer_t;
                    reader = bin_reader_t;
                    shape = bin_shape_t
                  }
                let _ = bin_t
                let to_latest = Fn.id
                module With_version =
                  struct
                    type typ = t[@@deriving bin_io]
                    let _ = fun (_ : typ) -> ()
                    let bin_shape_typ =
                      let _group =
                        Bin_prot.Shape.group
                          (Bin_prot.Shape.Location.of_string
                             "test/bad_versioned_in_nested_functor.ml:12:6")
                          [((Bin_prot.Shape.Tid.of_string "typ"), [],
                             bin_shape_t)] in
                      (Bin_prot.Shape.top_app _group
                         (Bin_prot.Shape.Tid.of_string "typ")) []
                    let _ = bin_shape_typ
                    let (bin_size_typ : typ Bin_prot.Size.sizer) = bin_size_t
                    let _ = bin_size_typ
                    let (bin_write_typ : typ Bin_prot.Write.writer) =
                      bin_write_t
                    let _ = bin_write_typ
                    let bin_writer_typ =
                      {
                        Bin_prot.Type_class.size = bin_size_typ;
                        write = bin_write_typ
                      }
                    let _ = bin_writer_typ
                    let (__bin_read_typ__ :
                      (int -> typ) Bin_prot.Read.reader) = __bin_read_t__
                    let _ = __bin_read_typ__
                    let (bin_read_typ : typ Bin_prot.Read.reader) =
                      bin_read_t
                    let _ = bin_read_typ
                    let bin_reader_typ =
                      {
                        Bin_prot.Type_class.read = bin_read_typ;
                        vtag_read = __bin_read_typ__
                      }
                    let _ = bin_reader_typ
                    let bin_typ =
                      {
                        Bin_prot.Type_class.writer = bin_writer_typ;
                        reader = bin_reader_typ;
                        shape = bin_shape_typ
                      }
                    let _ = bin_typ
                    type t = {
                      version: int ;
                      t: typ }[@@deriving bin_io]
                    let _ = fun (_ : t) -> ()
                    let bin_shape_t =
                      let _group =
                        Bin_prot.Shape.group
                          (Bin_prot.Shape.Location.of_string
                             "test/bad_versioned_in_nested_functor.ml:12:6")
                          [((Bin_prot.Shape.Tid.of_string "t"), [],
                             (Bin_prot.Shape.record
                                [("version", bin_shape_int);
                                ("t", bin_shape_typ)]))] in
                      (Bin_prot.Shape.top_app _group
                         (Bin_prot.Shape.Tid.of_string "t")) []
                    let _ = bin_shape_t
                    let (bin_size_t : t Bin_prot.Size.sizer) =
                      function
                      | { version = v1; t = v2 } ->
                          let size = 0 in
                          let size =
                            Bin_prot.Common.(+) size (bin_size_int v1) in
                          Bin_prot.Common.(+) size (bin_size_typ v2)
                    let _ = bin_size_t
                    let (bin_write_t : t Bin_prot.Write.writer) =
                      fun buf ->
                        fun ~pos ->
                          function
                          | { version = v1; t = v2 } ->
                              let pos = bin_write_int buf ~pos v1 in
                              bin_write_typ buf ~pos v2
                    let _ = bin_write_t
                    let bin_writer_t =
                      {
                        Bin_prot.Type_class.size = bin_size_t;
                        write = bin_write_t
                      }
                    let _ = bin_writer_t
                    let (__bin_read_t__ : (int -> t) Bin_prot.Read.reader) =
                      fun _buf ->
                        fun ~pos_ref ->
                          fun _vint ->
                            Bin_prot.Common.raise_variant_wrong_type
                              "test/bad_versioned_in_nested_functor.ml.Functor.Stable.V1.With_version.t"
                              (!pos_ref)
                    let _ = __bin_read_t__
                    let (bin_read_t : t Bin_prot.Read.reader) =
                      fun buf ->
                        fun ~pos_ref ->
                          let v_version = bin_read_int buf ~pos_ref in
                          let v_t = bin_read_typ buf ~pos_ref in
                          { version = v_version; t = v_t }
                    let _ = bin_read_t
                    let bin_reader_t =
                      {
                        Bin_prot.Type_class.read = bin_read_t;
                        vtag_read = __bin_read_t__
                      }
                    let _ = bin_reader_t
                    let bin_t =
                      {
                        Bin_prot.Type_class.writer = bin_writer_t;
                        reader = bin_reader_t;
                        shape = bin_shape_t
                      }
                    let _ = bin_t
                    let create t = { t; version = 1 }
                  end
                let bin_read_t buf ~pos_ref  =
                  let With_version.{ version = read_version; t }  =
                    With_version.bin_read_t buf ~pos_ref in
                  if not (Core_kernel.Int.equal read_version version)
                  then
                    failwith
                      (Core_kernel.sprintf
                         "bin_read_t: version read %d does not match expected version %d"
                         read_version version);
                  t
                let __bin_read_t__ buf ~pos_ref  i =
                  let With_version.{ version = read_version; t }  =
                    With_version.__bin_read_t__ buf ~pos_ref i in
                  if not (Core_kernel.Int.equal read_version version)
                  then
                    failwith
                      (Core_kernel.sprintf
                         "__bin_read_t__: version read %d does not match expected version %d"
                         read_version version);
                  t
                let bin_size_t t =
                  With_version.bin_size_t (With_version.create t)
                let bin_write_t buf ~pos  t =
                  With_version.bin_write_t buf ~pos (With_version.create t)
                let bin_shape_t = With_version.bin_shape_t
                let bin_reader_t =
                  {
                    Bin_prot.Type_class.read = bin_read_t;
                    vtag_read = __bin_read_t__
                  }
                let bin_writer_t =
                  {
                    Bin_prot.Type_class.size = bin_size_t;
                    write = bin_write_t
                  }
                let bin_t =
                  {
                    Bin_prot.Type_class.shape = bin_shape_t;
                    writer = bin_writer_t;
                    reader = bin_reader_t
                  }
                let _ =
                  (bin_read_t, __bin_read_t__, bin_size_t, bin_write_t,
                    bin_shape_t, bin_reader_t, bin_writer_t, bin_t)
              end
            module Latest = V1
            let (versions :
              (int *
                (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
                array)
              =
              [|(1,
                  ((fun buf ->
                      fun ~pos_ref ->
                        V1.to_latest (V1.bin_read_t buf ~pos_ref))))|]
            let bin_read_to_latest_opt buf ~pos_ref  =
              let open Core_kernel in
                let saved_pos = !pos_ref in
                let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
                let pos_ref = ref saved_pos in
                Array.find_map versions
                  ~f:(fun (i, f) ->
                        if Int.equal i version
                        then Some (f buf ~pos_ref)
                        else None)[@@ocaml.doc
                                    " deserializes data to the latest module version's type "]
            let _ = bin_read_to_latest_opt
          end
        type t = Stable.Latest.t
      end
  end
