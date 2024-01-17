module Length = struct
  type 'a t = ('a list, int) Sigs.predicate2

  let equal l len = Caml.List.compare_length_with l len = 0

  let unequal l len = Caml.List.compare_length_with l len <> 0

  let gte l len = Caml.List.compare_length_with l len >= 0

  let gt l len = Caml.List.compare_length_with l len > 0

  let lte l len = Caml.List.compare_length_with l len <= 0

  let lt l len = Caml.List.compare_length_with l len < 0

  module Compare = struct
    let ( = ) = equal

    let ( <> ) = unequal

    let ( >= ) = gte

    let ( > ) = gt

    let ( <= ) = lte

    let ( < ) = lt
  end
end
