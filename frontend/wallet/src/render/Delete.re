[@react.component]
let make = (~closeModal, ~walletName) => {
  <div onClick={e => ReactEvent.Synthetic.stopPropagation(e)}>
    <h1> {ReasonReact.string("Delete Wallet")} </h1>
    <div
      className=Css.(
        style([
          display(`flex),
          justifyContent(`center),
          alignItems(`center),
        ])
      )>
      <p> {ReasonReact.string("Are you sure you would like to delete:")} </p>
      <span> {ReasonReact.string(walletName)} </span>
      <span> {ReasonReact.string("?")} </span>
    </div>
    <br />
    <p>
      {ReasonReact.string("Please type in the wallet name on continue")}
    </p>
    <br />
    <label> {ReasonReact.string("Wallet:")} </label>
    <input type_="text" />
    <br />
    <ModalButtons
      onSecondaryClick={_e => closeModal()}
      onPrimaryClick={_e => ()}
      primaryColor=Theme.Colors.roseBud
      primaryCopy="Delete"
    />
  </div>;
};
