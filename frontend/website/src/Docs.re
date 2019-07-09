let extraHeaders = () => <> {Head.legacyStylesheets()} </>;

module Styles = {
  open Css;

  let markdownStyles =
    style([
      position(`relative),
      selector(
        "h1, h2, h3",
        [
          display(`flex),
          marginTop(rem(1.)),
          marginBottom(`rem(0.5)),
          hover([selector(".headerlink", [display(`inlineBlock)])]),
        ],
      ),
      selector(
        ".headerlink",
        [
          display(`none),
          width(rem(1.)),
          height(rem(1.)),
          marginLeft(rem(0.5)),
          color(`transparent),
          hover([color(`transparent)]),
          backgroundSize(`cover),
          backgroundImage(url("/static/img/link.svg")),
        ],
      ),
      selector("h1", Style.H1.heroStyles @ [alignItems(`baseline)]),
      selector("h2", Style.H2.basicStyles @ [alignItems(`baseline)]),
      selector(
        "h3",
        Style.H3.basicStyles @ [textAlign(`left), alignItems(`center)],
      ),
      selector("p", Style.Body.basicStyles),
      selector(
        "ul, ol",
        [
          margin(`zero),
          marginLeft(rem(1.5)),
          padding(`zero),
          ...Style.Body.basicStyles,
        ],
      ),
      selector(
        "code",
        [Style.Typeface.pragmataPro, color(Style.Colors.midnight)],
      ),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
      selector(
        "pre",
        [
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(9)),
          padding2(~v=`rem(0.5), ~h=`rem(1.)),
          overflow(`scroll),
        ],
      ),
      selector(
        "a",
        [
          hover([color(Style.Colors.hyperlinkHover)]),
          ...Style.Link.basicStyles,
        ],
      ),
    ]);

  let sideNav =
    style([
      minWidth(rem(15.)),
      selector("ul", [listStyleType(`none)]),
      selector("li > ul", [marginLeft(rem(1.))]),
      media(Style.MediaQuery.somewhatLarge, [marginTop(rem(2.))]),
    ]);
};

let component = ReasonReact.statelessComponent("Blog");

let make = _children => {
  ...component,
  render: _self =>
    <div
      className=Css.(
        merge([
          Styles.markdownStyles,
          style([
            display(`flex),
            flexDirection(`column),
            alignItems(`flexStart),
            justifyContent(`center),
            marginLeft(`auto),
            marginRight(`auto),
            media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
            media(Style.MediaQuery.somewhatLarge, [flexDirection(`row)]),
          ]),
        ])
      )>
      <aside
        className=Styles.sideNav
        dangerouslySetInnerHTML={
          "__html": {|
            {% if nav|length>1 %}
                <ul>
                {% for nav_item in nav %}
                    {% if nav_item.children %}
                        <li>{{ nav_item.title }}
                            <ul>
                            {% for nav_item in nav_item.children %}
                                <li class="{% if nav_item.active%}current{% endif %}">
                                    <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                                </li>
                            {% endfor %}
                            </ul>
                        </li>
                    {% else %}
                        <li class="{% if nav_item.active%}current{% endif %}">
                            <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                        </li>
                    {% endif %}
                {% endfor %}
                </ul>
            {% endif %}
          |},
        }
      />
      <article className=Css.(style([maxWidth(`rem(43.))]))>
        {ReasonReact.string("{{ page.content }}")}
      </article>
    </div>,
};
