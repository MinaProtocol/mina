open Core_kernel

module Make (M : sig
  type t = Int.t [@@deriving version { unnumbered }]
end) =
struct
  (* unnumbered option means M.version doesn't exist *)
  let x = M.version
end
