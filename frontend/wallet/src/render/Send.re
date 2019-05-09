open Tc;

[@react.component]
let make = (~closeModal, ~myWallets, ~settings) => {
  <div onClick={e => ReactEvent.Synthetic.stopPropagation(e)}>
    <h1> {ReasonReact.string("Send Coda")} </h1>
    <label> {ReasonReact.string("From:")} </label>
    <select>
      {List.map(myWallets, ~f=(wallet: Wallet.t)
         // TODO: Replace option/select tags with a custom dropdown
         // You can't put arbitrary html in the options, and styling
         // is hard.
         =>
           <option
             key={wallet.key |> PublicKey.toString}
             value={wallet.key |> PublicKey.toString}>
             {ReasonReact.string(
                (
                  Settings.lookup(settings, wallet.key)
                  |> Option.withDefault(
                       ~default=wallet.key |> PublicKey.toString,
                     )
                )
                ++ {j|( ■ |j}
                ++ Js.Int.toString(wallet.balance)
                ++ " )",
              )}
           </option>
         )
       |> Array.fromList
       |> ReasonReact.array}
    </select>
    <br />
    <label> {ReasonReact.string("To:")} </label>
    <input name="to" type_="text" />
    <br />
    <label> {ReasonReact.string("Qty:")} </label>
    <input name="qty" type_="number" />
    <br />
    <ModalButtons
      onSecondaryClick={_e => closeModal()}
      onPrimaryClick={_e => ()}
      primaryColor=Theme.Colors.serpentine
      primaryCopy="Send"
    />
  </div>;
};
