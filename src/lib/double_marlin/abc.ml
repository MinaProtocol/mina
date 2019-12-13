open Import
open H_list

type 'a t = {a: 'a; b: 'a; c: 'a} [@@deriving fields]

let to_hlist {a; b; c} = [a; b; c]

let of_hlist ([a; b; c] : (unit, _) H_list.t) = {a; b; c}

let typ g =
  Snarky.Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
