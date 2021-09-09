let monthOfIntExn =
  fun
  | 0 => "January"
  | 1 => "Februrary"
  | 2 => "March"
  | 3 => "April"
  | 4 => "May"
  | 5 => "June"
  | 6 => "July"
  | 7 => "August"
  | 8 => "September"
  | 9 => "October"
  | 10 => "November"
  | 11 => "December"
  | x => failwith(Printf.sprintf("Not a month: %d", x));

let thOfDate = x =>
  switch (x mod 10) {
  | 1 => "st"
  | 2 => "nd"
  | 3 => "rd"
  | _ => "th"
  };

let render = (~date, ~now) => {
  let int = (f, x) => f(x) |> Js.Math.unsafe_round;

  let militaryHours = int(Js.Date.getHours, date);
  let minutes = int(Js.Date.getMinutes, date);

  let (hours, meridiem) =
    if (militaryHours >= 12) {
      (militaryHours == 12 ? militaryHours : militaryHours - 12, "pm");
    } else {
      (militaryHours == 0 ? 12 : militaryHours, "am");
    };

  let hoursMins = Printf.sprintf("%d:%02d%s", hours, minutes, meridiem);
  if (Js.Date.getDay(date) == Js.Date.getDay(now)) {
    hoursMins;
  } else {
    let dateDay = int(Js.Date.getDate, date);
    Printf.sprintf(
      "%s %d%s - %s",
      int(Js.Date.getMonth, date) |> monthOfIntExn,
      dateDay,
      thOfDate(dateDay),
      hoursMins,
    );
  };
};
