# Mina Block Producer Metrics Sidecar

This is a simple sidecar that communicates with Mina nodes to ship off uptime data for analysis.

Unless you're a founding block producer, you shouldn't need to run this sidecar, and you'll need to talk with the Mina team to get a special URL to make it work properly.

## Configuration

The sidecar takes 2 approaches to configuration, a pair of envars, or a configuration file. 

**Note**: Environment variables always take precedence, even if the config file is available and valid. 

#### Envars
- `MINA_BP_UPLOAD_URL` - The URL to upload block producer statistics to
- `MINA_NODE_URL` - The URL that the sidecar will reach out to to get statistics from

#### Config File
[config-file]: #config-file
The mina metrics sidecar will also look at `/etc/mina-sidecar.json` for its configuration variables, and the file should look like this:

```
{
  "uploadURL": "https://your.upload.url.here?token=someToken", 
  "nodeURL": "https://your.mina.node.here:4321"
}
```

The `uploadURL` parameter should be given to you by the Mina engineers

## Running with Docker
Running in docker should be as straight forward as running any other docker image. 

#### Pulling from dockerhub
We push updates to `minaprotocol/mina-bp-stats-sidecar:latest` so you can simply run the following to pull the image down:

```
$ docker pull minaprotocol/mina-bp-stats-sidecar:latest
```

#### Building locally
This is un-necessary if you use the version from dockerhub (which is recommended).

If you want to build this image yourself though, you can run `docker build -t mina-sidecar .` in this folder to build the image while naming it "mina-sidecar". 

You should then substitute that in lieu of `minaprotocol/mina-bp-stats-sidecar:latest` for the rest of the commands below.

#### Running with envars
```bash
$ docker run --rm -it -e MINA_BP_UPLOAD_URL=https://some-url-here -e MINA_NODE_URL=https://localhost:4321 minaprotocol/mina-bp-stats-sidecar:latest
```

#### Running with a config file
```bash
$ docker run --rm -it -v $(pwd)/mina-sidecar.json:/etc/mina-sidecar.json minaprotocol/mina-bp-stats-sidecar:latest
```
#### You can even bake your own docker image with the config file already in it
```bash
# Copy the example and make edits
$ cp mina-sidecar-example.json mina-sidecar.json
$ vim mina-sidecar.json # Make edits to the config
# Create custom Dockerfile
$ cat <<EOF > Dockerfile.custom
FROM minaprotocol/mina-bp-stats-sidecar:latest
COPY your_custom_config.conf /etc/mina-sidecar.json
EOF
$ docker build -t your-custom-sidecar -f Dockerfile.custom .
$ docker run --rm -it your-custom-sidecar
```

## Running with debian package

Running the sidecar as a debian package is as simple as installing the package, editing the config file, and enabling the service.

#### Installing the package

This package will install 3 files:

- `/usr/local/bin/mina-bp-stats-sidecar` (the mina sidecar program)
- `/etc/mina-sidecar.json` (the config file for the mina sidecar)
- `/etc/systemd/system/mina-bp-stats-sidecar.service` (the systemd config to run it as a service)

Installing the deb directly should be done with `apt install`, which will install the dependencies along side the service:

```
$ apt install ./mina-bp-stats-sidecar.deb
```

If you prefer to use `dpkg`, you can do so after installing the dependencies:

```
$ apt-get update && apt-get install python3 python3-certifi
$ dpkg -i ./mina-bp-stats-sidecar.deb
```

#### Configuring and Running

See the [Config File](#config-file) section above for what should be in the `/etc/mina-sidecar.json` file.

To (optionally) enable the service to run on reboot you can use:

```
$ systemctl enable mina-bp-stats-sidecar
```

Then to start the service itself:

```
$ service mina-bp-stats-sidecar start
```

From there you can check that it's running and see the most recent logs with `service mina-bp-stats-sidecar status`:

```
$ service mina-bp-stats-sidecar status
● mina-bp-stats-sidecar.service - Mina Block Producer Stats Sidecar
   Loaded: loaded (/etc/systemd/system/mina-bp-stats-sidecar.service; disabled; vendor preset: enabled)
   Active: active (running) since Fri 2021-03-12 02:43:37 CET; 3s ago
 Main PID: 1906 (python3)
    Tasks: 1 (limit: 2300)
   CGroup: /system.slice/mina-bp-stats-sidecar.service
           └─1906 python3 /usr/local/bin/mina-bp-stats-sidecar

INFO:root:Found /etc/mina-sidecar.json on the filesystem, using config file
INFO:root:Starting Mina Block Producer Sidecar
INFO:root:Fetching block 2136...
INFO:root:Got block data
INFO:root:Finished! New tip 2136...
```

#### Monitoring/Logging

If you want to get logs from the sidecar service, you can use `journalctl`:

```
# Similar to "tail -f" for the sidecar service
$ journalctl -f -u mina-bp-stats-sidecar.service
```

## Issues

#### HTTP error 400 

If you get a 400 while running your sidecar:

```
INFO:root:Fetching block 2136...
INFO:root:Got block data
ERROR:root:HTTP Error 400: Bad Request

-- TRACEBACK --

ERROR:root:Sleeping for 30s and trying again
```

It likely means you're shipping off data to the ingest pipeline without any block producer key configured on your Mina node - since your BP key is your identity we can't accept node data since we don't know who is submitting it!
