## "Tiny" The Mina Bot
Tiny is a discord bot, designed to be run in the Mina Protocol Discord Server. 

It is a *Mina Service*, meaning it is necessary to run this alongside a synced and operational *Mina Daemon*. 

## Environment Variables
`ECHO_PUBLICKEY`: Mina Public Key that corresponds to a installed wallet
`FAUCET_PUBLICKEY`: Mina Public Key that corresponds to a installed wallet
`DISCORD_API_KEY`: A Discord Bot API Key
`CODA_GRAPHQL_HOST`: Defaults to `localhost`, the hostname of the *Mina Daemon* 
`CODA_GRAPHQL_PORT`: Defaults to `0xc0d` (3085), the port the *Mina Daemon* is listening on 
