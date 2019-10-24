open Tc;

module Styles = {
  open Css;

  let container =
    style([position(`relative), cursor(`default), display(`inlineBlock)]);

  let pillContents = (hovered, isActive) =>
    style([
      textAlign(`center),
      minWidth(`rem(5.)),
      opacity(0.7),
      visibility(hovered ? `hidden : `visible),
      color(isActive ? Theme.Colors.marine : Theme.Colors.midnight),
    ]);

  let hoverContainer =
    style([
      position(`absolute),
      top(`zero),
      right(`zero),
      bottom(`zero),
      left(`zero),
      display(`flex),
      justifyContent(`spaceBetween),
      padding2(~v=`zero, ~h=`rem(0.5)),
      color(white),
    ]);

  let copyButton =
    merge([
      Theme.Text.Body.regular,
      style([overflow(`hidden), opacity(0.9), hover([opacity(1.0)])]),
    ]);

  let editButton =
    merge([
      Theme.Text.Body.regular,
      style([opacity(0.5), hover([opacity(0.8)])]),
    ]);

  let editing =
    style([
      position(`absolute),
      top(`px(2)),
      right(`px(2)),
      bottom(`px(2)),
      left(`px(2)),
      backgroundColor(white),
      borderRadius(`px(2)),
    ]);

  let nameInput =
    merge([
      Theme.Text.Body.regular,
      style([
        textAlign(`center),
        outline(`px(0), `solid, white),
        border(`px(0), `solid, white),
        width(`percent(100.)),
        height(`percent(100.)),
        borderRadius(`px(2)),
        padding2(~v=`zero, ~h=`rem(0.25)),
      ]),
    ]);
};

[@react.component]
let make = (~pubkey) => {
  let activeAccount = Hooks.useActiveAccount();
  let (addressBook, updateAddressBook) =
    React.useContext(AddressBookProvider.context);
  let isActive = activeAccount === Some(pubkey);

  let (hovered, setHovered) = React.useState(() => false);
  let (editing, setEditing) = React.useState(() => false);

  let pillMode =
    switch (hovered, editing, isActive) {
    | (false, false, true) => Pill.Blue
    | (false, false, false) => Pill.Grey
    | (true, _, _)
    | (_, true, _) => Pill.DarkBlue
    };

  let handleEnter = e => {
    switch (ReactEvent.Keyboard.which(e)) {
    | 13 =>
      setEditing(_ => false);
      setHovered(_ => false);
    | _ => ()
    };
  };

  let handleNameChange = e =>
    updateAddressBook(
      AddressBook.set(~key=pubkey, ~name=ReactEvent.Form.target(e)##value),
    );

  let handleClipboard = _ =>
    ignore @@
    Bindings.Navigator.Clipboard.writeText(PublicKey.toString(pubkey));

  <div
    className=Styles.container
    onClick={e => ReactEvent.Mouse.stopPropagation(e)}
    onMouseEnter={_ => setHovered(_ => true)}
    onMouseLeave={_ => setHovered(_ => false)}>
    <Pill mode=pillMode>
      <span className={Styles.pillContents(hovered, isActive)}>
        <AccountName pubkey />
      </span>
    </Pill>
    {switch (hovered, editing) {
     | (true, false) =>
       <div className=Styles.hoverContainer>
         <span className=Styles.copyButton onClick=handleClipboard>
           {React.string("Copy")}
         </span>
         <span
           onClick={_ => setEditing(_ => true)} className=Styles.editButton>
           {React.string("Edit")}
         </span>
       </div>
     | (_, true) =>
       <div className=Styles.editing>
         <input
           className=Styles.nameInput
           autoFocus=true
           onKeyPress=handleEnter
           onBlur={_ => setEditing(_ => false)}
           onChange=handleNameChange
           value={
             AddressBook.lookup(addressBook, pubkey)
             |> Option.withDefault(~default="")
           }
         />
       </div>
     | (false, false) => React.string("")
     }}
  </div>;
};
