include Core_kernel

module True = struct
  type t = True
end

module False = struct
  type t = False
end

type true_ = True.t

type false_ = False.t

type ('witness, 'b) t =
  | True : 'witness -> ('witness, true_) t
  | False : ('witness, false_) t

type 'witness true_t = ('witness, true_) t

type 'witness false_t = ('witness, false_) t
