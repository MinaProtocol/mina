open Core_kernel
open Core_kernel.Hash.Builtin

module N16 = struct
  let max_array_len = 16
end

module N4000 = struct
  let max_array_len = 4000
end

module ArrayN (N : sig
  val max_array_len : int
end) =
struct
  module Stable = struct
    module V1 = struct
      type 'a t = 'a array [@@deriving sexp, yojson, bin_io]

      let path_to_type =
        let module_path =
          Core_kernel.String.chop_suffix_if_exists ~suffix:".path_to_type"
            __FUNCTION__
        in
        sprintf "%s:%s.%s" __FILE__ module_path "t"

      let __versioned__ = ()

      let hash_fold_t = hash_fold_array_frozen

      [%%define_locally Core_kernel.Array.(compare, equal)]

      let to_latest s = s

      let bin_shape_t bin_shape_elt =
        Bin_prot.Shape.basetype
          (Bin_prot.Shape.Uuid.of_string "Bounded_types.Array.t")
          [ bin_shape_elt ]

      let bin_write_t bin_write_el buf ~pos a =
        if Array.length a > N.max_array_len then
          failwithf "Exceeded array maximum size (max %d < got %d)"
            N.max_array_len (Array.length a) () ;
        bin_write_array bin_write_el buf ~pos a

      let bin_read_t bin_read_el buf ~pos_ref =
        let pos = !pos_ref in
        let len = (Bin_prot.Read.bin_read_nat0 buf ~pos_ref :> int) in
        if len > N.max_array_len then
          Bin_prot.Common.raise_read_error
            Bin_prot.Common.ReadError.Array_too_long !pos_ref
        else (
          pos_ref := pos ;
          bin_read_array bin_read_el buf ~pos_ref )

      let (_ : _) =
        Ppx_version_runtime.Contained_types.register ~path_to_type
          ~contained_type_paths:[]

      (* no shape to register, there's a type parameter *)
    end
  end

  type 'a t = 'a Stable.V1.t

  [%%define_locally
  Stable.V1.
    (compare, equal, hash_fold_t, sexp_of_t, t_of_sexp, to_yojson, of_yojson)]
end

module String = struct
  let max_string_len = 100_000_000

  module Stable = struct
    module V1 = struct
      type t = string [@@deriving sexp, yojson, bin_io]

      let __versioned__ = ()

      let to_latest s = s

      [%%define_locally Core_kernel.String.(compare, equal)]

      let hash = hash_string

      let hash_fold_t = hash_fold_string

      let bin_shape_t =
        Bin_prot.Shape.basetype
          (Bin_prot.Shape.Uuid.of_string "Bounded_types.String.t")
          []

      let bin_write_t buf ~pos s =
        if String.length s > max_string_len then
          failwith "Exceeded string maximum size" ;
        bin_write_string buf ~pos s

      let bin_read_t buf ~pos_ref =
        let pos = !pos_ref in
        let len = (Bin_prot.Read.bin_read_nat0 buf ~pos_ref :> int) in
        if len > max_string_len then
          Bin_prot.Common.raise_read_error
            Bin_prot.Common.ReadError.Array_too_long !pos_ref
        else (
          pos_ref := pos ;
          bin_read_string buf ~pos_ref )

      let path_to_type =
        let module_path =
          Core_kernel.String.chop_suffix_if_exists ~suffix:".path_to_type"
            __FUNCTION__
        in
        sprintf "%s:%s.%s" __FILE__ module_path "t"

      let (_ : _) =
        Ppx_version_runtime.Contained_types.register ~path_to_type
          ~contained_type_paths:[]

      let (_ : _) =
        Ppx_version_runtime.Shapes.register ~path_to_type
          ~type_shape:bin_shape_t ~type_decl:"string"
    end
  end

  type t = Stable.V1.t

  [%%define_locally
  Stable.V1.
    ( compare
    , equal
    , hash
    , hash_fold_t
    , sexp_of_t
    , t_of_sexp
    , to_yojson
    , of_yojson )]

  module Tagged = struct
    module Stable = struct
      module V1 = struct
        include Stable.V1

        (* because this is replacing a primitive,
           there is no actual version tag handling
           needed (and in fact, that will make a
           test in transaction fail *)
        module With_all_version_tags = Stable.V1
      end
    end
  end

  module Of_stringable (M : Stringable.S) =
  Bin_prot.Utils.Make_binable_without_uuid (struct
    module Binable = Stable.V1

    type t = M.t

    let to_binable = M.to_string

    (* Wrap exception for improved diagnostics. *)
    exception Of_binable of string * exn [@@deriving sexp]

    let of_binable s = try M.of_string s with x -> raise (Of_binable (s, x))
  end)
end

module Wrapped_error = struct
  module Stable = struct
    module V1 = struct
      type t = Core_kernel.Error.Stable.V2.t [@@deriving sexp]

      let __versioned__ = ()

      let path_to_type =
        let module_path =
          Core_kernel.String.chop_suffix_if_exists ~suffix:".path_to_type"
            __FUNCTION__
        in
        sprintf "%s:%s.%s" __FILE__ module_path "t"

      let to_latest = Core_kernel.Fn.id

      include String.Of_stringable (struct
        type nonrec t = t

        let to_string (s : t) =
          Core_kernel.Error.sexp_of_t s |> Core_kernel.Sexp.to_string_mach

        let of_string s =
          Core_kernel.Error.t_of_sexp (Core_kernel.Sexp.of_string s)
      end)

      let (_ : _) =
        Ppx_version_runtime.Contained_types.register ~path_to_type
          ~contained_type_paths:[]

      let (_ : _) =
        Ppx_version_runtime.Shapes.register ~path_to_type
          ~type_shape:bin_shape_t ~type_decl:"Core_kernel.Error.Stable.V2.t"
    end
  end

  type t = Stable.V1.t
end

module ArrayN16 = ArrayN (N16)
module ArrayN4000 = ArrayN (N4000)
