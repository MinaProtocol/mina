open Base

module Make2
    (M : Monad.S2) (T : sig
        type t
    end) : Monad.S with type 'a t = ('a, T.t) M.t = struct
  type 'a t = ('a, T.t) M.t

  let map = M.map

  let bind = M.bind

  let return = M.return

  let all = M.all

  let all_ignore = M.all_unit

  let all_unit = M.all_unit

  let ignore_m = M.ignore_m

  let join = M.join

  module Let_syntax = M.Let_syntax
  module Monad_infix = M.Monad_infix
  include Monad_infix
end

module Make3
    (M : Monad.S3) (T : sig
        type t1

        type t2
    end) : Monad.S with type 'a t = ('a, T.t1, T.t2) M.t = struct
  type 'a t = ('a, T.t1, T.t2) M.t

  let map = M.map

  let bind = M.bind

  let return = M.return

  let all = M.all

  let all_ignore = M.all_unit

  let all_unit = M.all_unit

  let ignore_m = M.ignore_m

  let join = M.join

  module Let_syntax = M.Let_syntax
  module Monad_infix = M.Monad_infix
  include Monad_infix
end
