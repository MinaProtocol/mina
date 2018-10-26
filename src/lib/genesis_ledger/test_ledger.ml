open Functor.With_private

include Make (struct
  let accounts =
    [ { pk= "KE63vdBqwbQ+p2XQ5QOrrPUkCfKtvPRg5jX2AfeC8C7cCNCJSmQBAAAB"
      ; sk= "KG4SU+0RbKTdsnrMHF8FW6sWwURj3d7uElsztcGvNH0shPVtKywAAAA="
      ; balance= 10_000_000 }
    ; { pk= "KNQxdQ2zGPN+xbEinl9//vVvVxIvI/I6UCXiYCj3Bu66afuhDHkBAAAA"
      ; sk= "KLPXDSFPannP/XEG0mzkD8twYUObNRhzpS39pLdOuIU96ZqSRcMCAAA="
      ; balance= 100 }
    ; { pk= "KA4EVFZFimYTnjvb5+o7Pfh8qe7+/vf7oZC5S1kk3xXdXRZ+xBoBAAAA"
      ; sk= "KH9kL3O+vcLHvQTIli8z2xs9YoagMZM7oDjDitx+0/tps04bOhcCAAA="
      ; balance= 1_000 }
    ; { pk= "KB71COB8c4Cz9m1MgQwdJ5f1wW/DZOSOdVr6qwA4Lw/ZNLmuoHQDAAAB"
      ; sk= "KG9w15C1oYIndb0bp4cFB0TqsIZ8QEwKfnxL0FCt54jPk4NmJswCAAA="
      ; balance= 1_000 }
    ; { pk= "KL8imhaBJyJCKXhjaBf8xEhT8MdNKu7fd6W0akmuaPQo0nfiuXMAAAAA"
      ; sk= "KCijYT7z7Opl8VI16EyMPWG4ty6o4iWeWI7I+cdW7H1hj3HJ8JIBAAA="
      ; balance= 1_000 }
    ; { pk= "KMGTh/pZ4Re7c81teCUupEh53+9fAwx4G+OzujBaQXNlG4fR9l4DAAAB"
      ; sk= "KDYNlJUdYS09kvoWpcstfu7B6cGKEf9uP9anSPej0eVj2jzB1mcDAAA="
      ; balance= 1_000 }
    ; { pk= "KMdebPAAdlELbSX6zwVCQHYPVNKUY5nyLVNl3BdSbH+cbxU0ADQCAAAB"
      ; sk= "KNfa2my92ziufwlYs33or/4EY8v0DHLpgUaTCOBk7DjeEZRz0UUDAAA="
      ; balance= 1_000 }
    ; { pk= "KO7wOEi08r68hg3+TKjYz0hAxpfBnwKwWDWELtGpggfHskEvtF4BAAAB"
      ; sk= "KNoKzYEPCUizc6EPGAxafj+jtwHz2qbgJPcy/+n1DpBwL8UryooBAAA="
      ; balance= 1_000 }
    ; { pk= "KI8nqqAgq4mEGjrFebow36GOKM3d26db+sIZ1Up7T+paKoCgmTYDAAAB"
      ; sk= "KM2do4YVHCcJS0QjI1Iw2xyEHg2ETJtO0GIV7Sm2R7qa7UD9LiwAAAA="
      ; balance= 1_000 }
    ; { pk= "KFIwno4wxlO/e0MjRdZROXnlrmh9AMYVad3kJrcPU4Fwe74qHPkAAAAB"
      ; sk= "KIMpQd2zHGzMm9kJUdRqTOuxZZWt5MJKHsgOzpnuo163s2UXItgBAAA="
      ; balance= 1_000 }
    ; { pk= "KKueD3sKJ+S7EbJlo192GPKFSgNkCs/Xio7BpkVh8dVDvKSNyJQBAAAA"
      ; sk= "KLlOtOQ02TIP5eDWkoGwq0UkWJy1Pz29oNBsCmnOT2zTf3QoSQAAAAA="
      ; balance= 1_000 }
    ; { pk= "KBNmX7yf+XL3X/NL8eb4phJNPkFqnKnjW1d8UIoQXKVmW9gUdf4BAAAA"
      ; sk= "KHiXtcpDPD5bv0UDn8scGO2XWmufONb2FJN1D1errmdOr/hGxB8DAAA="
      ; balance= 1_000 }
    ; { pk= "KMJOuj+qTSWhW3Z3ovBOXjiinclBfBoy2LUJwLwj8QImm0kcDRoBAAAA"
      ; sk= "KGE/+fYdDGAJ7XzDENaRU8RUBiiGW3d7N9UP89lUGRDFgD8s6TUCAAA="
      ; balance= 1_000 }
    ; { pk= "KOvma+7SVL0GM5vU0DTJ/EkwHeuTgfuEx6uAwMVPnAWB++XVBX0AAAAA"
      ; sk= "KDxMD1RMRTFeybSy2I/j/mXi3BbwMZK1T0/m9yg0qlmErjzTuXABAAA="
      ; balance= 1_000 }
    ; { pk= "KMdpUe3I8lWqhUIdUbWzdV4ubU6vfQVpkVBVLY1W/6enBMrQdoEDAAAB"
      ; sk= "KKfW61uYc0U7CihhXnTEioJ5I1qqeS/C13702l6RVR46xvm7uPUCAAA="
      ; balance= 1_000 }
    ; { pk= "KKy4+/iZ/s5m8PS3G4HG95bI5osiKY71BVKRgcnkh4dnS8H9luABAAAB"
      ; sk= "KMYeC2u+ugxQkBdE8HTHTvROlA1+oOIcYR3Rxi9qJwFtcLbqkusAAAA="
      ; balance= 1_000 }
    ; { pk= "KEqReFvUxEAUxhNjyGaUS5iH0pS4/TBHkUpvdIl8ue3SAb5cDqEBAAAB"
      ; sk= "KPXCLIvKGY6NozqsdfgAeAGZNgka46HYitp1n5RlqG8tqLeqVPsAAAA="
      ; balance= 1_000 }
    ; { pk= "KNztEcQ4/KcriidoDPC5H8V5otv2wvJQPxlcg2/TlOFBR69LfdMAAAAB"
      ; sk= "KPdCR+LJeRfaOOgg2VeIk3yAPJavBnew8UFd0e1gNajIQ7RJTR4DAAA="
      ; balance= 1_000 } ]
end)
