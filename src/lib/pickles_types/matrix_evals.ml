module H_list = Snarky.H_list
open H_list

type 'a t = {row: 'a; col: 'a; value: 'a}

let to_hlist {row; col; value} = [row; col; value]

let of_hlist ([row; col; value] : (unit, _) H_list.t) = {row; col; value}

let typ g =
  Snarky.Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let map {row; col; value} ~f = {row= f row; col= f col; value= f value}
