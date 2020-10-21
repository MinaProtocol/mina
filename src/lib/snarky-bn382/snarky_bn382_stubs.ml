module Ignored = struct
  (* Statically link the symbols at the library level. *)
  external name : unit -> unit = "zexe_bn382_fp_size_in_bits"

  let name () = ()
end
[@@warning "-32"]

let linkme () = ()
