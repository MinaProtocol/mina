import os
import random
import tarfile
import tempfile
import xml.etree.ElementTree as ET
from io import BytesIO
from typing import List
from urllib.parse import urljoin

import pycurl
from tqdm import tqdm

import rocksdb

NUM_LEDGER_TARS = 5
NUM_KV_PER_LEDGER = 10

# Match keys starting with "genesis_ledger" or "epoch_ledger" and ending with ".tar.gz"
def matches_pattern(key: str) -> bool:
    return (key.startswith("genesis_ledger") or key.startswith("epoch_ledger")) and key.endswith(".tar.gz")


def download_file(url: str, dest_path: str) -> None:
    with open(dest_path, "wb") as f:
        # Create a progress bar (tqdm)
        pbar = tqdm(unit="B", unit_scale=True, unit_divisor=1024, ncols=80)

        def progress(download_t, download_d, _upload_t, _upload_d):
            _ = (_upload_t, _upload_d) # Make pyright happier
            if download_t > 0:
                pbar.total = download_t
                pbar.update(download_d - pbar.n)

        c = pycurl.Curl()
        c.setopt(pycurl.URL, url)
        c.setopt(pycurl.WRITEDATA, f)
        c.setopt(pycurl.FOLLOWLOCATION, True)
        c.setopt(pycurl.NOPROGRESS, False)
        c.setopt(pycurl.XFERINFOFUNCTION, progress)
        c.perform()
        c.close()

        pbar.close()


def extract_tar_gz(tar_path: str, target_dir: str) -> None:
    with tarfile.open(tar_path, "r:gz") as tar:
        tar.extractall(path=target_dir)

# TODO: figure out how to enable SSL here
def list_s3_keys(url, matches_pattern) -> List[str] :
    buffer = BytesIO()
    c = pycurl.Curl()
    c.setopt(pycurl.URL, url)
    c.setopt(pycurl.WRITEDATA, buffer)
    c.setopt(pycurl.FOLLOWLOCATION, True)
    c.setopt(pycurl.SSL_VERIFYPEER, False)
    c.setopt(pycurl.SSL_VERIFYHOST, 0)
    c.perform()
    status_code = c.getinfo(pycurl.RESPONSE_CODE)
    c.close()

    if status_code != 200:
        raise RuntimeError(f"Failed to list S3 bucket: {status_code}")

    data = buffer.getvalue()
    root = ET.fromstring(data)
    ns = {"s3": "http://s3.amazonaws.com/doc/2006-03-01/"}
    tar_keys = [
        text
        for elem in root.findall(".//s3:Contents/s3:Key", ns)
        if (text := elem.text) is not None and matches_pattern(text)
    ]
    return tar_keys

def main():
    tar_keys = list_s3_keys("https://snark-keys.o1test.net.s3.amazonaws.com/", matches_pattern)

    if not tar_keys:
        raise RuntimeError("No ledger tar files found.")

    for tar_key in random.sample(tar_keys, min(NUM_LEDGER_TARS, len(tar_keys))):
        tar_uri = urljoin("https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/", tar_key)
        print(f"Testing RocksDB compatibility on {tar_uri}")

        with tempfile.TemporaryDirectory() as tmpdir:
            tar_path = os.path.join(tmpdir, os.path.basename(tar_key))
            print(f"  Downloading to {tar_path}...")
            download_file(tar_uri, tar_path)

            db_path = os.path.join(tmpdir, "extracted")
            os.makedirs(db_path, exist_ok=True)
            print(f"  Extracting to {db_path}...")
            extract_tar_gz(tar_path, db_path)

            print(f"  Testing extracted RocksDB at {db_path}")
            rocksdb.test(db_path, NUM_KV_PER_LEDGER)


if __name__ == "__main__":
    main()
