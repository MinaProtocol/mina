open Core_kernel
open Snarky
module Impl = Snark.Make (Backends.Bn128)
open Impl
open Let_syntax

(* Look at this beautifully secure hash function *)
module Hash = struct
  type t = Field.t [@@deriving sexp]

  type var = Field.var

  let typ = Field.typ

  let hash x = x

  let inv2 x = Field.(sub (of_int 0) x)

  let empty = inv2 Field.(of_int 5000)

  let combine x y = Field.add (inv2 x) (inv2 y)

  module Checked = struct
    let empty = Field.Checked.constant empty

    let hash x = x

    let inv2 x = Field.Checked.(sub Field.(of_int 0 |> constant) x)

    let combine x y = Field.Checked.add (inv2 x) (inv2 y)
  end
end

module Merkle_stack = struct
  type t = Hash.t * (Hash.t * Field.t) list [@@deriving sexp]

  let empty = (Hash.empty, [])

  let push t x =
    let hx = Hash.hash x in
    let h, old = t in
    let new_hash = Hash.combine h hx in
    (new_hash, (h, x) :: old)

  let pop_exn t : Field.t * t =
    let h, xs = t in
    let h', x = List.hd_exn xs in
    (x, (h', List.tl_exn xs))

  let root (h, _) = h

  let length (_, xs) = List.length xs
end

module Command = struct
  type t = Nop | Push of int | Add | Mul [@@deriving sexp]

  type var = Field.var

  (** This number is bigger than a 64bit int, but fits in the field *)
  let magic : Field.t =
    Bigint.to_field (Bigint.of_decimal_string "18446744073709551620")

  let inc x = Field.(add x (of_int 1))

  let nop_field = magic

  let add_field = inc magic

  let mul_field = inc (inc magic)

  let typ : (var, t) Typ.t =
    Typ.transport Field.typ
      ~there:(function
          | Nop -> nop_field
          | Push x -> Field.of_int x
          | Add -> add_field
          | Mul -> mul_field)
      ~back:(fun x ->
        match x with
        | _ when Field.equal x nop_field -> Nop
        | _ when Field.equal x add_field -> Add
        | _ when Field.equal x mul_field -> Mul
        | _ -> Push (Field.to_int_exn x) )

  let nopsled program size =
    assert (List.length program < size) ;
    List.init (size - List.length program) ~f:(fun _ -> Nop) @ program

  module Checked = struct
    let match_ : type a.
           Hash.var
        -> var
        -> nop:(unit -> (unit, _) As_prover.t)
        -> push:(Field.t -> (unit, _) As_prover.t)
        -> add:(unit -> ((Field.t * Field.t) * Field.t, _) As_prover.t)
        -> mul:(unit -> ((Field.t * Field.t) * Field.t, _) As_prover.t)
        -> (Hash.var, _) Checked.t =
     fun stack instr ~nop ~push ~add ~mul ->
      let%bind stack_two_back =
        provide_witness Hash.typ
          (let open As_prover in
          let open As_prover.Let_syntax in
          let%map starting_stack = get_state in
          if Merkle_stack.length starting_stack < 2 then
            Merkle_stack.root starting_stack
          else
            let _, stack = Merkle_stack.pop_exn starting_stack in
            let _, stack = Merkle_stack.pop_exn stack in
            Merkle_stack.root stack)
      in
      let%bind is_nop = Field.Checked.(equal (constant nop_field) instr) in
      let%bind is_add = Field.Checked.(equal (constant add_field) instr) in
      let%bind is_mul = Field.Checked.(equal (constant mul_field) instr) in
      let%bind is_push =
        let%map is_one = Boolean.(any [is_nop; is_mul; is_add]) in
        Boolean.not is_one
      in
      let%bind ((x, y), res), new_stack =
        provide_witness
          Typ.(field * field * field * field)
          (let open As_prover in
          let open As_prover.Let_syntax in
          let%bind is_nop = read Boolean.typ is_nop
          and is_add = read Boolean.typ is_add
          and is_mul = read Boolean.typ is_mul in
          let%bind snark_stack_hash = read Field.typ stack in
          let%bind stack = get_state in
          (*printf*)
          (*!"Stack hash: (snark) %{sexp: Hash.t} (real) %{sexp: \*)
              (*Merkle_stack.t}\n"*)
          (*snark_stack_hash stack ;*)
          assert (Field.equal (Merkle_stack.root stack) snark_stack_hash) ;
          if is_nop then
            let%bind () = nop () in
            let%map stack = get_state in
            (Field.((zero, zero), zero), Merkle_stack.root stack)
          else if is_add then
            let%bind (x, y), res = add () in
            let%map stack = get_state in
            (((x, y), res), Merkle_stack.root stack)
          else if is_mul then
            let%bind (x, y), res = mul () in
            let%map stack = get_state in
            (((x, y), res), Merkle_stack.root stack)
          else
            let%bind instr = read Field.typ instr in
            let%bind () = push instr in
            let%map stack = get_state in
            (Field.((zero, zero), zero), Merkle_stack.root stack))
      in
      let%bind push_stack_valid =
        let should_be_new_stack =
          Hash.Checked.combine stack (Hash.hash instr)
        in
        Field.Checked.equal new_stack should_be_new_stack
      in
      let%bind is_add_valid =
        Field.Checked.equal res (Field.Checked.add x y)
      in
      let%bind is_mul_valid =
        let%bind res' = Field.Checked.mul x y in
        Field.Checked.equal res res'
      in
      let%bind binop_stack_valid1, binop_stack_valid2 =
        let should_be_new_stack =
          Hash.Checked.combine stack_two_back (Hash.hash res)
        in
        let%bind b1 = Field.Checked.equal new_stack should_be_new_stack in
        let should_be_old_stack =
          let a = Hash.Checked.combine stack_two_back (Hash.hash y) in
          Hash.Checked.combine a (Hash.hash x)
        in
        let%map b2 = Field.Checked.equal stack should_be_old_stack in
        (b1, b2)
      in
      let%bind add =
        Boolean.all
          [is_add_valid; is_add; binop_stack_valid1; binop_stack_valid2]
      in
      let%bind mul =
        Boolean.all
          [is_mul_valid; is_mul; binop_stack_valid1; binop_stack_valid2]
      in
      let%bind push = Boolean.( && ) is_push push_stack_valid in
      let%map () = Boolean.Assert.any [add; mul; push; is_nop] in
      new_stack
  end
end

module Vm_stack = struct
  type t = Merkle_stack.t
end

let eval (stack: Hash.var) instr : (Hash.var, Vm_stack.t) Checked.t =
  let binop op =
    let open As_prover in
    let open As_prover.Let_syntax in
    let%bind stack = get_state in
    let x, stack = Merkle_stack.pop_exn stack in
    let y, stack = Merkle_stack.pop_exn stack in
    let res = op x y in
    let new_stack = Merkle_stack.push stack res in
    let%map () = set_state new_stack in
    ((x, y), res)
  in
  Command.Checked.match_ stack instr
    ~nop:(fun () -> As_prover.return ())
    ~push:(fun x ->
      let open As_prover in
      let open As_prover.Let_syntax in
      let%bind stack = get_state in
      let new_stack = Merkle_stack.push stack x in
      set_state new_stack )
    ~mul:(fun () -> binop Field.mul)
    ~add:(fun () -> binop Field.add)

let run program : (Field.var, Vm_stack.t) Checked.t =
  let%bind last_stack =
    Checked.List.fold program ~init:(Field.Checked.constant Hash.empty) ~f:eval
  in
  provide_witness Field.typ
    (let open As_prover in
    let open As_prover.Let_syntax in
    let%bind stack = get_state in
    let%map last_stack = read Field.typ last_stack in
    assert (Field.equal (Merkle_stack.root stack) last_stack) ;
    let v, _ = Merkle_stack.pop_exn stack in
    v)

let prove_calc program output : (unit, Vm_stack.t) Checked.t =
  let%bind result = run program in
  Field.Checked.Assert.equal result output

let max_size = 25

let input () = Data_spec.[Typ.list ~length:max_size Command.typ; Field.typ]

let keypair = generate_keypair ~exposing:(input ()) prove_calc

let compile_and_validate program result =
  let program' = Command.nopsled program max_size in
  let proof =
    prove (Keypair.pk keypair) (input ()) Merkle_stack.empty prove_calc
      program' result
  in
  let is_valid =
    verify proof (Keypair.vk keypair) (input ()) program' result
  in
  printf
    !"*** Did I run the program %{sexp: Command.t list} to produce %{sexp: \
      Field.t}? %b\n"
    program result is_valid

(* Look it works! *)

let () =
  compile_and_validate
    Command.[Push 10; Push 10; Mul; Push 4001; Add]
    (Field.of_int 4101)
