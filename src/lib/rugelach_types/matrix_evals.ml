module H_list = Snarky.H_list

type 'a t = {row: 'a; col: 'a; value: 'a; rc: 'a} [@@deriving bin_io, sexp]

let to_hlist {row; col; value; rc} = H_list.[row; col; value; rc]

let of_hlist ([row; col; value; rc] : (unit, _) H_list.t) =
  {row; col; value; rc}

let typ g =
  Snarky.Typ.of_hlistable [g; g; g; g] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let map {row; col; value; rc} ~f =
  {row= f row; col= f col; value= f value; rc= f rc}
