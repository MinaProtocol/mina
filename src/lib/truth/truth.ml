type true_ = unit

type false_ = unit

type ('witness, _) with_witness =
  | True : 'witness -> ('witness, true_) with_witness
  | False : ('witness, false_) with_witness

type 'a t = (unit, 'a) with_witness

type true_t = true_ t

type false_t = false_ t
