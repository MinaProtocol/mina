module Block = [%graphql
  {|
    query {
      blockchainVerificationKey
      blocks(last: 1) {
        nodes {
          stateHashField
          protocolStateProof {
            a
            b
            c
            delta_prime
            z
          }
          protocolState {
            consensusState {
              blockchainLength @bsDecoder(fn:"Apollo.Decoders.string")
            }
          }
        }
      }
    }
  |}
];

module BlockQuery = ReasonApollo.CreateQuery(Block);

module DemoInternal = {
  [@react.component]
  let make = (~worker, ~blocks) => {
    let (isVerified, setVerified) = React.useState(() => None);

    React.useEffect1(
      () =>
        switch (blocks) {
        | None => None
        | Some(data) when Array.length(data##blocks##nodes) == 0 => None
        | Some(data) =>
          Js.log("posting message");
          let nodes = data##blocks##nodes;
          Array.fast_sort(
            (a, b) =>
              compare(
                int_of_string(
                  a##protocolState##consensusState##blockchainLength,
                ),
                int_of_string(
                  b##protocolState##consensusState##blockchainLength,
                ),
              ),
            nodes,
          );
          let block = nodes[Array.length(nodes) - 1];
          let proof = block##protocolStateProof;
          let msg = {
            "key": data##blockchainVerificationKey,
            "a": proof##a,
            "b": proof##b,
            "c": proof##c,
            "delta_prime": proof##delta_prime,
            "z": proof##z,
            "stateHashField": block##stateHashField,
          };
          let _ =
            Worker.Promise.postMessage(worker, msg)
            |> Js.Promise.then_(response => {
                 let verified = response##verified;
                 let verifyTime = response##time;
                 Js.log2("got response", response);
                 setVerified(_ => Some((verified, verifyTime)));
                 Js.Promise.resolve();
               });
          setVerified(_ => None);
          None;
        },
      [|blocks|],
    );

    let (verified, verifiedTime) =
      switch (isVerified) {
      | Some((v, time)) => (v, string_of_int(time / 1000))
      | None => (false, "?")
      };

    <>
      <Background />
      <Banner time=verifiedTime />
      <Spacer height=5.0 />
      <BlockRow verified />
    </>;
  };
};

[@react.component]
let make = (~worker) => {
  <ReasonApollo.Provider client=Apollo.client>
    <BlockQuery>
      {response =>
         switch (response.result) {
         | Loading => <DemoInternal worker blocks=None />
         | Error(e) =>
           Js.log(e##message);
           <DemoInternal worker blocks=None />;
         | Data(d) => <DemoInternal worker blocks={Some(d)} />
         }}
    </BlockQuery>
  </ReasonApollo.Provider>;
};
