module Styles = {
  open Css;
  let backgroundImage =
    style([
      backgroundSize(`cover),
      backgroundImage(url("/static/img/InvestorsBackgroundMobile.png")),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(url("/static/img/InvestorsBackgroundTablet.png"))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          backgroundImage(url("/static/img/InvestorsBackgroundDesktop.png")),
        ],
      ),
    ]);
  let investorGrid =
    style([
      display(`grid),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(5.5)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`repeat((`num(4), `rem(10.)))])],
      ),
    ]);
  let innerContainer =
    style([paddingTop(`rem(4.)), paddingLeft(`rem(1.25))]);
  let header = merge([Theme.Type.h2, style([marginBottom(`rem(0.5))])]);
  let subhead =
    merge([Theme.Type.sectionSubhead, style([marginBottom(`rem(4.))])]);
};

[@react.component]
let make = () => {
  <div className=Styles.backgroundImage>
    <div className=Styles.innerContainer>
      <h2 className=Styles.header> {React.string("Investors")} </h2>
      <p className=Styles.subhead> {React.string("Supporting O(1) Labs")} </p>
      <div className=Styles.investorGrid>
        <img src="/static/img/logos/LogoAccomplice.png" />
        <img src="/static/img/logos/LogoBlockchange.png" />
        <img src="/static/img/logos/LogoCoinbaseVentures.png" />
        <img src="/static/img/logos/LogoCollaborativeFund.png" />
        <img src="/static/img/logos/LogoCuriousEndeavors.png" />
        <img src="/static/img/logos/LogoDekryptCapital.png" />
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
    </div>
  </div>;
};
