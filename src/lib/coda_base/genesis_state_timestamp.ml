open Core

let value =
  Time.of_date_ofday
    ~zone:(Time.Zone.of_utc_offset ~hours:(-7))
    (Date.create_exn ~y:2018 ~m:Month.Sep ~d:1)
    (Time.Ofday.create ~hr:10 ())
