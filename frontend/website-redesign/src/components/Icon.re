type kind =
  | World
  | Discord
  | Twitter
  | Facebook
  | Telegram
  | WeChat
  | Forums
  | Github
  | Wiki
  | Email
  | Location
  | ArrowUp
  | ArrowLeft
  | ArrowRight
  | ChevronDown
  | ChevronUp
  | ChevronRight
  | Info
  | Plus
  | ExternalLink
  | BulletPoint
  | Copy
  | NodeOperators
  | Developers
  | Documentation
  | GenesisProgram
  | GrantsProgram
  | Testnet
  | InstallSDK
  | CoreProtocol
  | Community
  | TechnicalGrants
  | SubmitYourOwn
  | Comet
  | CommunityGrants
  | Browser
  | BurgerMenu
  | CloseMenu
  | Box;

[@react.component]
let make = (~kind, ~size=?) => {
  let size =
    switch (size) {
    | Some(size) => size
    | None => "24"
    };

  switch (kind) {
  | World => <svg height=size width=size />
  | Discord => <svg height=size width=size />
  | Twitter => <svg height=size width=size />
  | Facebook => <svg height=size width=size />
  | Telegram => <svg height=size width=size />
  | WeChat => <svg height=size width=size />
  | Forums => <svg height=size width=size />
  | Github => <svg height=size width=size />
  | Wiki => <svg height=size width=size />
  | Email => <svg height=size width=size />
  | Location => <svg height=size width=size />
  | ArrowUp => <svg height=size width=size />
  | ArrowLeft => <svg height=size width=size />
  | ArrowRight => <svg height=size width=size />
  | ChevronDown => <svg height=size width=size />
  | ChevronUp => <svg height=size width=size />
  | ChevronRight => <svg height=size width=size />
  | Info => <svg height=size width=size />
  | Plus => <svg height=size width=size />
  | ExternalLink => <svg height=size width=size />
  | BulletPoint => <svg height=size width=size />
  | Copy => <svg height=size width=size />
  | NodeOperators => <svg height=size width=size />
  | Developers => <svg height=size width=size />
  | Documentation => <svg height=size width=size />
  | GenesisProgram => <svg height=size width=size />
  | GrantsProgram => <svg height=size width=size />
  | Testnet => <svg height=size width=size />
  | InstallSDK => <svg height=size width=size />
  | CoreProtocol => <svg height=size width=size />
  | Community => <svg height=size width=size />
  | TechnicalGrants => <svg height=size width=size />
  | SubmitYourOwn => <svg height=size width=size />
  | Comet => <svg height=size width=size />
  | CommunityGrants => <svg height=size width=size />
  | Browser => <svg height=size width=size />
  | BurgerMenu => <svg height=size width=size />
  | CloseMenu => <svg height=size width=size />
  | Box => <svg height=size width=size />
  };
};
