"use strict";

const sgMail = require("@sendgrid/mail");
const sendgrid = require("@sendgrid/client");
const Cryptr = require("cryptr");
const qs = require("querystring");

const { SENDGRID_APIKEY, TEMPLATE_ID, CRYPTR_SECRET, URL } = process.env;
const cryptr = new Cryptr(CRYPTR_SECRET);

sgMail.setApiKey(SENDGRID_APIKEY);
sendgrid.setApiKey(SENDGRID_APIKEY);

module.exports.sendConfirmation = async (event) => {
  if (event.httpMethod !== "POST" || !event.body) {
    return {
      statusCode: 400,
      body: "No email address was provided.",
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
      },
    };
  }

  // We must encrypt the email to prevent an attacker from
  // registering arbitrary emails by spamming confirmEmail
  const data = qs.parse(event.body);
  const encryptedEmail = cryptr.encrypt(data.email);

  const message = {
    to: data.email,
    from: {
      email: "no-reply@minaprotocol.com",
      name: "Mina Protocol",
    },
    templateId: TEMPLATE_ID,
    dynamic_template_data: {
      url: `${URL}/confirm?token=${encryptedEmail}`,
    },
  };

  try {
    await sgMail.send(message);
  } catch (e) {
    console.error(e);
    return {
      statusCode: 500,
      body: "",
    };
  }

  return {
    statusCode: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "Origin, X-Requested-With, Content-Type, Accept",
      "Content-Type": "application/json",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Max-Age": "2592000",
      "Access-Control-Allow-Credentials": "true",
    },
    body: "Please check your email",
  };
};

module.exports.confirmEmail = async (event) => {
  const encryptedEmail = event.queryStringParameters.token;

  if (!encryptedEmail) {
    return {
      statusCode: 400,
      body: "Invalid confirmation token.",
    };
  }

  const email = cryptr.decrypt(encryptedEmail);

  const newContactRequest = {
    method: "POST",
    url: "/v3/marketing/contacts",
    body: {
      list_ids: ["bcd755f4-53e9-4182-8c16-06d763408ffb"],
      contacts: [{ email }],
    },
  };

  try {
    await sendgrid.request(newContactRequest);
  } catch (e) {
    console.error(e);
    return {
      statusCode: 500,
      body: "",
    };
  }

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "text/html",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Credentials": "true",
    },
    body:
      '<html><head><meta http-equiv="Refresh" content="3; url=https://minaprotocol.com"></head><body><p>Thanks for subscribing!</p><p>You will be redirected shortly. If you are not redirected click <a href="https://minaprotocol.com">here</a>.</p></body></html>',
  };
};
