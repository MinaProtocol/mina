[@bs.send.pipe: Js.Promise.t('a)]
external map: ([@bs.uncurry] ('a => 'b)) => Js.Promise.t('b) = "then";

[@bs.send.pipe: Js.Promise.t('a)]
external bind: ([@bs.uncurry] ('a => Js.Promise.t('b))) => Js.Promise.t('b) =
  "then";

let iter = (f: _ => unit, v) => ignore(map(inner => f(inner), v));

[@bs.val] [@bs.scope "Promise"]
external return: 'a => Js.Promise.t('a) = "resolve";
