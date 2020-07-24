(* list_with_length.ml -- list type with Bin_prot serialization
   if the list is too long, then `bin_read_t` fails
   (Bin_prot v14 has read_list_with_max_len)
*)

open Core_kernel

module Make (Len : sig
  val max_length : int
end) =
struct
  type 'a t = 'a list [@@deriving bin_io_unversioned]

  let bin_read_t a_reader buf ~pos_ref =
    let len = (Bin_prot.Read.bin_read_nat0 buf ~pos_ref :> int) in
    if Int.( > ) len Len.max_length then
      failwithf "List_with_length: list length=%d exceeds max_length=%d" len
        Len.max_length () ;
    bin_read_t a_reader buf ~pos_ref
end
