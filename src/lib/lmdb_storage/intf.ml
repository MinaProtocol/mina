module Db (T : sig
  type ('k, 'v) t
end) =
struct
  type ('k, 'v) t = ('k, 'v) T.t

  type creator =
    { create :
        'k 'v. ?name:string -> 'k Lmdb.Conv.t -> 'v Lmdb.Conv.t -> ('k, 'v) t
    }

  type getter =
    { get : 'k 'v. ('k, 'v) t -> 'k -> 'v option
    ; iter_ro :
        'k 'v. f:('k -> 'v -> [ `Continue | `Stop ]) -> ('k, 'v) t -> unit
    }

  type setter =
    { set : 'k 'v. ('k, 'v) t -> 'k -> 'v -> unit
    ; iter_rw :
        'k 'v.
           f:
             (   'k
              -> 'v
              -> [ `Continue
                 | `Stop
                 | `Remove_continue
                 | `Remove_stop
                 | `Update_continue of 'v
                 | `Update_stop of 'v ] )
        -> ('k, 'v) t
        -> unit
    }
end
