module Styles = {
  open Css;

  let container =
    merge([
      Style.Body.basic_semibold,
      style([
        position(`relative),
        width(`percent(100.)),
        fontWeight(`normal),
        media(Style.MediaQuery.notMobile, [width(`auto)]),
      ]),
    ]);

  let successMessage =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      position(`absolute),
      bottom(`zero),
      left(`zero),
      height(px(40)),
      width(px(400)),
      background(white),
      border(px(1), `solid, Style.Colors.jungle),
      color(Style.Colors.jungle),
      borderRadius(px(4)),
      visibility(`hidden),
      opacity(0.),
      transition("all", ~duration=150),
    ]);

  let textField =
    style([
      display(`inlineFlex),
      alignItems(`center),
      height(px(40)),
      borderRadius(px(4)),
      width(`percent(100.)),
      color(Style.Colors.teal),
      padding(px(12)),
      border(px(1), `solid, Style.Colors.hyperlinkAlpha(0.3)),
      active([
        outline(px(0), `solid, `transparent),
        borderColor(Style.Colors.hyperlinkAlpha(0.7)),
      ]),
      focus([
        outline(px(0), `solid, `transparent),
        borderColor(Style.Colors.hyperlinkAlpha(0.7)),
      ]),
      media(Style.MediaQuery.notMobile, [width(px(272))]),
    ]);

  let submit =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`center),
      color(white),
      backgroundColor(Style.Colors.jungle),
      border(px(0), `solid, `transparent),
      marginTop(`rem(0.5)),
      marginLeft(`zero),
      height(px(40)),
      width(px(120)),
      borderRadius(px(4)),
      cursor(`pointer),
      active([outline(px(0), `solid, `transparent)]),
      focus([outline(px(0), `solid, `transparent)]),
      disabled([backgroundColor(Style.Colors.slateAlpha(0.3))]),
      media(
        Style.MediaQuery.notMobile,
        [marginLeft(`rem(0.5)), marginTop(`zero)],
      ),
    ]);
};

let widgetCounter = ref(0);
let uniqueId = () => {
  widgetCounter := widgetCounter^ + 1;
  string_of_int(widgetCounter^);
};

[@react.component]
let make = () => {
  let formId = uniqueId();
  <form id={"subscribe-form-" ++ formId} className=Styles.container>
    <div className=Css.(style([marginBottom(px(8))]))>
      {React.string("Subscribe to our newsletter for updates")}
    </div>
    <div id={"success-message-" ++ formId} className=Styles.successMessage>
      {React.string({js|✓ Check your email|js})}
    </div>
    <input
      type_="email"
      name="email"
      placeholder="janedoe@example.com"
      className=Styles.textField
    />
    <input
      type_="submit"
      value="Subscribe"
      id={"subscribe-button-" ++ formId}
      className=Styles.submit
    />
    <RunScript>
      {j|
            document.getElementById('subscribe-form-$formId '.trim()).onsubmit = function (e) {
              e.preventDefault();
              const formElement = document.getElementById('subscribe-form-$formId '.trim());
              const request = new XMLHttpRequest();
              const submitButton = document.getElementById('subscribe-button-$formId '.trim());
              submitButton.setAttribute('disabled', 'disabled');
              request.onload = function () {
                const successMessage = document.getElementById('success-message-$formId '.trim());
                successMessage.style.visibility = "visible";
                successMessage.style.opacity = 1;
                setTimeout(function () {
                  submitButton.removeAttribute('disabled');
                  successMessage.style.visibility = "hidden";
                  successMessage.style.opacity = 0;
                }, 5000);
              };
              request.open("POST", "https://jfs501bgik.execute-api.us-east-2.amazonaws.com/dev/subscribe");
              request.send(new URLSearchParams(new FormData(formElement)));
              return false;
            }
          |j}
    </RunScript>
  </form>;
};
