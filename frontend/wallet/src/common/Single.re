module Make =
       (
         T: {
           type input;
           type t;
           let make: (~drop: unit => unit, input) => t;
         },
       ) => {
  let cache: ref(option(T.t)) = ref(None);

  let get = input => {
    switch (cache^) {
    | Some(w) => w
    | None =>
      let res = T.make(~drop=() => cache := None, input);
      cache := Some(res);
      res;
    };
  };
};
