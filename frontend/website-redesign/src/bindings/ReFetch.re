include Bs_fetch;

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
  fetchWithInit(
    resource,
    RequestInit.make(
      ~method_?,
      ~headers=?Option.map(HeadersInit.make, headers),
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
  );
