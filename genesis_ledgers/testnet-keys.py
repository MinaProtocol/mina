import docker
import inflect
import os
import subprocess
from pathlib import Path
import click
import glob
import json
import csv

client = docker.from_env()
p = inflect.engine()

CODA_DAEMON_IMAGE = "codaprotocol/coda-daemon:0.0.11-beta1-release-0.0.12-beta-493b4c6"
SCRIPT_DIR = Path(__file__).parent.absolute()
DEFAULT_BLOCK_PRODUCER_KEY_DIR = SCRIPT_DIR / "block_producer_keys"
DEFAULT_WHALE_KEYS_DIR = SCRIPT_DIR / "whale_keys"
DEFAULT_FISH_KEYS_DIR = SCRIPT_DIR / "fish_keys"
DEFAULT_SEED_KEY_DIR = SCRIPT_DIR / "seed_libp2p_keys"
DEFAULT_STAKER_CSV_FILE = SCRIPT_DIR / "out.csv"


@click.group()
@click.option('--debug/--no-debug', default=False)
def cli(debug):
    pass

### 
# Commands for generating Coda Keypairs 
###
@cli.command()
@click.option('--count', default=5, help='Number of Block Producer keys to generate.')
@click.option('--output-dir', default=DEFAULT_BLOCK_PRODUCER_KEY_DIR.absolute(), help='Directory to output Public Keys to.')
@click.option('--privkey-pass', default="naughty blue worm", help='The password to use when generating keys.')
def generate_block_producer_keys(count, output_dir, privkey_pass):
    """Generate Public Keys for Block Producers."""
    # Create Block Producer Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        block_producer_number = p.number_to_words(i+1)
            
        # key outputted to file
        pubkey = client.containers.run(
            CODA_DAEMON_IMAGE,
            entrypoint="bash -c",  
            command=["CODA_PRIVKEY_PASS='{}' coda client-old generate-keypair -privkey-path /keys/block_producer_{}".format(privkey_pass, block_producer_number)], 
            volumes={output_dir: {'bind': '/keys', 'mode': 'rw'}}
        )
        print(pubkey)


@cli.command()
@click.option('--count', default=5, help='Number of Whale Account keys to generate.')
@click.option('--output-dir', default=DEFAULT_WHALE_KEYS_DIR.absolute(), help='Directory to output Whale Account Keys to.')
@click.option('--privkey-pass', default="naughty blue worm", help='The password to use when generating keys.')
def generate_offline_whale_keys(count, output_dir, privkey_pass):
    """Generate Public Keys Offline Whale Accounts (Controlled by O(1) Labs)."""
    # Create Whale Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        whale_number = p.number_to_words(i+1)
            
        # key outputted to file
        pubkey = client.containers.run(
            CODA_DAEMON_IMAGE,
            entrypoint="bash -c",  
            command=["CODA_PRIVKEY_PASS='{}' coda client-old generate-keypair -privkey-path /keys/whale_account_{}".format(privkey_pass, i+1)], 
            volumes={output_dir: {'bind': '/keys', 'mode': 'rw'}}
        )
        print(pubkey)

@cli.command()
@click.option('--count', default=150, help='Number of Fish Account keys to generate.')
@click.option('--output-dir', default=DEFAULT_FISH_KEYS_DIR.absolute(), help='Directory to output Fish Account Keys to.')
@click.option('--privkey-pass', default="naughty blue worm", help='The password to use when generating keys.')
def generate_offline_fish_keys(count, output_dir, privkey_pass):
    # Create Whale Keys Directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for i in range(0, count):
        fish_number = p.number_to_words(i+1)
            
        # key outputted to file
        pubkey = client.containers.run(
            CODA_DAEMON_IMAGE,
            entrypoint="bash -c",  
            command=["CODA_PRIVKEY_PASS='{}' coda client-old generate-keypair -privkey-path /keys/fish_account_{}".format(privkey_pass, i+1)], 
            volumes={output_dir: {'bind': '/keys', 'mode': 'rw'}}
        )
        print(pubkey)

#####
# Commands for generating LibP2P Keypairs
#####

@cli.command()
@click.option('--count', default=1, help='Number of Seed Libp2p keys to generate.')
@click.option('--output-dir', default=DEFAULT_SEED_KEY_DIR.absolute(), help='Directory to output LibP2P keys to.')
def generate_seed_keys(count, output_dir):
    """Generate LibP2P Keys for Seed Nodes"""
    SEED_KEYS_DIR = output_dir
    # Create Seed Node LibP2P Keys
    Path(SEED_KEYS_DIR).mkdir(parents=True, exist_ok=True)

    for i in range(0, 3):
        seed_number = p.number_to_words(i+1)

        # Key outputted to stdout
        key_raw = client.containers.run(CODA_DAEMON_IMAGE, entrypoint="bash -c", command=["coda advanced generate-libp2p-keypair"])
        key_parsed = str(key_raw).split("\\n")[1]
        all_key_file = open(SEED_KEYS_DIR / "seed_{}_libp2p.txt".format(seed_number), "w")

        client_id = copy(key_parsed).split(",")[2]
        client_id_file = open(SEED_KEYS_DIR / "seed_{}_client_id.txt".format(seed_number), "w")
        # Write Key to file
        all_key_file.write(key_parsed)
        client_id_file.write(client_id)
        print(client_id)

##### 
# Commands related to Genesis Ledger Creation
#####

@cli.command()
# Global Params
@click.option('--generate-remainder', default=False, help='Indicates that keys should be generated if there are not a sufficient number of keys present.')
# Whale Account Params
@click.option('--num-whale-accounts', default=5, help='Number of Whale accounts to be generated.')
@click.option('--whale-accounts-directory', default=DEFAULT_WHALE_KEYS_DIR, help='Directory where Whale Account Keys will be stored.')
# Fish Account Params
@click.option('--num-fish-accounts', default=100, help='Number of Fish accounts to be generated.')
@click.option('--fish-accounts-directory', default=DEFAULT_FISH_KEYS_DIR, help='Directory where Fish Account Keys will be stored.')
# Block Producer Account Params
@click.option('--num-block-producers', default=5, help='Number of O(1) Labs Block producer accounts to be generated.')
@click.option('--block-producer-accounts-directory', default=DEFAULT_BLOCK_PRODUCER_KEY_DIR, help='Directory where Block Producer Account Keys will be stored.')
# Community Staker Account Params
@click.option('--staker-csv-file', default=DEFAULT_STAKER_CSV_FILE, help='Location of a CSV file detailing Discord Username and Public Key for Stakers.')
def create_genesis_ledger(
    generate_remainder, 
    num_whale_accounts, 
    whale_accounts_directory,
    num_fish_accounts,
    fish_accounts_directory,
    num_block_producers,
    block_producer_accounts_directory,
    staker_csv_file
    ):
    """
    Generates a Genesis Ledger based on previously generated Whale, Fish, and Block Producer keys. 
    If keys are not present on the filesystem at the specified location, they are not generated.
    """

    ledger_public_keys = {
        "whale_keys": [],
        "fish_keys": [],
        "block_producer_keys": [],
        "staker_keys": [],
        "stakers": []
    }
    # Try loading whale keys
    whale_key_files = glob.glob(str(whale_accounts_directory.absolute()) + "/*.pub")
    if len(whale_key_files) >= num_whale_accounts:
        print("Processing Whale Keys -- {} keys required, loaded {} whale keys".format(num_whale_accounts, len(whale_key_files)))
        # load Whale Key Contents
        for whale_key_file in whale_key_files:
            fd = open(whale_key_file, "r")
            whale_public_key = fd.readline().strip()
            ledger_public_keys["whale_keys"].append(whale_public_key)

            fd.close()
    else:
        raise Exception("There aren't enough Whale Keys to populate the genesis ledger! Required {}, Present {}".format(num_whale_accounts, len(whale_key_files)))
    
    # Try Loading Fish Keys
    fish_key_files = glob.glob(str(fish_accounts_directory.absolute()) + "/*.pub")
    if len(fish_key_files) >= num_fish_accounts:
        print("Processing Fish Keys -- {} keys required, loaded {} fish keys".format(num_fish_accounts, len(fish_key_files)))
        for fish_key_file in fish_key_files:
            fd = open(fish_key_file, "r")
            fish_public_key = fd.readline().strip()
            ledger_public_keys["fish_keys"].append(fish_public_key)

            fd.close()
    else:
        raise Exception("There aren't enough Fish Keys to populate the genesis ledger! Required {}, Present {}".format(num_fish_accounts, len(fish_key_files)))
    
    # Try loading Block Producer Keys
    block_producer_key_files = glob.glob(str(block_producer_accounts_directory.absolute()) + "/*.pub")

    if len(block_producer_key_files) >= num_block_producers:
        print("Processing Block Producer Keys -- {} keys required, loaded {} block producer keys".format(num_block_producers, len(block_producer_key_files)))
        # should be 5 block producer keys, each is delegated to by (REMAINING_FISH_ACCOUNTS/5) fish accounts
        for block_producer_key_file in block_producer_key_files:
            fd = open(block_producer_key_file, "r")
            block_producer_public_key = fd.readline().strip()
            ledger_public_keys["block_producer_keys"].append(block_producer_public_key)

            fd.close()
    else:
        raise Exception("There aren't enough Block Producer Keys to populate the genesis ledger! Required {}, Present {}".format(num_block_producers, len(block_producer_key_files)))
   
    # Load contents of Online Staker Keys CSV
    with open(staker_csv_file, newline='') as csvfile:
        reader = csv.reader(csvfile, delimiter=',', quotechar='|')
        for row in reader:
            discord_username = row[1]
            public_key = row[2]
            if public_key.startswith("B62qr"):
                ledger_public_keys["staker_keys"].append(public_key)
                ledger_public_keys["stakers"].append({
                    "discord_username": discord_username, 
                    "public_key": public_key
                })
    
    #####################
    # GENERATE THE LEDGER
    #####################
    print("\n===Generating Genesis Ledger===")
    # [
    #     {  
    #     "pk":public-key-string, 
    #     "sk":optional-secret-key-string, 
    #     "balance":int, 
    #     "delegate": optional-public-key-string
    #     }
    # ]
    ledger_total_currency = 12000000
    ledger = []
    annotated_ledger = []

    # Check that there are enough fish keys for all stakers
    if len(ledger_public_keys["fish_keys"]) >= len(ledger_public_keys["staker_keys"]):
        print("There is a sufficient number of Fish Keys -- {} fish keys, {} stakers".format(num_fish_accounts, len(ledger_public_keys["staker_keys"])))

    # Fish Keys represent 70% of stake
    # Each fish key should delegate to, at most, one staker
    for index, fish in enumerate(ledger_public_keys["fish_keys"]):
        try: 
            # each fish key holds (70%/NUM_FISH_KEYS) of the total stake (70% total)
            ledger.append({
                "pk": fish,
                "sk": None,
                "balance": int((.7 * ledger_total_currency) / num_fish_accounts - 1000),
                "delegate": ledger_public_keys["stakers"][index]["public_key"]
            })
            # each staker key holds 1000 Coda to play with
            ledger.append({
                "pk": ledger_public_keys["stakers"][index]["public_key"],
                "sk": None,
                "delegate": None,
                "balance": 1000
            })

            # Create an annotated ledger with discord usernames in it
            annotated_ledger.append({
                "pk": fish,
                "sk": None,
                "balance": int((.7 * ledger_total_currency) / num_fish_accounts - 1000),
                "delegate": ledger_public_keys["stakers"][index]["public_key"],
                "nickname": ledger_public_keys["stakers"][index]["discord_username"]
            })
            # each staker key holds 1000 Coda to play with
            annotated_ledger.append({
                "pk": ledger_public_keys["stakers"][index]["public_key"],
                "sk": None,
                "balance": 1000,
                "delegate": None,
                "nickname": ledger_public_keys["stakers"][index]["discord_username"]
            })
        # This will occur if there are less staker keys than there are fish keys
        except IndexError: 
            # Delegate remainder keys to block producer one
            remainder_index = len(ledger_public_keys["fish_keys"]) - len(ledger_public_keys["stakers"]) - 1
            break

    # Check that there are enough whale keys for all block producers
    if len(ledger_public_keys["whale_keys"]) >= len(ledger_public_keys["block_producer_keys"]):
        print("There is a sufficient number of Whale Keys -- {} whale keys, {} block producer keys".format(num_whale_accounts, len(ledger_public_keys["block_producer_keys"])))

    # Whale Keys represent 30% of stake
    for index, whale in enumerate(ledger_public_keys["whale_keys"]):
        try:
            # Each whale key holds (30%/NUM_WHALE_KEYS) of the total stake (30% total)
            ledger.append({
                "pk": whale,
                "sk": None,
                "balance": int((0.3 * ledger_total_currency) / num_whale_accounts),
                "delegate": ledger_public_keys["block_producer_keys"][index]
            })
            ledger.append({
                "pk": ledger_public_keys["block_producer_keys"][index],
                "sk": None,
                "balance": 0,
                "delegate": None
            })

            annotated_ledger.append({
                "pk": whale,
                "sk": None,
                "balance": int((0.3 * ledger_total_currency) / num_whale_accounts),
                "delegate": ledger_public_keys["block_producer_keys"][index],
                "delegate_discord_username": "CodaBP{}".format(index)
            })
            annotated_ledger.append({
                "pk": ledger_public_keys["block_producer_keys"][index],
                "sk": None,
                "balance": 0,
                "delegate": None,
                "discord_username": "CodaBP{}".format(index)
            })
        # This will occur if there are less block producer keys than there are whale keys
        except IndexError: 
            print("There are less block producer keys than there are whale keys, are you sure you meant to do that?")
            break
    
    # Write ledger and annotated ledger to disk
    with open(SCRIPT_DIR / 'genesis_ledger.json', 'w') as outfile:
        json.dump(ledger, outfile, indent=1)

    with open(SCRIPT_DIR / 'annotated_ledger.json', 'w') as outfile:
        json.dump(annotated_ledger, outfile, indent=1)

    
#####
# Commands for persisting keys to K8s Secrets
#####

@cli.command()
@click.option('--key-dir', default=(SCRIPT_DIR / "seed_keys").absolute(), help='Location of Block Producer keys to Upload, a Directory.')
@click.option('--namespace', default="coda-testnet", help='The namespace the Kubernetes secret should be uploaded to.')
def upload_seed_keys(key_dir, namespace):
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
            seed_node.replace("_", "-") + "-key",
            namespace,
            file,
            client_id
        )
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
             print(output)

@cli.command()
@click.option('--key-dir', default=(SCRIPT_DIR / "block_producers").absolute(), help='Location of Block Producer keys to Upload, a Directory.')
@click.option('--namespace', default="coda-testnet", help='The namespace the Kubernetes secret should be uploaded to.')
def upload_block_producer_keys(key_dir, namespace):
    """Upload Private Keys for Block Producers to Kubernetes -- Ensure kubectl is properly configured!"""
    # Load all the public keys from seed_key_dir
    key_files = glob.glob(str(key_dir.absolute()) + "/*.pub")
    # iterate over each key and upload it to kubernetes
    for file in key_files: 
        block_producer = os.path.basename(file).split(".")[0]

        public_key_file = key_dir / (block_producer + ".pub")
        private_key_file = key_dir / block_producer

        command = "kubectl create secret generic {} --namespace={} --from-file=key={} --from-file=pub={}".format(
            block_producer.replace("_", "-") + "-key",
            namespace, private_key_file, public_key_file
        )
        process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
        output, error = process.communicate()
        if error:
            print(error)
        if output:
            print(output)


if __name__ == "__main__":
    cli()