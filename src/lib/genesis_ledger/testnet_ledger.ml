open Functor.Without_private

(* TODO: generate new keypairs before public testnet *)
include Make (struct
  let accounts =
    [ { pk= "KE63vdBqwbQ+p2XQ5QOrrPUkCfKtvPRg5jX2AfeC8C7cCNCJSmQBAAAB"
      ; balance= 10_000_000 }
    ; { pk= "KNQxdQ2zGPN+xbEinl9//vVvVxIvI/I6UCXiYCj3Bu66afuhDHkBAAAA"
      ; balance= 1_000 }
    ; { pk= "KA4EVFZFimYTnjvb5+o7Pfh8qe7+/vf7oZC5S1kk3xXdXRZ+xBoBAAAA"
      ; balance= 1_000 }
    ; { pk= "KB71COB8c4Cz9m1MgQwdJ5f1wW/DZOSOdVr6qwA4Lw/ZNLmuoHQDAAAB"
      ; balance= 1_000 }
    ; { pk= "KL8imhaBJyJCKXhjaBf8xEhT8MdNKu7fd6W0akmuaPQo0nfiuXMAAAAA"
      ; balance= 1_000 }
    ; { pk= "KMGTh/pZ4Re7c81teCUupEh53+9fAwx4G+OzujBaQXNlG4fR9l4DAAAB"
      ; balance= 1_000 }
    ; { pk= "KMdebPAAdlELbSX6zwVCQHYPVNKUY5nyLVNl3BdSbH+cbxU0ADQCAAAB"
      ; balance= 1_000 }
    ; { pk= "KO7wOEi08r68hg3+TKjYz0hAxpfBnwKwWDWELtGpggfHskEvtF4BAAAB"
      ; balance= 1_000 }
    ; { pk= "KI8nqqAgq4mEGjrFebow36GOKM3d26db+sIZ1Up7T+paKoCgmTYDAAAB"
      ; balance= 1_000 }
    ; { pk= "KFIwno4wxlO/e0MjRdZROXnlrmh9AMYVad3kJrcPU4Fwe74qHPkAAAAB"
      ; balance= 1_000 }
    ; { pk= "KKueD3sKJ+S7EbJlo192GPKFSgNkCs/Xio7BpkVh8dVDvKSNyJQBAAAA"
      ; balance= 1_000 }
    ; { pk= "KBNmX7yf+XL3X/NL8eb4phJNPkFqnKnjW1d8UIoQXKVmW9gUdf4BAAAA"
      ; balance= 1_000 }
    ; { pk= "KMJOuj+qTSWhW3Z3ovBOXjiinclBfBoy2LUJwLwj8QImm0kcDRoBAAAA"
      ; balance= 1_000 }
    ; { pk= "KOvma+7SVL0GM5vU0DTJ/EkwHeuTgfuEx6uAwMVPnAWB++XVBX0AAAAA"
      ; balance= 1_000 }
    ; { pk= "KMdpUe3I8lWqhUIdUbWzdV4ubU6vfQVpkVBVLY1W/6enBMrQdoEDAAAB"
      ; balance= 1_000 }
    ; { pk= "KKy4+/iZ/s5m8PS3G4HG95bI5osiKY71BVKRgcnkh4dnS8H9luABAAAB"
      ; balance= 1_000 }
    ; { pk= "KEqReFvUxEAUxhNjyGaUS5iH0pS4/TBHkUpvdIl8ue3SAb5cDqEBAAAB"
      ; balance= 1_000 }
    ; { pk= "KNztEcQ4/KcriidoDPC5H8V5otv2wvJQPxlcg2/TlOFBR69LfdMAAAAB"
      ; balance= 1_000 } ]
end)
