[%%polymorphic_record
`Instances [T; Snarkable]
, `Fields
    [ ("length", Nat, Nat.Snark)
    ; ("timestamp", Snarky.Time.T, Snarky.Time.Checked)
    ; ("previous_hash", Hash.T, Hash.Snarkable)
    ; ("next_hash", Hash)
    ; ("new_hash", Hash.New.T, Hash.Snarkable) ]
, `Contents
    [ `Fold ("length_in_bits", Pervasives.( + ))
    ; `Fold ("fold", Fold_lib.( +> ))
    ; `Fold ("var_to_triples", Pervasives.( @ ))
    ; `Fold ("length_in_triples", Pervasives.( + ))
    ; `Fold ("something_else", fun x y -> x + y) ]]
