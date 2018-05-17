open Core_kernel

type 'a t =
  { data : 'a list
  ; count : int
  ; max_size : int
  }
[@@deriving bin_io]

include Container.Make(struct
  type nonrec 'a t = 'a t
  let fold t ~init ~f =
    List.fold t.data ~init ~f
  let iter = `Define_using_fold
end)

let empty ~max_size =
  { data = []
  ; count = 0
  ; max_size
  }

let add_all ({data ; count ; max_size} as c) xs =
  let len = List.length xs in
  assert (len < max_size);
  (* TODO: Use less appends *)
  if count < max_size-len then
    `Next { c with data = data @ xs ; count = count + len }
  else
    let (rest, spill) = List.split_n xs (max_size - count) in
    `Full (data @ rest, spill)

let add t x =
  add_all t [x]

let remaining_size {count;max_size} = max_size - count

let drain t = List.rev t.data

