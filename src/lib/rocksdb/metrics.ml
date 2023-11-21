open Core_kernel

type gauge = { hits : int; time_spent : Time_ns.Span.t }
[@@deriving sexp, fields]

let empty_gauge = { hits = 0; time_spent = Time_ns.Span.zero }

type t =
  { get : gauge ref
  ; get_batch : gauge ref
  ; set : gauge ref
  ; set_batch : gauge ref
  ; with_batch : gauge ref
  ; remove : gauge ref
  ; checkpoint_create : gauge ref
  ; to_alist : gauge ref
  }
[@@deriving sexp, fields]

let to_string
    { get
    ; get_batch
    ; set
    ; set_batch
    ; with_batch
    ; remove
    ; checkpoint_create
    ; to_alist
    } =
  sprintf
    "( get: %d/%s, get_batch: %d/%s, set: %d/%s, set_batch: %d/%s, with_batch: \
     %d/%s, remove: %d/%s, checkpoint_create: %d/%s, to_alist: %d/%s )"
    !get.hits
    (Time_ns.Span.to_string_hum !get.time_spent)
    !get_batch.hits
    (Time_ns.Span.to_string_hum !get_batch.time_spent)
    !set.hits
    (Time_ns.Span.to_string_hum !set.time_spent)
    !set_batch.hits
    (Time_ns.Span.to_string_hum !set_batch.time_spent)
    !with_batch.hits
    (Time_ns.Span.to_string_hum !with_batch.time_spent)
    !remove.hits
    (Time_ns.Span.to_string_hum !remove.time_spent)
    !checkpoint_create.hits
    (Time_ns.Span.to_string_hum !checkpoint_create.time_spent)
    !to_alist.hits
    (Time_ns.Span.to_string_hum !to_alist.time_spent)

let create () =
  { get = ref empty_gauge
  ; get_batch = ref empty_gauge
  ; set = ref empty_gauge
  ; set_batch = ref empty_gauge
  ; with_batch = ref empty_gauge
  ; remove = ref empty_gauge
  ; checkpoint_create = ref empty_gauge
  ; to_alist = ref empty_gauge
  }

let wrap ~f t field =
  let gauge = field t in
  let start = Time_ns.now () in
  let res = f () in
  let span = Time_ns.(diff (now ()) start) in
  gauge :=
    { hits = !gauge.hits + 1
    ; time_spent = Time_ns.Span.(!gauge.time_spent + span)
    } ;
  res

let reset
    { get
    ; get_batch
    ; set
    ; set_batch
    ; with_batch
    ; remove
    ; checkpoint_create
    ; to_alist
    } =
  get := empty_gauge ;
  get_batch := empty_gauge ;
  set := empty_gauge ;
  set_batch := empty_gauge ;
  with_batch := empty_gauge ;
  remove := empty_gauge ;
  checkpoint_create := empty_gauge ;
  to_alist := empty_gauge
