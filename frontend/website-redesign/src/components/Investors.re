module Styles = {
  open Css;
  let backgroundImage =
    style([
      backgroundSize(`cover),
      backgroundImage(url("/static/img/InvestorsBackgroundSmall.png")),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(url("/static/img/InvestorsBackgroundMedium.png"))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [backgroundImage(url("/static/img/InvestorsBackgroundLarge.png"))],
      ),
    ]);
  let container =
    style([
      display(`grid),
      gridTemplateColumns([`rem(11.), `rem(11.)]),
      gridAutoRows(`rem(5.5)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.backgroundImage>
    <div className=Styles.container>
      <img src="/static/img/logos/LogoAccomplice.png" />
      <img src="/static/img/logos/LogoBlockchange.png" />
      <img src="/static/img/logos/LogoCoinbaseVentures.png" />
      <img src="/static/img/logos/LogoCollaborativeFund.png" />
      <img src="/static/img/logos/LogoCuriousEndeavors.png" />
      <img src="/static/img/logos/LogoDekyrptCapital.png" />
      <img src="/static/img/logos/LogoDragonfly.png" />
      <img src="/static/img/logos/LogoElectricCapital.png" />
      <img src="/static/img/logos/LogoEvolveVC.png" />
      <img src="/static/img/logos/LogoGeneralCatalyst.png" />
      <img src="/static/img/logos/LogoKilowattCapital.png" />
      <img src="/static/img/logos/LogoKindredVentures.png" />
      <img src="/static/img/logos/LogoLibertusCapital.png" />
      <img src="/static/img/logos/LogoMetastable.png" />
      <img src="/static/img/logos/LogoMulticoinCapital.png" />
      <img src="/static/img/logos/LogoNimaCapital.png" />
      <img src="/static/img/logos/LogoParadigm.png" />
      <img src="/static/img/logos/LogoPolychainCapital.png" />
      <img src="/static/img/logos/LogoScifiVC.png" />
    </div>
  </div>;
};
