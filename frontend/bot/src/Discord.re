module Snowflake = {
  type t;
  external toString: t => string = "%identity";
};

module Collection = {
  type t('k, 'v);
  [@bs.send] external get: (t('k, 'v), 'k) => option('v) = "get";
  [@bs.send] external find: (t('k, 'v), 'v => bool) => option('v) = "find";
};

module Channel = {
  type t;
  [@bs.get] external channelType: t => string = "type";
  [@bs.get] external id: t => Snowflake.t = "id";
};

module TextChannel = {
  type t;
  external fromChannelUnsafe: Channel.t => t = "%identity";
  let fromChannel = (c: Channel.t): option(t) =>
    Channel.channelType(c) == "text" ? Some(fromChannelUnsafe(c)) : None;
  [@bs.get] external name: t => string = "name";
};

module User = {
  type t;
  [@bs.get] external id: t => Snowflake.t = "id";
  [@bs.get] external username: t => string = "username";
  [@bs.get] external bot: t => bool = "bot";
};

module Role = {
  type t;
  [@bs.get] external name: t => string = "name";
};

module GuildMember = {
  type t;
  [@bs.get] external user: t => User.t = "user";
  [@bs.get] external roles: t => Collection.t(Snowflake.t, Role.t) = "roles";
};

module Message = {
  type t;
  [@bs.get] external content: t => string = "content";
  [@bs.get] external channel: t => Channel.t = "channel";
  [@bs.send] external reply: (t, string) => unit = "reply";
  [@bs.get] external author: t => User.t = "author";
  [@bs.get] external member: t => option(GuildMember.t) = "member";
};

module Client = {
  type t;
  [@bs.module "discord.js"] [@bs.new]
  external createClient: unit => t = "Client";
  [@bs.send] external login: (t, string) => unit = "login";
  [@bs.send]
  external onReady: (t, [@bs.as "ready"] _, unit => unit) => unit = "on";
  [@bs.send]
  external onMessage: (t, [@bs.as "message"] _, Message.t => unit) => unit =
    "on";
};
