open Core_kernel

type t =
  (* It is important to choose `maximum_refresh` and `bucket_size` such that
   * the probability of `bucket_size` nodes failing within `maximum_refresh`
   * time is "small".
   *
   * If such an event happens, where all nodes within a bucket fail within
   * the maximum_refresh time, runtime will be affected but correctness will
   * not.
   * *)
  { maximum_refresh : Time.Span.t
  ; bucket_size : int (* $k$ in the paper *)
  ; max_lookup_concurrency : int (* $\alpha$ in the paper *)
  ; ping_time : Time.Span.t (* All known nodes are pinged every ping_time *)
  ; max_msg_size_bytes : int (* Smaller than a packet! *)
  ; ping_limit : int (* After this many retries, a node is assumed dead *)
  }

let default : t =
  { maximum_refresh = Time.Span.of_hr 1.
  ; bucket_size = 7
  ; max_lookup_concurrency = 3
  ; ping_time = Time.Span.of_min 5.
  ; max_msg_size_bytes = 1200
  ; ping_limit = 4
  }

