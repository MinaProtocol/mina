open Core_kernel

module Partial = struct
  (*
  module Bin_io (M : Intf.Bin_io_intf) : Intf.Partial.Yojson_intf with type t := M.t = struct
    let bin_size_t = M.bin_size_t
    let bin_write_t = M.bin_write_t
    let bin_read_t = ...
    let bin_shape_t = M.bin_shape_t
    let bin_reader_t = ...
    let bin_t = ...
  end
  *)

  module Sexp (M : Intf.Input.Sexp_intf) :
    Intf.Partial.Sexp_intf with type t := M.t = struct
    let sexp_of_t = M.sexp_of_t

    let t_of_sexp t = Table.attach_finalizer M.id (M.t_of_sexp t)
  end

  module Yojson (M : Intf.Input.Yojson_intf) :
    Intf.Partial.Yojson_intf with type t := M.t = struct
    let to_yojson = M.to_yojson

    let of_yojson json =
      M.of_yojson json |> Result.map ~f:(Table.attach_finalizer M.id)
  end
end

module Basic (M : Intf.Input.Basic_intf) :
  Intf.Output.Basic_intf with type t = M.t and type 'a creator := 'a M.creator =
struct
  type t = M.t

  let create = M.map_creator M.create ~f:(Table.attach_finalizer M.id)
end

(*
module Bin_io (M : Intf.Bin_io_intf) : Intf.Bin_io_intf with type t = M.t and type create_args := M.create_args = struct
  include Basic (M)
  include Partial.Bin_io (M)
end
*)

module Sexp (M : Intf.Input.Sexp_intf) :
  Intf.Output.Sexp_intf with type t = M.t and type 'a creator := 'a M.creator =
struct
  include Basic (M)
  include Partial.Sexp (M)
end

module Yojson (M : Intf.Input.Yojson_intf) :
  Intf.Output.Yojson_intf with type t = M.t and type 'a creator := 'a M.creator =
struct
  include Basic (M)
  include Partial.Yojson (M)
end

(*
module Full (M : Intf.Input.Full_intf) : Intf.Ouptut.Full_intf with type t = M.t and type create_args := M.create_args = struct
  include Basic (M)
  include Partial.Bin_io (M)
  include Partial.Sexp (M)
  include Partial.Yojson (M)
end
*)
