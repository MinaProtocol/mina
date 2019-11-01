module Block = [%graphql
  {|
         query {
           version
           blocks(last: 1) {
             nodes {
               stateHash
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
      () => {
        Js.log("posting message");
        let _ =
          Worker.Promise.postMessage(worker, 100)
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
      | Some((v, time)) => (v, string_of_int(time))
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
