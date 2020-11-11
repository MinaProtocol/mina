module Styles = {
  open Css;
  let container = style([margin2(~v=`rem(4.), ~h=`zero)]);

  let modalContainer = modalShowing =>
    style([
      modalShowing ? opacity(1.) : opacity(0.),
      modalShowing ? pointerEvents(`auto) : pointerEvents(`none),
      transition("opacity", ~duration=400, ~timingFunction=`easeIn),
      position(`fixed),
      height(`vh(100.)),
      width(`vw(100.)),
      backgroundColor(`rgba((0, 0, 0, 0.3))),
      display(`flex),
      top(`percent(50.)),
      left(`percent(50.)),
      transform(`translate((`percent(-50.), `percent(-50.)))),
      zIndex(2),
    ]);

  let modal = style([margin(`auto)]);
};

type state = {
  memberIndex: int,
  currentMembers: array(ContentType.GenericMember.t),
};

type actions =
  | UpdateIndexAndCurrentMembers(
      ContentType.GenericMember.t,
      array(ContentType.GenericMember.t),
    )
  | UpdateMemberIndex(int)
  | OnPrevMemberPress
  | OnNextMemberPress;

let reducer = (prevState, action) => {
  switch (action) {
  | UpdateIndexAndCurrentMembers(member, members) =>
    let memberIndex =
      Belt.Array.getIndexBy(members, (m: ContentType.GenericMember.t) => {
        m.name == member.name
      });
    switch (memberIndex) {
    | Some(index) => {memberIndex: index, currentMembers: members}
    | None => prevState
    };

  | UpdateMemberIndex(index) => {...prevState, memberIndex: index}

  | OnPrevMemberPress =>
    prevState.memberIndex <= 0
      ? prevState : {...prevState, memberIndex: prevState.memberIndex - 1}

  | OnNextMemberPress =>
    prevState.memberIndex >= Array.length(prevState.currentMembers) - 1
      ? prevState : {...prevState, memberIndex: prevState.memberIndex + 1}
  };
};

external asDomElement: 'a => Dom.element = "%identity";
[@react.component]
let make =
    (~profiles, ~genesisMembers, ~advisors, ~modalOpen, ~switchModalState) => {
  let (state, dispatch) =
    React.useReducer(reducer, {memberIndex: 0, currentMembers: [||]});
  let modalBackgroundRef = React.useRef(Js.Nullable.null);

  let onPrevMemberPress = () => {
    dispatch(OnPrevMemberPress);
  };

  let onNextMemberPress = () => {
    dispatch(OnNextMemberPress);
  };

  let setCurrentIndexAndMembers = (member, members) => {
    dispatch(UpdateIndexAndCurrentMembers(member, members));
  };

  let closeModal = e => {
    modalBackgroundRef
    |> React.Ref.current
    |> Js.Nullable.toOption
    |> Option.iter(modalRef =>
         if (modalRef === asDomElement(ReactEvent.Mouse.target(e))
             && modalOpen) {
           switchModalState();
         }
       );
  };

  <>
    {Array.length(state.currentMembers) === 0
       ? React.null
       : <div
           className={Styles.modalContainer(modalOpen)}
           ref={modalBackgroundRef->ReactDOMRe.Ref.domRef}
           onClick={e => closeModal(e)}>
           <div className=Styles.modal>
             <ProfileCard
               member={Array.get(state.currentMembers, state.memberIndex)}
               switchModalState
               onPrevMemberPress
               onNextMemberPress
             />
           </div>
         </div>}
    <div className=Styles.container>
      <Wrapped>
        <Rule color=Theme.Colors.black />
        <TeamGrid profiles switchModalState setCurrentIndexAndMembers />
        <Rule color=Theme.Colors.black />
        <GenesisMembersGrid
          genesisMembers
          switchModalState
          setCurrentIndexAndMembers
        />
      </Wrapped>
    </div>
    <Investors advisors switchModalState setCurrentIndexAndMembers />
  </>;
};
