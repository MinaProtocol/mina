include sig
  [@@@warning "-33"]
  (* This open is unused with OCaml >= 4.03 since the stdlib defines a
     result type *)
  open Result_compat
  open Pervasives

  (** The result type.

      It is equal to the result type defined by the standard library
      for OCaml >= 4.03.  *)
  type ('a, 'error) t = ('a, 'error) result =
    | Ok    of 'a
    | Error of 'error
end

type ('a, 'error) result = ('a, 'error) t
