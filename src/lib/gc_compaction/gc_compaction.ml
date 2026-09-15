let default_overhead = 500

let default_min_peak_heap_mib = 256.

let bytes_per_word = Sys.word_size / 8

let mib_of_words words =
  float_of_int words *. float_of_int bytes_per_word /. 1048576.

let should_compact_now ~overhead ~min_peak_heap_mib ~top_heap_words ~heap_words
    ~live_words =
  (* [live_words = 0] means the heap is empty, not that everything is garbage:
     dividing by it would be meaningless. *)
  live_words > 0
  (* The floor keys on the *peak* heap, not the current one. Sweeping returns
     empty pools to a freelist that stays mapped, so [heap_words] falls while
     RSS does not -- precisely when compaction is worth the most. Keying the
     floor on [heap_words] would refuse to compact exactly then. *)
  && Float.compare (mib_of_words top_heap_words) min_peak_heap_mib >= 0
  && (heap_words - live_words) * 100 / live_words > overhead

let%test_module "compaction policy" =
  ( module struct
    let words_of_mib mib = mib * 1048576 / bytes_per_word

    let decide ?(overhead = default_overhead) ?(min_peak_heap_mib = 256.)
        ?top_heap ~heap ~live () =
      let top_heap = Option.value ~default:heap top_heap in
      should_compact_now ~overhead ~min_peak_heap_mib
        ~top_heap_words:(words_of_mib top_heap) ~heap_words:(words_of_mib heap)
        ~live_words:(words_of_mib live)

    (* An empty heap must not divide by zero, however large it looks. *)
    let%test "empty heap is left alone" = not (decide ~heap:4096 ~live:0 ())

    (* Below the floor a compaction cannot reclaim enough to be worth a pause,
       no matter how bad the ratio is. *)
    let%test "small heap is left alone even when mostly waste" =
      not (decide ~heap:100 ~live:1 ())

    let%test "at the floor, mostly waste, compacts" =
      decide ~heap:256 ~live:1 ()

    (* Regression: sweeping shrinks [heap_words] below the floor while RSS stays
       at the peak. Keying the floor on the current heap refused to compact here,
       which is the one case that matters most. *)
    let%test "swept heap under the floor still compacts on peak" =
      decide ~top_heap:1024 ~heap:53 ~live:3 ()

    (* 1 GiB heap holding 512 MiB live is 100% overhead: well under the 500%
       default, so this is a working process, not a fragmented one. *)
    let%test "large heap in active use is left alone" =
      not (decide ~heap:1024 ~live:512 ())

    (* The archive's shape: heap stays large while live data collapses. *)
    let%test "large heap with collapsed live set compacts" =
      decide ~heap:1024 ~live:64 ()

    let%test "overhead is configurable" =
      let heap, live = (1024, 256) in
      (* 300% overhead: above a 200 threshold, below the 500 default *)
      decide ~overhead:200 ~heap ~live ()
      && not (decide ~overhead:500 ~heap ~live ())
  end )

(* [off] disables the alarm entirely; an integer overrides the overhead
   percentage. Anything else is ignored, so a typo cannot silently disable
   compaction. *)
let overhead_from_env ~default ~logger =
  match Sys.getenv_opt "MINA_GC_COMPACTION" with
  | None ->
      Some default
  | Some s -> (
      match String.lowercase_ascii (String.trim s) with
      | "off" ->
          [%log info] "Heap compaction alarm disabled by MINA_GC_COMPACTION=off" ;
          None
      | other -> (
          match int_of_string_opt other with
          | Some n when n > 0 ->
              Some n
          | _ ->
              [%log warn]
                "Ignoring unparseable MINA_GC_COMPACTION=$value; using the \
                 default overhead of $default percent"
                ~metadata:[ ("value", `String s); ("default", `Int default) ] ;
              Some default ) )

let install ?(overhead = default_overhead)
    ?(min_peak_heap_mib = default_min_peak_heap_mib)
    ?(should_compact = fun () -> true) ~logger () =
  match overhead_from_env ~default:overhead ~logger with
  | None ->
      ()
  | Some overhead ->
      [%log info]
        "Installing heap compaction alarm: compact when wasted heap exceeds \
         $overhead percent of live data, once the heap has peaked above \
         $min_peak_heap_mib MiB"
        ~metadata:
          [ ("overhead", `Int overhead)
          ; ("min_peak_heap_mib", `Float min_peak_heap_mib)
          ] ;
      let (_ : Gc.alarm) =
        Gc.create_alarm (fun () ->
            let stat = Gc.quick_stat () in
            if
              should_compact_now ~overhead ~min_peak_heap_mib
                ~top_heap_words:stat.top_heap_words ~heap_words:stat.heap_words
                ~live_words:stat.live_words
              && should_compact ()
            then (
              let before = stat.heap_words in
              let start = Sys.time () in
              Gc.compact () ;
              let elapsed_ms = (Sys.time () -. start) *. 1000. in
              let after = (Gc.quick_stat ()).heap_words in
              [%log debug]
                "Compacted the major heap: $before_mib MiB -> $after_mib MiB \
                 in $elapsed_ms ms"
                ~metadata:
                  [ ("before_mib", `Float (mib_of_words before))
                  ; ("after_mib", `Float (mib_of_words after))
                  ; ("elapsed_ms", `Float elapsed_ms)
                  ] ) )
      in
      ()
