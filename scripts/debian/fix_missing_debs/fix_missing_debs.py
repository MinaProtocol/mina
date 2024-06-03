import hashlib
import os
import gzip
import re
import sys
import tempfile
from pathlib import Path
import shutil
import click


def make_a_backup(path):
    bck = f'{path}.bck'
    shutil.copyfile(path, bck)
    return bck


def find_all_debians_in(path, regex):
    files = list(map(lambda filename: DebInfo(f'{path}/{filename}'),
                     filter(lambda filename: filename.endswith(".deb"),
                            filter(lambda filename: re.search(regex, filename), os.listdir(path))
                            )
                     )
                 )
    [print(str(file_info)) for file_info in files]
    return files

def packages_file_exist(path):
    package_file = f"{path}/Packages"
    if os.path.isfile(package_file):
        print(f"cannot find {package_file}")
        sys.exit()
    else:
        return package_file

def release_file_exist(path):
    release_file = f"{path}/Release"
    if os.path.isfile(release_file):
        print(f"cannot find {release_file}")
        sys.exit()
    else:
        return release_file

class CheckSumInfo:
    def __init__(self, path):
        self.path = path
        self.size = os.stat(path).st_size
        self.md5 = hashlib.md5(open(path, 'rb').read()).hexdigest()
        self.sha1 = hashlib.sha1(open(path, 'rb').read()).hexdigest()
        self.sha256 = hashlib.sha256(open(path, 'rb').read()).hexdigest()

    def __str__(self):
        return f"""Path: {self.path}
Size: {self.size}
MD5Sum: {self.md5}
Sha1Sum: {self.sha1}
Sha256Sum: {self.sha256}
"""


class PackagesFile:

    def __init__(self, path, arch, component):
        self.path = path
        self.arch = arch
        self.component = component
        self.check_sum = CheckSumInfo(path)

    def __str__(self):
        return f'''Path: {self.full_name()}
Arch: {self.arch}
Component: {self.component}
{ReleaseFile.md5_header}
{self.formatted_md5()}{ReleaseFile.sha1_header}
{self.formatted_sha1()}{ReleaseFile.sha256_header}
{self.formatted_sha256()}
    '''

    def copy(self, new_path):
        return PackagesFile(new_path, self.arch, self.component)

    def full_name(self):
        return f'{self.component}/binary-{self.arch}/Packages'

    def update(self, file_info):
        package_found = False
        version_found = False

        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            with open(self.path) as text, open(tmp.name, 'w') as new_text:
                for line in text:
                    if line.strip() == f'Package: {file_info.package}':
                        package_found = True
                    if line.strip() == f'Version: {file_info.version}':
                        version_found = True
                    if line.isspace():
                        package_found = False
                        version_found = False

                    if package_found and version_found:
                        if line.startswith(DebInfo.size_header):
                            print(f"updating size in {self.path} for debian: {file_info.path}")
                            new_text.writelines(file_info.formatted_size())
                        elif line.startswith(DebInfo.md5_header):
                            print(f"updating md5 in {self.path} for debian: {file_info.path}")
                            new_text.write(file_info.formatted_md5())
                        elif line.startswith(DebInfo.sha1_header):
                            print(f"updating sha1 in {self.path} for debian: {file_info.path}")
                            new_text.write(file_info.formatted_sha1())
                        elif line.startswith(DebInfo.sha256_header):
                            print(f"updating sha256 in {self.path} for debian: {file_info.path}")
                            new_text.write(file_info.formatted_sha256())
                        else:
                            new_text.write(line)
                    else:
                        new_text.write(line)

            shutil.move(tmp.name, self.path)

    def formatted_sha1(self):
        return f" {self.check_sum.sha1} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"

    def formatted_sha256(self):
        return f" {self.check_sum.sha256} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"

    def formatted_md5(self):
        return f" {self.check_sum.md5} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"


class PackagesGzipFile:

    def __init__(self, packages_file: PackagesFile):
        gzip_file = f'{packages_file.path}.gz'
        with open(packages_file.path, 'rb') as src, gzip.open(gzip_file, 'wb') as dst:
            dst.writelines(src)

        self.package_file = packages_file
        self.gzip_package_file = gzip_file
        self.check_sum = CheckSumInfo(self.gzip_package_file)

    def __str__(self):
        return f'''Path: {self.full_name()}
{ReleaseFile.md5_header}
{self.formatted_md5()}{ReleaseFile.sha1_header}
{self.formatted_sha1()}{ReleaseFile.sha256_header}
{self.formatted_sha256()}
'''

    def full_name(self):
        return f'{self.package_file.component}/binary-{self.package_file.arch}/Packages.gz'

    def formatted_sha1(self):
        return f" {self.check_sum.sha1} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"

    def formatted_sha256(self):
        return f" {self.check_sum.sha256} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"

    def formatted_md5(self):
        return f" {self.check_sum.md5} {str(self.check_sum.size).rjust(16, ' ')} {self.full_name()}\n"


class DebInfo:
    sha1_header = "SHA1:"
    sha256_header = "SHA256:"
    md5_header = "MD5sum:"
    size_header = "Size:"

    def __init__(self, path):
        self.package, self.version = Path(path).stem.split('_')
        self.check_sum = CheckSumInfo(path)
        self.path = path

    def formatted_size(self):
        return f'{DebInfo.size_header} {self.check_sum.size}\n'

    def formatted_md5(self):
        return f'{DebInfo.md5_header} {self.check_sum.md5}\n'

    def formatted_sha1(self):
        return f'{DebInfo.sha1_header} {self.check_sum.sha1}\n'

    def formatted_sha256(self):
        return f'{DebInfo.sha256_header} {self.check_sum.sha256}\n'

    def __str__(self):
        return f'''Package: {self.package}
Arch: {self.version}
{self.formatted_size()}{self.formatted_md5()}{self.formatted_sha1()}{self.formatted_sha256()}
'''


class ReleaseFile:
    sha1_header = "SHA1:"
    sha256_header = "SHA256:"
    md5_header = "MD5Sum:"
    size_header = "Size:"

    def __init__(self, path):
        self.path = path

    def update(self, package_file: PackagesFile, gzip_package_file: PackagesGzipFile):
        sha1_sums = False
        sha256_sums = False
        md5_sums = False

        with tempfile.NamedTemporaryFile(delete=False) as tmp:

            with open(self.path) as text, open(tmp.name, 'w') as new_text:
                for line in text:
                    if line.startswith(ReleaseFile.sha1_header):
                        sha1_sums = True
                        sha256_sums = False
                        md5_sums = False
                    if line.startswith(ReleaseFile.sha256_header):
                        sha1_sums = False
                        sha256_sums = True
                        md5_sums = False
                    if line.startswith(ReleaseFile.md5_header):
                        sha1_sums = False
                        sha256_sums = False
                        md5_sums = True
                    if line.strip().endswith(package_file.full_name()):
                        if sha1_sums:
                            new_text.writelines(package_file.formatted_sha1())
                        if sha256_sums:
                            new_text.write(package_file.formatted_sha256())
                        if md5_sums:
                            new_text.write(package_file.formatted_md5())

                    elif line.strip().endswith(gzip_package_file.full_name()):
                        if sha1_sums:
                            new_text.write(gzip_package_file.formatted_sha1())
                        if sha256_sums:
                            new_text.write(gzip_package_file.formatted_sha256())
                        if md5_sums:
                            new_text.write(gzip_package_file.formatted_md5())
                    else:
                        new_text.write(line)


@click.group()
def cli():
    pass


@cli.command()
@click.option('--path', default=".", help='Path to file')
@click.option('--regex', default=".*", help='Path to file')
def print_checksums(path: str, regex):
    for filename in os.listdir(path):
        if re.search(regex, filename):
            filepath = f'{path}/{filename}'
            if filename.endswith(".deb"):
                print(str(DebInfo(filepath)))
            else:
                print(str(CheckSumInfo(filepath)))


@cli.command()
@click.option('--path', default=".", help='Path to folder with debian files')
@click.option('--regex', default=".", help='Regex for selecting debian to update')
@click.option('--arch', default="amd64", help='Package architecture')
@click.option('--component', help='Package component')
def update_packages(path, regex, arch, component):
    file_infos = find_all_debians_in(path.path, regex)

    package_file = packages_file_exist(path)
    make_a_backup(package_file)

    package_info_file = PackagesFile(package_file, arch, component)

    for file_info in file_infos:
        package_info_file.update(file_info)

    new_gzip_file = PackagesGzipFile(package_info_file)

    print(package_info_file)
    print(new_gzip_file)

@cli.command()
@click.option('--path', default=".", help='Path to folder with debian files')
@click.option('--regex', default=".", help='Regex for selecting debian to update')
@click.option('--arch', default="amd64", help='Package architecture')
@click.option('--component', help='Package component')
def update_releases(path, regex, arch, component):
    file_infos = file_infos = find_all_debians_in(path.path, regex)

    package_file = packages_file_exist(path)
    release_file = release_file_exist(path)

    make_a_backup(package_file)
    make_a_backup(release_file)

    package_info_file = PackagesFile(package_file, arch, component)

    for file_info in file_infos:
        package_info_file.update(file_info)

    new_gzip_file = PackagesGzipFile(package_info_file)

    print(package_info_file)
    print(new_gzip_file)

    release = ReleaseFile(release_file)
    release.update(package_info_file, new_gzip_file)


if __name__ == '__main__':
    cli()
