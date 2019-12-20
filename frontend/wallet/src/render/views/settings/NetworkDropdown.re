open Tc;
module Styles = {
  open Css;

  let networkContainer = style([width(`rem(21.))]);

  let customNetwork = style([display(`flex), alignItems(`center)]);
};

type networkOption =
  | NetworkOption(string)
  | Custom(string);

let listToOptions = l => List.map(~f=x => (x, React.string(x)), l);

module NetworkQueryString = [%graphql {|
    {
      initialPeers
    }
  |}];

module NetworkQuery = ReasonApollo.CreateQuery(NetworkQueryString);

module InnerDropdown = {
  let customNetwork = "Custom network";
  let networkOptions = [CodaProcess.defaultNetwork];
  let dropDownOptions = List.append(networkOptions, [customNetwork]);

  let stringToNetworkOption = s =>
    if (List.member(~value=s, networkOptions)) {
      NetworkOption(s);
    } else {
      Custom(s);
    };

  [@react.component]
  let make = (~network) => {
    let (networkValue, setNetworkValue) =
      React.useState(() =>
        switch (
          (network: ReasonApolloTypes.queryResponse(NetworkQueryString.t))
        ) {
        | Loading
        | Error(_) =>
          stringToNetworkOption(CodaProcess.getLocalStorageNetwork())
        | Data(d) =>
          // TODO: Refactor this to actually check network, translate from IP etc
          switch (d##initialPeers) {
          | [||] => Custom("")
          | a => stringToNetworkOption(Caml.Array.get(a, 0))
          }
        }
      );

    let dropDownValue =
      switch (networkValue) {
      | NetworkOption(s) => Some(s)
      | Custom(_) => Some(customNetwork)
      };

    let dispatchNetwork = {
      let dispatchToMain = React.useContext(ProcessDispatchProvider.context);
      s => {
        Bindings.LocalStorage.setItem(~key=`Network, ~value=s);
        let args =
          switch (s) {
          | "" => []
          | s => ["-peer", s]
          };
        dispatchToMain(CodaProcess.Action.StartCoda(args));
      };
    };

    let dropdownHandler = s =>
      switch (s) {
      | "Custom network" =>
        setNetworkValue(
          fun
          | NetworkOption(_) => Custom("")
          | x => x,
        )
      | s =>
        dispatchNetwork(s);
        setNetworkValue(_ => NetworkOption(s));
      };

    <div className=Styles.networkContainer>
      <Dropdown
        value=dropDownValue
        label="Network"
        options={listToOptions(dropDownOptions)}
        onChange=dropdownHandler
      />
      {switch (networkValue) {
       | Custom(customValue) =>
         <>
           <Spacer height=0.5 />
           <div className=Styles.customNetwork>
             <Icon kind=Icon.BentArrow />
             <Spacer width=0.5 />
             <TextField
               value=customValue
               label="URL"
               placeholder="testnet-name.o1test.net:8303"
               onChange={s => setNetworkValue(_ => Custom(s))}
               button={
                 <TextField.Button
                   text="Save"
                   color=`Green
                   onClick={_ => dispatchNetwork(customValue)}
                 />
               }
             />
           </div>
         </>
       | _ => React.null
       }}
    </div>;
  };
};

[@react.component]
let make = () => {
  <NetworkQuery partialRefetch=true>
    {response => <InnerDropdown network={response.result} />}
  </NetworkQuery>;
};
