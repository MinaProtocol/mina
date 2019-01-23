(* someday: optimization, the scalar here can be smaller than full width in our usecase. *)
type ('group, 'scalar) t = {h: 'group; s: 'scalar} [@@deriving bin_io]
