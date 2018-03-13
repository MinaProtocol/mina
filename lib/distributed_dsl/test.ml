

let%test "trivial" = true

(*let node = make_node [
  on (Message Message.any)
    ~f:(fun state_machine state msg ->
      state with messages = msg::state.messages

; on (Predicate fun state -> List.length state.messages > 3)
    ~f:(fun state_machine state msg ->
      state with messages = msg::state.messages
                                   D.timeout state_machine 4 (fun some_transition)
]*)

