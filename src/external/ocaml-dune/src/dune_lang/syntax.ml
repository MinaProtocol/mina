type t = Jbuild | Dune

let of_basename = function
  | "jbuild" -> Some Jbuild
  | "dune" -> Some Dune
  | _ -> None
