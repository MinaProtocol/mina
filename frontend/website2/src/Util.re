/* let rec arrayFind = (a, f, i) => { */
/*   switch (i < Array.length(a)) { */
/*   | false => None */
/*   | true => */
/*     let e = Array.unsafe_get(a, i); */
/*     f(e) ? Some(e) : arrayFind(a, f, i + 1); */
/*   }; */
/* }; */
/* let arrayFind = (a, ~f) => arrayFind(a, f, 0); */

let reactMap = (~f, v) =>
  Option.map(f, v) |> Option.value(~default=React.null);
