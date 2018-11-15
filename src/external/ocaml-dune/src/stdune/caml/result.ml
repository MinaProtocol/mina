include struct
  [@@@warning "-33"]
  open Result_compat
  open Pervasives

  type ('a, 'error) t = ('a, 'error) result =
    | Ok    of 'a
    | Error of 'error
end

type ('a, 'error) result = ('a, 'error) t
