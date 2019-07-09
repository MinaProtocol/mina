let extraHeaders = () => <> {Head.legacyStylesheets()} </>;

module Styles = {
  open Css;

  let markdownStyles =
    style([
      selector("h1", Style.H1.heroStyles),
      selector("h3, h2", Style.H2.basicStyles),
      selector("p", Style.Body.basicStyles),
      selector("ul, ol", [
        margin(`zero),
        padding(`zero),
        ...Style.Body.basicStyles]),
      selector("code", Style.Body.Technical.basicStyles),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Style.Colors.slateAlpha(0.4)),
          borderRadius(`px(4)),
        ],
      ),
      selector(
        "pre",
        [
          backgroundColor(Style.Colors.slateAlpha(0.4)),
          borderRadius(`px(9)),
          padding(`rem(1.5)),
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
            alignItems(`stretch),
            maxWidth(`rem(43.)),
            marginLeft(`auto),
            marginRight(`auto),
            media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
          ]),
        ])
      )>
      <aside
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
                                    <a href="/docs/{{ nav_item.url|url }}/index.html">{{ nav_item.title }}</a>
                                </li>
                            {% endfor %}
                            </ul>
                        </li>
                    {% else %}
                        <li class="{% if nav_item.active%}current{% endif %}">
                            <a href="/docs/{{ nav_item.url|url }}/index.html">{{ nav_item.title }}</a>
                        </li>
                    {% endif %}
                {% endfor %}
                </ul>
            {% endif %}
          |},
        }
      />
      {ReasonReact.string("{{ page.content }}")}
    </div>,
};
