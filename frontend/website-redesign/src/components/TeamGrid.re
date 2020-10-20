module Styles = {
  open Css;
  let grid =
    style([
      display(`grid),
      paddingTop(`rem(1.)),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([
            `rem(10.),
            `rem(10.),
            `rem(10.),
            `rem(10.),
          ]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
          ]),
        ],
      ),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.grid>
    <TeamMember
      fullName="Evan Shapiro"
      title="CEO, O(1) Labs"
      src="/static/img/headshots/EvanShapiro.jpg"
    />
    <TeamMember
      fullName="Izaak Meckler"
      title="CTO, O(1) Labs"
      src="/static/img/headshots/IzaakMeckler.jpg"
    />
    <TeamMember
      fullName="Brandon Kase"
      title="Head of Product Engineering, O(1) Labs"
      src="/static/img/headshots/BrandonKase.jpg"
    />
    <TeamMember
      fullName="Claire Kart"
      title="Head of Marketing & Community, O(1) Labs"
      src="/static/img/headshots/ClaireKart.jpg"
    />
    <TeamMember
      fullName="Emre Tekisalp"
      title="Head of Business Development, O(1) Labs"
      src="/static/img/headshots/EmreTekisalp.jpg"
    />
    <TeamMember
      fullName="Bijan Shahrokhi"
      title="Product Manager, O(1) Labs"
      src="/static/img/headshots/BijanShahrokhi.jpg"
    />
    <TeamMember
      fullName="Aneesha Raines"
      title="Engineering Manager, O(1) Labs"
      src="/static/img/headshots/AneeshaRaines.jpeg"
    />
    <TeamMember
      fullName="Sherry Lin"
      title="Marketing Manager, O(1) Labs"
      src="/static/img/headshots/SherryLin.jpg"
    />
    <TeamMember
      fullName="Carey Janecka"
      title="Product Engineer, O(1) Labs"
      src="/static/img/headshots/CareyJanecka.jpg"
    />
    <TeamMember
      fullName="Kate El-Bizri"
      title="Visual Designer,  O(1) Labs"
      src="/static/img/headshots/KateElBizri2.jpg"
    />
    <TeamMember
      fullName="Deepthi Kumar"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/DeepthiKumar.jpg"
    />
    <TeamMember
      fullName="Paul Steckler"
      title="Protocol Engineer,   O(1) Labs"
      src="/static/img/headshots/PaulSteckler.jpg"
    />
    <TeamMember
      fullName="Jiawei Tang"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/JiaweiTang.jpg"
    />
    <TeamMember
      fullName="Nathan Holland"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/NathanHolland.jpg"
    />
    <TeamMember
      fullName="Matthew Ryan"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/MatthewRyan.jpg"
    />
    <TeamMember
      fullName="Ahmad Wilson"
      title="Protocol Reliability Engineer, O(1) Labs"
      src="/static/img/headshots/AhmadWilson.jpg"
    />
    <TeamMember
      fullName="Vanishree Rao"
      title="Protocol Researcher, O(1) Labs"
      src="/static/img/headshots/VanishreeRao.jpg"
    />
    <TeamMember
      fullName="Michelle Wong"
      title="Product Engineer, O(1) Labs"
      src="/static/img/headshots/MichelleWong.jpg"
    />
    <TeamMember
      fullName="Nacera Rodstein"
      title="Operations Associate, O(1) Labs"
      src="/static/img/headshots/NaceraRodstein.jpg"
    />
    <TeamMember
      fullName="Christine Yip"
      title="Community Manager, O(1) Labs"
      src="/static/img/headshots/ChristineYip.jpg"
    />
    <TeamMember
      fullName="Andrew Trainor"
      title="Protocol Engineer, O(1) Labs"
      src="/static/img/headshots/AndrewTrainor.jpg"
    />
    <TeamMember
      fullName="Helena Li"
      title="Protocol Engineer, O(1) Labs"
      src="/static/img/headshots/HelenaLi.jpg"
    />
    <TeamMember
      fullName="Chris Pryor"
      title="Lead Product Designer, O(1) Labs"
      src="/static/img/headshots/ChrisPryor.jpg"
    />
    <TeamMember
      fullName="Joon Kim"
      title="General Counsel, O(1) Labs"
      src="/static/img/headshots/JoonKim.jpg"
    />
  </div>;
};
