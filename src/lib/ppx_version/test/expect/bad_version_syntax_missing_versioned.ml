[@@@ocaml.ppwarning "Versioned type must be in %%versioned extension"]
open Core_kernel
module Stable =
  struct
    module V1 =
      struct
        module T =
          struct
            type t = int[@@deriving (bin_io, version)]
            let _ = fun (_ : t) -> ()
            let bin_shape_t =
              let _group =
                Bin_prot.Shape.group
                  (Bin_prot.Shape.Location.of_string
                     "test/bad_version_syntax_missing_versioned.ml:8:6")
                  [((Bin_prot.Shape.Tid.of_string "t"), [], bin_shape_int)] in
              (Bin_prot.Shape.top_app _group
                 (Bin_prot.Shape.Tid.of_string "t")) []
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
          end
      end
  end
