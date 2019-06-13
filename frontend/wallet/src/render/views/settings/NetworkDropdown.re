open Tc;
module Styles = {
  open Css;

  let networkContainer = style([width(`rem(21.))]);

  let customNetwork = style([display(`flex), alignItems(`center)]);
};

type networkOption =
  | NetworkOption(string)
  | Custom(string)
  | Loading
  | None;

let listToOptions = l => List.map(~f=x => (x, React.string(x)), l);

module NetworkQueryString = [%graphql {|
    {
      network
    }
  |}];

module NetworkQuery = ReasonApollo.CreateQuery(NetworkQueryString);

module InnerDropdown = {
  [@react.component]
  let make = (~network) => {
    let (networkValue, setNetworkValue) =
      React.useState(() =>
        switch (
          (network: ReasonApolloTypes.queryResponse(NetworkQueryString.t))
        ) {
        | Loading => Loading
        | Error(_) => None
        | Data(d) =>
          switch (d##network) {
          | Some("testnet.codaprotocol.com") =>
            NetworkOption("testnet.codaprotocol.com")
          | Some(s) => Custom(s)
          | None => None
          }
        }
      );

    let customNetwork = "Custom network";
    let loading = "Loading...";

    let dropDownValue =
      switch (networkValue) {
      | NetworkOption(s) => Some(s)
      | Custom(_) => Some(customNetwork)
      | Loading => Some(loading)
      | None => None
      };

    let isLoading = networkValue == Loading;

    let dropDownOptions = ["testnet.codaprotocol.com", customNetwork];
    let dropDownOptions =
      isLoading ? [loading, ...dropDownOptions] : dropDownOptions;

    let dispatchToMain = React.useContext(ProcessDispatchProvider.context);

    let dropdownHandler = s =>
      switch (s) {
      | "Custom network" =>
        setNetworkValue(
          fun
          | NetworkOption(_) => Custom("")
          | x => x,
        )
      | s =>
        dispatchToMain(CodaProcess.Action.ChangeArgs(["-peer", s]));
        setNetworkValue(_ => NetworkOption(s));
      };

    <div className=Styles.networkContainer>
      <Dropdown
        value=dropDownValue
        label="Network"
        options={listToOptions(dropDownOptions)}
        onChange=dropdownHandler
        disabled=isLoading
      />
      {switch (networkValue) {
       | Custom(v) =>
         <>
           <Spacer height=0.5 />
           <div className=Styles.customNetwork>
             <Icon kind=Icon.BentArrow />
             <Spacer width=0.5 />
             <TextField
               value=v
               label="URL"
               placeholder="my.network.com"
               onChange={s => setNetworkValue(_ => Custom(s))}
               button={
                 <TextField.Button
                   text="Save"
                   color=`Green
                   onClick={_ =>
                     dispatchToMain(
                       CodaProcess.Action.ChangeArgs(["-peer", v]),
                     )
                   }
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
