// Polyfill fetch during prerendering
[%raw "require('isomorphic-unfetch')"];
let fetch =
    (
      ~method_=?,
      ~headers=?,
      ~body=?,
      ~referrer=?,
      ~referrerPolicy=?,
      ~mode=?,
      ~credentials=?,
      ~cache=?,
      ~redirect=?,
      ~integrity=?,
      ~keepalive=?,
      resource,
    ) =>
  Bs_fetch.(
    fetchWithInit(
      resource,
      Bs_fetch.RequestInit.make(
        ~method_?,
        ~headers=?Option.map(Bs_fetch.HeadersInit.make, headers),
        ~body?,
        ~referrer?,
        ~referrerPolicy?,
        ~mode?,
        ~credentials?,
        ~cache?,
        ~redirect?,
        ~integrity?,
        ~keepalive?,
        (),
      ),
    )
  );
