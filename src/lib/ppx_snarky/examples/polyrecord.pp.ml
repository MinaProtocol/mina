include struct
  type nonrec ('Hash, 'Hash1, 'Nat, 'Time) polymorphic =
    { length: 'Nat
    ; timestamp: 'Time
    ; previous_hash: 'Hash
    ; next_hash: 'Hash
    ; new_hash: 'Hash1 }

  let length {length; _} = length

  and timestamp {timestamp; _} = timestamp

  and previous_hash {previous_hash; _} = previous_hash

  and next_hash {next_hash; _} = next_hash

  and new_hash {new_hash; _} = new_hash

  module T = struct
    type nonrec t =
      (Hash.T.t, Hash.New.T.t, Nat.t, Snarky.Time.T.t) polymorphic
  end

  include T

  module Snarkable = struct
    type nonrec t =
      ( Hash.Snarkable.t
      , Hash.Snarkable.t
      , Nat.Snark.t
      , Snarky.Time.Checked.t )
      polymorphic

    let typ =
      let store {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Store.bind (Typ.store Nat.Snark.typ length) (fun length ->
            Typ.Store.bind (Typ.store Snarky.Time.Checked.typ timestamp)
              (fun timestamp ->
                Typ.Store.bind (Typ.store Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Store.bind (Typ.store Hash.Snarkable.typ next_hash)
                      (fun next_hash ->
                        Typ.Store.bind (Typ.store Hash.Snarkable.typ new_hash)
                          (fun new_hash ->
                            Typ.Store.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let read {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Read.bind (Typ.read Nat.Snark.typ length) (fun length ->
            Typ.Read.bind (Typ.read Snarky.Time.Checked.typ timestamp)
              (fun timestamp ->
                Typ.Read.bind (Typ.read Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Read.bind (Typ.read Hash.Snarkable.typ next_hash)
                      (fun next_hash ->
                        Typ.Read.bind (Typ.read Hash.Snarkable.typ new_hash)
                          (fun new_hash ->
                            Typ.Read.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let alloc {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Alloc.bind (Typ.alloc Nat.Snark.typ length) (fun length ->
            Typ.Alloc.bind (Typ.alloc Snarky.Time.Checked.typ timestamp)
              (fun timestamp ->
                Typ.Alloc.bind (Typ.alloc Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Alloc.bind (Typ.alloc Hash.Snarkable.typ next_hash)
                      (fun next_hash ->
                        Typ.Alloc.bind (Typ.alloc Hash.Snarkable.typ new_hash)
                          (fun new_hash ->
                            Typ.Alloc.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      let check {length; timestamp; previous_hash; next_hash; new_hash} =
        Typ.Check.bind (Typ.check Nat.Snark.typ length) (fun length ->
            Typ.Check.bind (Typ.check Snarky.Time.Checked.typ timestamp)
              (fun timestamp ->
                Typ.Check.bind (Typ.check Hash.Snarkable.typ previous_hash)
                  (fun previous_hash ->
                    Typ.Check.bind (Typ.check Hash.Snarkable.typ next_hash)
                      (fun next_hash ->
                        Typ.Check.bind (Typ.check Hash.Snarkable.typ new_hash)
                          (fun new_hash ->
                            Typ.Check.return
                              { length
                              ; timestamp
                              ; previous_hash
                              ; next_hash
                              ; new_hash } ) ) ) ) )
      in
      {store; read; alloc; check}

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
