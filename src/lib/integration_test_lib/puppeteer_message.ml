type t =
  { puppeteer_script_event : bool
  ; puppeteer_event_type : string option
  ; message : string
  }
[@@deriving yojson]
