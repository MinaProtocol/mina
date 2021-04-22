# nix-shell -p python3 python3Packages.requests python3Packages.pip python3Packages.readchar python3Packages.jinja2 python3Packages.click python3Packages.natsort python3Packages.docker python3Packages.inflect
#
import docker
import inflect
import os
import subprocess
from pathlib import Path
import click
import glob
import json
import csv
import natsort
client = docker.from_env()
p = inflect.engine()

MINA_DAEMON_IMAGE = "gcr.io/o1labs-192920/coda-daemon:1.0.0-fd39808"
SCRIPT_DIR = Path(__file__).parent.absolute()

# Default output folders for various kinds of keys
DEFAULT_ONLINE_WHALE_KEYS_DIR = SCRIPT_DIR / "online_whale_keys"
DEFAULT_OFFLINE_WHALE_KEYS_DIR = SCRIPT_DIR / "offline_whale_keys"
DEFAULT_OFFLINE_FISH_KEYS_DIR = SCRIPT_DIR / "offline_fish_keys"
DEFAULT_ONLINE_FISH_KEYS_DIR = SCRIPT_DIR / "online_fish_keys"
DEFAULT_SERVICE_KEY_DIR = SCRIPT_DIR / "service_keys"

DEFAULT_SEED_KEY_DIR = SCRIPT_DIR / "seed_libp2p_keys"
DEFAULT_STAKER_CSV_FILE = SCRIPT_DIR / "staker_public_keys.csv"

# A list of services to add and the percentage of total stake they should be allocated
DEFAULT_SERVICES = {"faucet": 100000 * (10**9), "echo": 100 * (10**9)}


def encode_nanocodas(nanocodas):
    s = str(nanocodas)
    if len(s) > 9:
        return s[:-9] + '.' + s[-9:]
    else:
        return '0.' + ('0' * (9 - len(s))) + s


@click.group()
@click.option('--debug/--no-debug', default=False)
def cli(debug):
    pass


@cli.group()
def keys():
    pass


@cli.group()
def ledger():
    pass


@cli.group()
def aws():
    pass


@cli.group()
def k8s():
    pass


###
# Commands for generating Coda Keypairs
###


@keys.command()
@click.option('--output-dir',
              default=DEFAULT_SERVICE_KEY_DIR.absolute(),
              help='Directory to output Public Keys to.')
@click.option('--privkey-pass',
              default="naughty blue worm",
              help='The password to use when generating keys.')
def generate_service_keys(output_dir, privkey_pass):
    """Generate Public Keys for Services."""

    # Create Block Producer Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for service in DEFAULT_SERVICES.keys():
        # key outputted to file
        pubkey = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=[
                "CODA_PRIVKEY_PASS='{}' mina advanced generate-keypair -privkey-path /keys/{}_service"
                .format(privkey_pass, service)
            ],
            volumes={output_dir: {
                'bind': '/keys',
                'mode': 'rw'
            }})
        print(pubkey)


@keys.command()
@click.option('--count',
              default=5,
              help='Number of Block Producer keys to generate.')
@click.option('--output-dir',
              default=DEFAULT_ONLINE_WHALE_KEYS_DIR.absolute(),
              help='Directory to output Public Keys to.')
@click.option('--privkey-pass',
              default="naughty blue worm",
              help='The password to use when generating keys.')
def generate_online_whale_keys(count, output_dir, privkey_pass):
    """Generate Public Keys for Online Whale Block Producers."""
    # Create Block Producer Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        whale_key = i + 1

        # key outputted to file
        pubkey = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=[
                "CODA_PRIVKEY_PASS='{}' mina advanced generate-keypair -privkey-path /keys/online_whale_account_{}"
                .format(privkey_pass, whale_key)
            ],
            volumes={output_dir: {
                'bind': '/keys',
                'mode': 'rw'
            }})
        print(pubkey)


@keys.command()
@click.option('--count',
              default=5,
              help='Number of Whale Account keys to generate.')
@click.option('--output-dir',
              default=DEFAULT_OFFLINE_WHALE_KEYS_DIR.absolute(),
              help='Directory to output Whale Account Keys to.')
@click.option('--privkey-pass',
              default="naughty blue worm",
              help='The password to use when generating keys.')
def generate_offline_whale_keys(count, output_dir, privkey_pass):
    """Generate Public Keys for Offline Whale Accounts"""
    # Create Whale Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        whale_number = i + 1

        # key outputted to file
        pubkey = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=[
                "CODA_PRIVKEY_PASS='{}' mina advanced generate-keypair -privkey-path /keys/offline_whale_account_{}"
                .format(privkey_pass, i + 1)
            ],
            volumes={output_dir: {
                'bind': '/keys',
                'mode': 'rw'
            }})
        print(pubkey)


@keys.command()
@click.option('--count',
              default=10,
              help='Number of Fish Account keys to generate.')
@click.option('--output-dir',
              default=DEFAULT_OFFLINE_FISH_KEYS_DIR.absolute(),
              help='Directory to output Fish Account Keys to.')
@click.option('--privkey-pass',
              default="naughty blue worm",
              help='The password to use when generating keys.')
def generate_offline_fish_keys(count, output_dir, privkey_pass):
    """Generate Public Keys for Offline Fish Accounts"""
    # Create Whale Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        fish_number = i + 1

        # key outputted to file
        pubkey = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=[
                "CODA_PRIVKEY_PASS='{}' mina advanced generate-keypair -privkey-path /keys/offline_fish_account_{}"
                .format(privkey_pass, fish_number)
            ],
            volumes={output_dir: {
                'bind': '/keys',
                'mode': 'rw'
            }},
            detach=True)
        print("Generating Offline Fish Key #{}".format(fish_number))


@keys.command()
@click.option('--count',
              default=10,
              help='Number of Fish Account keys to generate.')
@click.option('--output-dir',
              default=DEFAULT_ONLINE_FISH_KEYS_DIR.absolute(),
              help='Directory to output Fish Account Keys to.')
@click.option('--privkey-pass',
              default="naughty blue worm",
              help='The password to use when generating keys.')
def generate_online_fish_keys(count, output_dir, privkey_pass):
    """Generate Public Keys for Online Fish Accounts"""
    # Create Whale Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        fish_number = i + 1

        # key outputted to file
        pubkey = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=[
                "CODA_PRIVKEY_PASS='{}' mina advanced generate-keypair -privkey-path /keys/online_fish_account_{}"
                .format(privkey_pass, fish_number)
            ],
            volumes={output_dir: {
                'bind': '/keys',
                'mode': 'rw'
            }},
            detach=True)
        print("Generating Online Fish Key #{}".format(fish_number))


#####
# Commands for generating LibP2P Keypairs
#####


@keys.command()
@click.option('--count',
              default=1,
              help='Number of Seed Libp2p keys to generate.')
@click.option('--output-dir',
              default=DEFAULT_SEED_KEY_DIR.absolute(),
              help='Directory to output LibP2P keys to.')
def generate_seed_keys(count, output_dir):
    """Generate LibP2P Keys for Seed Nodes"""
    SEED_KEYS_DIR = output_dir
    # Create Seed Node LibP2P Keys
    Path(SEED_KEYS_DIR).mkdir(parents=True, exist_ok=True)

    for i in range(0, 3):
        seed_number = p.number_to_words(i + 1)

        # Key outputted to stdout
        key_raw = client.containers.run(
            MINA_DAEMON_IMAGE,
            entrypoint="bash -c",
            command=["mina advanced generate-libp2p-keypair"])
        key_parsed = str(key_raw).split("\\n")[1]
        all_key_file = open(
            SEED_KEYS_DIR / "seed_{}_libp2p.txt".format(seed_number), "w")

        client_id = copy(key_parsed).split(",")[2]
        client_id_file = open(
            SEED_KEYS_DIR / "seed_{}_client_id.txt".format(seed_number), "w")
        # Write Key to file
        all_key_file.write(key_parsed)
        client_id_file.write(client_id)
        print(client_id)


#####
# Commands related to Genesis Ledger Creation
#####


@ledger.command()
# Global Params
@click.option(
    '--generate-remainder',
    default=False,
    help=
    'Indicates that keys should be generated if there are not a sufficient number of keys present.'
)
# Service Account Params
@click.option('--service-accounts-directory',
              default=DEFAULT_SERVICE_KEY_DIR.absolute(),
              help='Directory where Service Account Keys will be stored.')
# Whale Account Params
@click.option('--num-whale-accounts',
              default=5,
              help='Number of Whale accounts to be generated.')
@click.option('--online-whale-accounts-directory',
              default=DEFAULT_ONLINE_WHALE_KEYS_DIR.absolute(),
              help='Directory where Offline Whale Account Keys will be stored.'
              )
@click.option('--offline-whale-accounts-directory',
              default=DEFAULT_OFFLINE_WHALE_KEYS_DIR.absolute(),
              help='Directory where Offline Whale Account Keys will be stored.'
              )
# Fish Account Params
@click.option('--num-fish-accounts',
              default=10,
              help='Number of Fish accounts to be generated.')
@click.option('--online-fish-accounts-directory',
              default=DEFAULT_ONLINE_FISH_KEYS_DIR.absolute(),
              help='Directory where Online Fish Account Keys will be stored.')
@click.option('--offline-fish-accounts-directory',
              default=DEFAULT_OFFLINE_FISH_KEYS_DIR.absolute(),
              help='Directory where Offline Fish Account Keys will be stored.')
# Community Staker Account Params
@click.option(
    '--staker-csv-file',
    help=
    'Location of a CSV file detailing Discord Username and Public Key for Stakers.'
)
def generate_ledger(generate_remainder, service_accounts_directory,
                    num_whale_accounts, online_whale_accounts_directory,
                    offline_whale_accounts_directory, num_fish_accounts,
                    online_fish_accounts_directory,
                    offline_fish_accounts_directory, staker_csv_file):
    """
    Generates a Genesis Ledger based on previously generated Whale, Fish, and Block Producer keys.
    If keys are not present on the filesystem at the specified location, they are not generated.
    """

    ledger_public_keys = {
        "service_keys": [],
        "online_whale_keys": [],
        "offline_whale_keys": [],
        "online_fish_keys": [],
        "offline_fish_keys": [],
        "online_staker_keys": [],
        "stakers": []
    }

    # Try loading Service keys
    service_accounts_directory = Path(service_accounts_directory)
    service_key_files = glob.glob(
        str(service_accounts_directory.absolute()) + "/*.pub")
    print("Processing Service Keys -- loaded {} service keys".format(
        len(service_key_files)))
    # load Service Key Contents
    for service_key_file in service_key_files:
        service_name = os.path.basename(service_key_file).split("_")[0]
        service_balance = DEFAULT_SERVICES[service_name]
        fd = open(service_key_file, "r")
        service_public_key = fd.readline().strip()
        ledger_public_keys["service_keys"].append({
            "public_key": service_public_key,
            "service": service_name,
            "balance": service_balance
        })

        fd.close()

    # Try loading offline whale keys
    offline_whale_accounts_directory = Path(offline_whale_accounts_directory)
    offline_whale_key_files = glob.glob(
        str(offline_whale_accounts_directory.absolute()) + "/*.pub")
    if len(offline_whale_key_files) >= num_whale_accounts:
        print(
            "Processing Offline Whale Keys -- {} keys required, loaded {} whale keys"
            .format(num_whale_accounts, len(offline_whale_key_files)))
        # load Whale Key Contents
        for whale_key_file in offline_whale_key_files:
            fd = open(whale_key_file, "r")
            whale_public_key = fd.readline().strip()
            ledger_public_keys["offline_whale_keys"].append(whale_public_key)
            fd.close()
    else:
        raise Exception(
            "There aren't enough Offline Whale Keys to populate the genesis ledger! Required {}, Present {}"
            .format(num_whale_accounts, len(offline_whale_key_files)))

    # Try loading online whale keys
    online_whale_accounts_directory = Path(online_whale_accounts_directory)
    online_whale_key_files = glob.glob(
        str(online_whale_accounts_directory.absolute()) + "/*.pub")
    if len(online_whale_key_files) >= num_whale_accounts:
        print(
            "Processing Online Whale Keys -- {} keys required, loaded {} whale keys"
            .format(num_whale_accounts, len(online_whale_key_files)))
        # load Whale Key Contents
        for whale_key_file in online_whale_key_files:
            fd = open(whale_key_file, "r")
            whale_public_key = fd.readline().strip()
            ledger_public_keys["online_whale_keys"].append(whale_public_key)
            fd.close()
    else:
        raise Exception(
            "There aren't enough Online Whale Keys to populate the genesis ledger! Required {}, Present {}"
            .format(num_whale_accounts, len(online_whale_key_files)))

    # Try Loading Offline Fish Keys
    offline_fish_accounts_directory = Path(offline_fish_accounts_directory)
    offline_fish_key_files = glob.glob(
        str(offline_fish_accounts_directory.absolute()) + "/*.pub")
    if len(offline_fish_key_files) >= num_fish_accounts:
        print(
            "Processing Offline Fish Keys -- {} keys required, loaded {} fish keys"
            .format(num_fish_accounts, len(offline_fish_key_files)))
        for fish_key_file in offline_fish_key_files:
            fd = open(fish_key_file, "r")
            fish_public_key = fd.readline().strip()
            ledger_public_keys["offline_fish_keys"].append(fish_public_key)

            fd.close()
    else:
        raise Exception(
            "There aren't enough Offline Fish Keys to populate the genesis ledger! Required {}, Present {}"
            .format(num_fish_accounts, len(offline_fish_key_files)))
    import itertools

    # If a CSV is passed as input, use the staker public keys
    if staker_csv_file is not None:
        # Load contents of Online Staker Keys CSV
        with open(Path(staker_csv_file).absolute(), newline='') as csvfile:
            reader = csv.reader(csvfile, delimiter=',', quotechar='|')
            for row in itertools.islice(reader, num_fish_accounts):
                discord_username = row[1]
                public_key = row[2]
                ## TODO: Check the key format better here
                if public_key.startswith("4vsRC"):
                    ledger_public_keys["online_staker_keys"].append(public_key)
                    ledger_public_keys["stakers"].append({
                        "nickname":
                        discord_username,
                        "public_key":
                        public_key
                    })
    # If no CSV passed as input, use the online_fish_keys
    else:
        online_fish_accounts_directory = Path(online_fish_accounts_directory)
        online_fish_key_files = glob.glob(
            str(online_fish_accounts_directory.absolute()) + "/*.pub")
        if len(offline_fish_key_files) >= num_fish_accounts:
            print(
                "Processing Online Fish Keys -- {} keys required, loaded {} fish keys"
                .format(num_fish_accounts, len(online_fish_key_files)))
            for fish_key_file in online_fish_key_files[0:num_fish_accounts]:
                fd = open(fish_key_file, "r")
                fish_public_key = fd.readline().strip()
                ledger_public_keys["online_staker_keys"].append(
                    fish_public_key)
                ledger_public_keys["stakers"].append({
                    "nickname":
                    Path(fish_key_file).name,
                    "public_key":
                    fish_public_key
                })

                fd.close()
        else:
            raise Exception(
                "There aren't enough Online Fish Keys to populate the genesis ledger! Required {}, Present {}"
                .format(num_fish_accounts, len(online_fish_key_files)))

    #####################
    # GENERATE THE LEDGER
    #####################
    print("\n===Generating Genesis Ledger===")
    # {
    #   "name": "release",
    #   "num_accounts": 250,
    #   "accounts": [
    #         {
    #           "pk":public-key-string,
    #           "sk":optional-secret-key-string,
    #           "balance":int,
    #           "delegate": optional-public-key-string
    #         }
    #   ]
    # }
    ledger = []
    annotated_ledger = []

    # Service Accounts
    for service in ledger_public_keys["service_keys"]:
        ledger.append({
            "pk": service["public_key"],
            "sk": None,
            "balance": encode_nanocodas(service["balance"]),
            "delegate": None
        })

        annotated_ledger.append({
            "pk": service["public_key"],
            "sk": None,
            "balance": encode_nanocodas(service["balance"]),
            "delegate": None,
            "nickname": service["service"]
        })

    # Check that there are enough fish keys for all stakers
    if len(ledger_public_keys["offline_fish_keys"]) >= len(
            ledger_public_keys["online_staker_keys"]):
        print(
            "There is a sufficient number of Fish Keys -- {} fish keys, {} stakers"
            .format(num_fish_accounts,
                    len(ledger_public_keys["online_staker_keys"])))

    fish_offline_balance = encode_nanocodas(65500 * (10**9))
    fish_online_balance = encode_nanocodas(500 * (10**9))

    # Fish Accounts
    for index, fish in enumerate(ledger_public_keys["offline_fish_keys"]):
        try:
            ledger.append({
                "pk":
                fish,
                "sk":
                None,
                "balance":
                fish_offline_balance,
                "delegate":
                ledger_public_keys["stakers"][index]["public_key"]
            })
            ledger.append({
                "pk":
                ledger_public_keys["stakers"][index]["public_key"],
                "sk":
                None,
                "delegate":
                None,
                "balance":
                fish_online_balance
            })
            annotated_ledger.append({
                "pk":
                fish,
                "sk":
                None,
                "balance":
                fish_offline_balance,
                "delegate":
                ledger_public_keys["stakers"][index]["public_key"],
                "nickname":
                ledger_public_keys["stakers"][index]["nickname"]
            })
            annotated_ledger.append({
                "pk":
                ledger_public_keys["stakers"][index]["public_key"],
                "sk":
                None,
                "balance":
                fish_online_balance,
                "delegate":
                None,
                "nickname":
                ledger_public_keys["stakers"][index]["nickname"]
            })
        # This will occur if there are less staker keys than there are fish keys
        except IndexError:
            # Delegate remainder keys to block producer one
            remainder_index = len(
                ledger_public_keys["offline_fish_keys"]) - len(
                    ledger_public_keys["stakers"]) - 1
            break

    # Check that there are enough whale keys for all block producers
    if len(ledger_public_keys["offline_whale_keys"]) >= len(
            ledger_public_keys["online_whale_keys"]):
        print(
            "There is a sufficient number of Whale Keys -- {} offline whale keys, {} online whale keys"
            .format(num_whale_accounts,
                    len(ledger_public_keys["online_whale_keys"])))

    whale_offline_balance = 66000 * 175 * (10**9)

    # Whale Accounts
    for index, offline_whale in enumerate(
            ledger_public_keys["offline_whale_keys"]):
        try:
            ledger.append({
                "pk":
                offline_whale,
                "sk":
                None,
                "balance":
                encode_nanocodas(whale_offline_balance),
                "delegate":
                ledger_public_keys["online_whale_keys"][index]
            })
            ledger.append({
                "pk": ledger_public_keys["online_whale_keys"][index],
                "sk": None,
                "balance": encode_nanocodas(0),
                "delegate": None
            })

            annotated_ledger.append({
                "pk":
                offline_whale,
                "sk":
                None,
                "balance":
                encode_nanocodas(whale_offline_balance),
                "delegate":
                ledger_public_keys["online_whale_keys"][index],
                "delegate_discord_username":
                "CodaBP{}".format(index)
            })
            annotated_ledger.append({
                "pk":
                ledger_public_keys["online_whale_keys"][index],
                "sk":
                None,
                "balance":
                encode_nanocodas(0),
                "delegate":
                None,
                "discord_username":
                "CodaBP{}".format(index)
            })
        # This will occur if there are less block producer keys than there are whale keys
        except IndexError:
            print(
                "There are less online whale keys than there are offline whale keys, are you sure you meant to do that?"
            )
            break
    print()
    # TODO: dynamic num_accounts
    # Write ledger and annotated ledger to disk
    with open(str(SCRIPT_DIR / 'genesis_ledger.json'), 'w') as outfile:
        ledger_wrapper = {
            "name": "release",
            "num_accounts": 250,
            "accounts": ledger
        }
        json.dump(ledger_wrapper, outfile, indent=1)
        print("Ledger Path: " + str(SCRIPT_DIR / 'genesis_ledger.json'))

    with open(str(SCRIPT_DIR / 'annotated_ledger.json'), 'w') as outfile:
        annotated_ledger_wrapper = {
            "name": "annotated_release",
            "num_accounts": 250,
            "accounts": ledger
        }
        json.dump(annotated_ledger_wrapper, outfile, indent=1)
        print("Annotated Ledger Path: " + str(SCRIPT_DIR / 'annotated_ledger.json'))


#####
# Commands for persisting keys to K8s Secrets
#####


@k8s.command()
@click.option('--key-dir',
              default=(SCRIPT_DIR / "seed_keys").absolute(),
              help='Location of Block Producer keys to Upload, a Directory.')
@click.option('--namespace',
              default="coda-testnet",
              help='The namespace the Kubernetes secret should be uploaded to.'
              )
@click.option('--cluster',
              default="",
              help='The cluster the Kubernetes secret should be uploaded to.')
def upload_seed_keys(key_dir, namespace, cluster):
    """Upload LibP2P Keypairs to Kubernetes -- Ensure kubectl is properly configured!"""
    # Load all the public keys from seed_key_dir
    key_files = glob.glob(str(key_dir.absolute()) + "/*libp2p*")
    # iterate over each key and upload it to kubernetes
    for file in key_files:
        seed_node = os.path.basename(file).split(".")[0]

        key_list = open(file, "r").readline()
        client_id = key_list.split(",")[2]
        print(client_id)

        command = "kubectl create secret generic {} --namespace={} --from-file=key={} --from-literal=peerid={}".format(
            seed_node.replace("_", "-") + "-key", namespace, file, client_id)
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
            print(output)


@k8s.command()
@click.option('--key-dir',
              default=DEFAULT_ONLINE_WHALE_KEYS_DIR.absolute(),
              help='Location of Block Producer keys to Upload, a Directory.')
@click.option('--namespace',
              default="coda-testnet",
              help='The namespace the Kubernetes secret should be uploaded to.'
              )
@click.option('--cluster',
              default="",
              help='The cluster the Kubernetes secret should be uploaded to.')
def upload_online_whale_keys(key_dir, namespace, cluster):
    """Upload Private Keys for Online Whales to Kubernetes -- Ensure kubectl is properly configured!"""
    key_dir = Path(key_dir)
    # Load all the public keys from seed_key_dir
    key_files = natsort.natsorted(
        glob.glob(str(key_dir.absolute()) + "/*.pub"))
    print(str(key_dir.absolute()) + "/*.pub")
    print(glob.glob(str(key_dir.absolute()) + "/*.pub"))
    # iterate over each key and upload it to kubernetes
    for file in key_files:
        keyfile = os.path.basename(file).split(".")[0]

        public_key_file = key_dir / (keyfile + ".pub")
        private_key_file = key_dir / keyfile

        command = "kubectl create secret generic {} --cluster={} --namespace={} --from-file=key={} --from-file=pub={}".format(
            keyfile.replace("_", "-") + "-key", cluster, namespace,
            private_key_file, public_key_file)
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
            print(output)


@k8s.command()
@click.option('--key-dir',
              default=DEFAULT_ONLINE_FISH_KEYS_DIR.absolute(),
              help='Location of Fish keys to Upload, a Directory.')
@click.option(
    '--namespace',
    default="coda-testnet",
    help='The namespace the Kubernetes secret(s) should be uploaded to.')
@click.option('--cluster',
              default="",
              help='The cluster the Kubernetes secret should be uploaded to.')
@click.option('--count', default=10, help='The number of keys to upload.')
@click.option('--offset',
              default=0,
              help='The number of keys to skip before uploading.')
def upload_online_fish_keys(key_dir, namespace, cluster, count, offset):
    """Upload Private Keys for online Fish Block Producers to Kubernetes -- Ensure kubectl is properly configured!"""
    key_dir = Path(key_dir)
    # Load all the public keys from seed_key_dir
    key_files = natsort.natsorted(
        glob.glob(str(Path(key_dir).absolute()) + "/*.pub"))

    # iterate over each key and upload it to kubernetes
    for file in key_files[offset:offset + count]:
        fish_producer = os.path.basename(file).split(".")[0]

        public_key_file = key_dir / (fish_producer + ".pub")
        private_key_file = key_dir / fish_producer

        command = "kubectl create secret generic {} --cluster={} --namespace={} --from-file=key={} --from-file=pub={}".format(
            fish_producer.replace("_", "-") + "-key", cluster, namespace,
            private_key_file, public_key_file)
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
            print(output)


@k8s.command()
@click.option('--key-dir',
              default=DEFAULT_SERVICE_KEY_DIR.absolute(),
              help='Location of Block Producer keys to Upload, a Directory.')
@click.option('--namespace',
              default="coda-testnet",
              help='The namespace the Kubernetes secret should be uploaded to.'
              )
@click.option('--cluster',
              default="",
              help='The cluster the Kubernetes secret should be uploaded to.')
def upload_service_keys(key_dir, namespace, cluster):
    """Upload Private Keys for Services to Kubernetes -- Ensure kubectl is properly configured!"""
    key_dir = Path(key_dir)
    # Load all the public keys from seed_key_dir
    key_files = glob.glob(str(key_dir.absolute()) + "/*.pub")
    if len(key_files) == 0:
        raise Exception('no service keys found')
    # iterate over each key and upload it to kubernetes
    for file in key_files:
        service = os.path.basename(file).split(".")[0]

        public_key_file = key_dir / (service + ".pub")
        private_key_file = key_dir / service

        command = "kubectl create secret generic {} --cluster={} --namespace={} --from-file=key={} --from-file=pub={}".format(
            service.replace("_", "-") + "-key", cluster, namespace,
            private_key_file, public_key_file)
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
            print(output)


if __name__ == "__main__":
    cli()
