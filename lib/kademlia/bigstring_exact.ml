open Core_kernel

(* Like a bigstring, but with a fixed size. Now, we can omit
 * the header info in the serialization *)

module Make (Size : sig val size: int end) = struct
  type t = Bigstring.t [@@deriving sexp]

  let zeros () = Bigstring.init Size.size ~f:(fun _ -> Char.of_int_exn 0)

  let create () = Bigstring.create Size.size

  let init ~f = Bigstring.init Size.size ~f

  let bin_read_t buf ~pos_ref =
    let bs = create () in
    Bin_prot.Common.blit_buf ?src_pos:(Some !pos_ref) ~src:buf ~dst:bs Size.size;
    pos_ref := (!pos_ref) + Size.size;
    bs

  let bin_size_t a = Size.size

  let bin_write_t buf ~pos a =
    Bin_prot.Common.blit_buf ~src:a ?dst_pos:(Some pos) ~dst:buf Size.size;
    pos + Size.size

  let bin_shape_t = Bin_prot.Shape.(basetype (Uuid.of_string (Printf.sprintf "Bigstring%d" Size.size))) []
end

let%test_module "bigstring_exact" = (module struct
  module Bigstring6 = Make(struct let size = 6 end)
  module Bigstring3 = Make(struct let size = 3 end)

  type t =
    { six : Bigstring6.t
    ; three : Bigstring3.t
    }
  [@@deriving bin_io]

  let%test "serializes_compactly" =
    let t = { six = Bigstring.of_string "aaaaaa" ; three = Bigstring.of_string "zzz" } in
    assert (Bigstring.length t.six = 6);
    assert (Bigstring.length t.three = 3);
    let bs = Bigstring.init 9 ~f:(fun _ -> Char.of_int_exn 0) in
    let _ = bin_write_t bs ~pos:0 t in
    (Bigstring.to_string bs) = "aaaaaazzz"
end)

