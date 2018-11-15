let rec list_append l1 l2 =
  match l1 with
    [] -> l2
  | hd :: tl -> hd :: (list_append tl l2)

type fmt = CamlinternalFormatBasics.fmt = Fmt

module List = Stdlib__List
