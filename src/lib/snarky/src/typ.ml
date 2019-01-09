open Core_kernel

type ('var, 'value, 'field, 'cvar, 'sys) t =
  ('var, 'value, 'field, 'cvar, 'sys) Types.Typ.t

type ('var, 'value, 'field, 'cvar, 'sys) typ =
  ('var, 'value, 'field, 'cvar, 'sys) t

module T = struct
  open Types.Typ
  open Typ_monads

  let store ({store; _} : ('var, 'value, 'field, 'cvar, 'sys) t) (x : 'value) :
      ('var, 'field, 'cvar) Store.t =
    store x

  let read ({read; _} : ('var, 'value, 'field, 'cvar, 'sys) t) (v : 'var) :
      ('value, 'field, 'cvar) Read.t =
    read v

  let alloc ({alloc; _} : ('var, 'value, 'field, 'cvar, 'sys) t) :
      ('var, 'cvar) Alloc.t =
    alloc

  let check (type field cvar)
      ({check; _} : ('var, 'value, field, cvar, 'sys) t) (v : 'var) :
      (unit, 's, field, cvar, 'sys) Types.Checked.t =
    let do_nothing : (unit, cvar -> field, _) As_prover0.t =
     fun _ s -> (s, ())
    in
    With_state (do_nothing, (fun () -> do_nothing), check v, Checked.return)

  let unit () : (unit, unit, 'field, 'cvar, 'sys) t =
    let s = Store.return () in
    let r = Read.return () in
    let c = Checked.return () in
    { store= (fun () -> s)
    ; read= (fun () -> r)
    ; check= (fun () -> c)
    ; alloc= Alloc.return () }

  let field () : ('cvar, 'field, 'field, 'cvar, 'sys) t =
    { store= Store.store
    ; read= Read.read
    ; alloc= Alloc.alloc
    ; check= (fun _ -> Checked.return ()) }

  let transport
      ({read; store; alloc; check} : ('var1, 'value1, 'field, 'cvar, 'sys) t)
      ~(there : 'value2 -> 'value1) ~(back : 'value1 -> 'value2) :
      ('var1, 'value2, 'field, 'cvar, 'sys) t =
    { alloc
    ; store= (fun x -> store (there x))
    ; read= (fun v -> Read.map ~f:back (read v))
    ; check }

  let transport_var
      ({read; store; alloc; check} : ('var1, 'value, 'field, 'cvar, 'sys) t)
      ~(there : 'var2 -> 'var1) ~(back : 'var1 -> 'var2) :
      ('var2, 'value, 'field, 'cvar, 'sys) t =
    { alloc= Alloc.map alloc ~f:back
    ; store= (fun x -> Store.map (store x) ~f:back)
    ; read= (fun x -> read (there x))
    ; check= (fun x -> check (there x)) }

  let list ~length
      ({read; store; alloc; check} :
        ('elt_var, 'elt_value, 'field, 'cvar, 'sys) t) :
      ('elt_var list, 'elt_value list, 'field, 'cvar, 'sys) t =
    let store ts =
      let n = List.length ts in
      if n <> length then
        failwithf "Typ.list: Expected length %d, got %d" length n () ;
      Store.all (List.map ~f:store ts)
    in
    let alloc = Alloc.all (List.init length ~f:(fun _ -> alloc)) in
    let check ts = Checked.all_unit (List.map ts ~f:check) in
    let read vs = Read.all (List.map vs ~f:read) in
    {read; store; alloc; check}

  (* TODO-someday: Make more efficient *)
  let array ~length
      ({read; store; alloc; check} :
        ('elt_var, 'elt_value, 'field, 'cvar, 'sys) t) :
      ('elt_var array, 'elt_value array, 'field, 'cvar, 'sys) t =
    let store ts =
      assert (Array.length ts = length) ;
      Store.map ~f:Array.of_list
        (Store.all (List.map ~f:store (Array.to_list ts)))
    in
    let alloc =
      let open Alloc.Let_syntax in
      let%map vs = Alloc.all (List.init length ~f:(fun _ -> alloc)) in
      Array.of_list vs
    in
    let read vs =
      assert (Array.length vs = length) ;
      Read.map ~f:Array.of_list
        (Read.all (List.map ~f:read (Array.to_list vs)))
    in
    let check ts =
      assert (Array.length ts = length) ;
      let open Checked in
      let rec go i =
        if i = length then return ()
        else
          let%map () = check ts.(i) and () = go (i + 1) in
          ()
      in
      go 0
    in
    {read; store; alloc; check}

  let tuple2 (typ1 : ('var1, 'value1, 'field, 'cvar, 'sys) t)
      (typ2 : ('var2, 'value2, 'field, 'cvar, 'sys) t) :
      ('var1 * 'var2, 'value1 * 'value2, 'field, 'cvar, 'sys) t =
    let alloc =
      let open Alloc.Let_syntax in
      let%map x = typ1.alloc and y = typ2.alloc in
      (x, y)
    in
    let read (x, y) =
      let open Read.Let_syntax in
      let%map x = typ1.read x and y = typ2.read y in
      (x, y)
    in
    let store (x, y) =
      let open Store.Let_syntax in
      let%map x = typ1.store x and y = typ2.store y in
      (x, y)
    in
    let check (x, y) =
      let open Checked in
      let%map () = typ1.check x and () = typ2.check y in
      ()
    in
    {read; store; alloc; check}

  let ( * ) = tuple2

  let tuple3 (typ1 : ('var1, 'value1, 'field, 'cvar, 'sys) t)
      (typ2 : ('var2, 'value2, 'field, 'cvar, 'sys) t)
      (typ3 : ('var3, 'value3, 'field, 'cvar, 'sys) t) :
      ( 'var1 * 'var2 * 'var3
      , 'value1 * 'value2 * 'value3
      , 'field
      , 'cvar
      , 'sys )
      t =
    let alloc =
      let open Alloc.Let_syntax in
      let%map x = typ1.alloc and y = typ2.alloc and z = typ3.alloc in
      (x, y, z)
    in
    let read (x, y, z) =
      let open Read.Let_syntax in
      let%map x = typ1.read x and y = typ2.read y and z = typ3.read z in
      (x, y, z)
    in
    let store (x, y, z) =
      let open Store.Let_syntax in
      let%map x = typ1.store x and y = typ2.store y and z = typ3.store z in
      (x, y, z)
    in
    let check (x, y, z) =
      let open Checked in
      let%map () = typ1.check x and () = typ2.check y and () = typ3.check z in
      ()
    in
    {read; store; alloc; check}
end

include T
