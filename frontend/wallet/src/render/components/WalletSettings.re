open Tc;

module Styles = {
  open Css;

  let container = style([padding(`rem(1.0))]);

  let backHeader = style([display(`flex), alignItems(`center)]);

  let backIcon =
    style([
      color(Theme.Colors.hyperlinkAlpha(1.0)),
      hover([color(Theme.Colors.hyperlinkAlpha(0.5))]),
    ]);

  let backHeaderText =
    merge([Theme.Text.Header.h3, style([color(Theme.Colors.midnight)])]);

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([
        color(Theme.Colors.midnight),
        margin(`rem(0.25)),
        marginTop(`rem(1.0)),
      ]),
    ]);

  let textBox = style([maxWidth(`rem(21.))]);
};

[@react.component]
let make = (~publicKey) => {
  let (addressBook, updateAddressBook) =
    React.useContext(AddressBookProvider.context);
  <div className=Styles.container>
    <div className=Styles.backHeader>
      <span
        className=Styles.backIcon
        onClick={_ => ReasonReact.Router.push("/settings")}>
        <Icon kind=Icon.BackArrow />
      </span>
      <Spacer width=0.5 />
      <span className=Styles.backHeaderText>
        {React.string(
           AddressBook.getWalletName(addressBook, publicKey) ++ " settings",
         )}
      </span>
    </div>
    <div className=Styles.label> {React.string("Wallet name")} </div>
    <div className=Styles.textBox>
      <TextField
        label="Name"
        value={Option.withDefault(
          ~default="",
          AddressBook.lookup(addressBook, publicKey),
        )}
        onChange={value =>
          updateAddressBook(ab =>
            AddressBook.set(ab, ~key=publicKey, ~name=value)
          )
        }
      />
    </div>
    <div className=Styles.label> {React.string("Public key")} </div>
    <div className=Styles.textBox>
      <TextField
        label="Key"
        value={PublicKey.toString(publicKey)}
        onChange={_ => ()}
      />
    </div>
    <div className=Styles.label> {React.string("Private key")} </div>
    <div className=Styles.textBox>
      <TextField label="Path" value="" onChange={_ => ()} />
    </div>
    <Link> {React.string("Delete wallet")} </Link>
  </div>;
};
