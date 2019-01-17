module Type = struct
  include struct
    type nonrec ('a, 'a1, 'b, 'c) polymorphic =
      {a: 'a; b: 'b; c: 'c; d: 'a; e: 'a1}

    let a {a; _} = a

    and b {b; _} = b

    and c {c; _} = c

    and d {d; _} = d

    and e {e; _} = e

    type nonrec t = (A.t, A.t, B.t, C.t) polymorphic

    let typ =
      let store {a; b; c; d; e} =
        Typ.Store.bind (Typ.store A.typ a) (fun a ->
            Typ.Store.bind (Typ.store B.typ b) (fun b ->
                Typ.Store.bind (Typ.store C.typ c) (fun c ->
                    Typ.Store.bind (Typ.store A.typ d) (fun d ->
                        Typ.Store.bind (Typ.store A.typ e) (fun e ->
                            Typ.Store.return {a; b; c; d; e} ) ) ) ) )
      in
      let read {a; b; c; d; e} =
        Typ.Read.bind (Typ.read A.typ a) (fun a ->
            Typ.Read.bind (Typ.read B.typ b) (fun b ->
                Typ.Read.bind (Typ.read C.typ c) (fun c ->
                    Typ.Read.bind (Typ.read A.typ d) (fun d ->
                        Typ.Read.bind (Typ.read A.typ e) (fun e ->
                            Typ.Read.return {a; b; c; d; e} ) ) ) ) )
      in
      let alloc {a; b; c; d; e} =
        Typ.Alloc.bind (Typ.alloc A.typ a) (fun a ->
            Typ.Alloc.bind (Typ.alloc B.typ b) (fun b ->
                Typ.Alloc.bind (Typ.alloc C.typ c) (fun c ->
                    Typ.Alloc.bind (Typ.alloc A.typ d) (fun d ->
                        Typ.Alloc.bind (Typ.alloc A.typ e) (fun e ->
                            Typ.Alloc.return {a; b; c; d; e} ) ) ) ) )
      in
      let check {a; b; c; d; e} =
        Typ.Check.bind (Typ.check A.typ a) (fun a ->
            Typ.Check.bind (Typ.check B.typ b) (fun b ->
                Typ.Check.bind (Typ.check C.typ c) (fun c ->
                    Typ.Check.bind (Typ.check A.typ d) (fun d ->
                        Typ.Check.bind (Typ.check A.typ e) (fun e ->
                            Typ.Check.return {a; b; c; d; e} ) ) ) ) )
      in
      {store; read; alloc; check}

    module Var = struct
      type nonrec t = (A.Var.t, A.Something.t, B.Var.t, C.Var.t) polymorphic

      let f x =
        A.Var.f x.a
        + (B.Var.f x.b + (C.Var.f x.c + (A.Var.f x.d + A.Something.f x.e)))
    end
  end
end

module Type2 = struct
  include struct
    type nonrec ('hash, 'hash1, 'hash2, 'nat, 'time) polymorphic =
      { length: 'nat
      ; timestamp: 'time
      ; previous_hash: 'hash
      ; next_hash: 'hash1
      ; new_hash: 'hash2 }

    let length {length; _} = length

    and timestamp {timestamp; _} = timestamp

    and previous_hash {previous_hash; _} = previous_hash

    and next_hash {next_hash; _} = next_hash

    and new_hash {new_hash; _} = new_hash

    module T = struct
      type nonrec t =
        (Hash.T.t, Hash.T.t, Hash.New.T.t, Nat.t, Snarky.Time.T.t) polymorphic
    end

    include T

    let typ =
      let store {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Store.bind (Typ.store Nat.typ length) (fun length ->
            Typ.Store.bind (Typ.store Snarky.Time.typ timestamp)
              (fun timestamp ->
                Typ.Store.bind (Typ.store Hash.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Store.bind (Typ.store Hash.typ next_hash)
                      (fun next_hash ->
                        Typ.Store.bind (Typ.store Hash.typ new_hash)
                          (fun new_hash ->
                            Typ.Store.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let read {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Read.bind (Typ.read Nat.typ length) (fun length ->
            Typ.Read.bind (Typ.read Snarky.Time.typ timestamp)
              (fun timestamp ->
                Typ.Read.bind (Typ.read Hash.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Read.bind (Typ.read Hash.typ next_hash)
                      (fun next_hash ->
                        Typ.Read.bind (Typ.read Hash.typ new_hash)
                          (fun new_hash ->
                            Typ.Read.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let alloc {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Alloc.bind (Typ.alloc Nat.typ length) (fun length ->
            Typ.Alloc.bind (Typ.alloc Snarky.Time.typ timestamp)
              (fun timestamp ->
                Typ.Alloc.bind (Typ.alloc Hash.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Alloc.bind (Typ.alloc Hash.typ next_hash)
                      (fun next_hash ->
                        Typ.Alloc.bind (Typ.alloc Hash.typ new_hash)
                          (fun new_hash ->
                            Typ.Alloc.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let check {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Check.bind (Typ.check Nat.typ length) (fun length ->
            Typ.Check.bind (Typ.check Snarky.Time.typ timestamp)
              (fun timestamp ->
                Typ.Check.bind (Typ.check Hash.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Check.bind (Typ.check Hash.typ next_hash)
                      (fun next_hash ->
                        Typ.Check.bind (Typ.check Hash.typ new_hash)
                          (fun new_hash ->
                            Typ.Check.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      {store; read; alloc; check}

    module Snarkable = struct
      type nonrec t =
        ( Hash.Snarkable.t
        , Hash.Snarkable.t
        , Hash.Snarkable.t
        , Nat.Snark.t
        , Snarky.Time.Checked.t )
        polymorphic

      let length_in_bits t =
        Pervasives.( + )
          (Nat.Snark.length_in_bits t.length)
          (Pervasives.( + )
             (Snarky.Time.Checked.length_in_bits t.timestamp)
             (Pervasives.( + )
                (Hash.Snarkable.length_in_bits t.previous_hash)
                (Pervasives.( + )
                   (Hash.Snarkable.length_in_bits t.next_hash)
                   (Hash.Snarkable.length_in_bits t.new_hash))))

      let fold t =
        Fold_lib.( +> ) (Nat.Snark.fold t.length)
          (Fold_lib.( +> )
             (Snarky.Time.Checked.fold t.timestamp)
             (Fold_lib.( +> )
                (Hash.Snarkable.fold t.previous_hash)
                (Fold_lib.( +> )
                   (Hash.Snarkable.fold t.next_hash)
                   (Hash.Snarkable.fold t.new_hash))))

      let var_to_triples t =
        Pervasives.( @ )
          (Nat.Snark.var_to_triples t.length)
          (Pervasives.( @ )
             (Snarky.Time.Checked.var_to_triples t.timestamp)
             (Pervasives.( @ )
                (Hash.Snarkable.var_to_triples t.previous_hash)
                (Pervasives.( @ )
                   (Hash.Snarkable.var_to_triples t.next_hash)
                   (Hash.Snarkable.var_to_triples t.new_hash))))

      let length_in_triples t =
        Pervasives.( + )
          (Nat.Snark.length_in_triples t.length)
          (Pervasives.( + )
             (Snarky.Time.Checked.length_in_triples t.timestamp)
             (Pervasives.( + )
                (Hash.Snarkable.length_in_triples t.previous_hash)
                (Pervasives.( + )
                   (Hash.Snarkable.length_in_triples t.next_hash)
                   (Hash.Snarkable.length_in_triples t.new_hash))))

      let something_else t =
        (fun x y -> x + y)
          (Nat.Snark.something_else t.length)
          ((fun x y -> x + y)
             (Snarky.Time.Checked.something_else t.timestamp)
             ((fun x y -> x + y)
                (Hash.Snarkable.something_else t.previous_hash)
                ((fun x y -> x + y)
                   (Hash.Snarkable.something_else t.next_hash)
                   (Hash.Snarkable.something_else t.new_hash))))
    end
  end
end
