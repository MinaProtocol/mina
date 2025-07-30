module True : sig
  type t = True
end

module False : sig
  type t = False
end

type true_ = True.t

type false_ = False.t

type ('witness, 'b) t =
  | True : 'witness -> ('witness, True.t) t
  | False : ('witness, False.t) t

type 'witness true_t = ('witness, true_) t

type 'witness false_t = ('witness, false_) t
