const { Client } = require("pg");

const client = new Client({
  user: "postgres",
  host: "localhost",
  database: "archive",
  password: "foobar",
  port: 5432,
});
client.connect();

client.query("SELECT * FROM blocks", (err, res) => {
  console.log(err, res);
  client.end();
});
