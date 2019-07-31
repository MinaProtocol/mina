type true_

type false_

type ('witness, _) t =
  | True : 'witness -> ('witness, true_) t
  | False : ('witness, false_) t

type 'witness true_t = ('witness, true_) t

type 'witness false_t = ('witness, false_) t
