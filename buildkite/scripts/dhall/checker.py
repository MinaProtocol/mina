"""
    Runs dhall checks like:

    - validate if all dependencies in jobs are covered

        python3 buildkite/scripts/dhall/checker.py --root ./buildkite/src/Jobs deps

    - all dirtyWhen entries relates to existing files

        python3 buildkite/scripts/dhall/checker.py --root ./buildkite/src/Jobs dirty-when

    - print commands for given job

        python3 buildkite/scripts/dhall/checker.py --root ./buildkite/src/Jobs print-cmd --job SingleNodeTest
"""


import argparse
import subprocess
import os
from glob import glob
import tempfile
from pathlib import Path
import yaml


class CmdColors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class PipelineInfoBuilder:

    def __init__(self, temp, file):
        with open(f"{temp}/{file}") as stream:
            try:
                self.pipeline = yaml.safe_load(stream)
                self.file = file
            except yaml.YAMLError as exc:
                print(f"cannot parse correctly {temp}/{file}, due to {exc}")
                exit(1)

    def get_steps(self):
        steps = []
        for step in self.pipeline["pipeline"]["steps"]:
            key = step["key"]
            deps = []
            if "depends_on" in step:
                for dependsOn in step["depends_on"]:
                    deps.append(dependsOn["step"])
            commands = step["commands"]
            steps.append(Step(key, deps, commands))
        return steps

    def get_dirty(self):
        dirty = []
        for dirtyWhen in self.pipeline["spec"]["dirtyWhen"]:
            path = dirtyWhen["dir"][0] if "dir" in dirtyWhen else ""
            exts = dirtyWhen["exts"][0] if "exts" in dirtyWhen else ""
            strictEnd = bool(dirtyWhen["strictEnd"]) if (
                not "strictEnd" in dirtyWhen) else False
            strictStart = bool(dirtyWhen["strictStart"]) if (
                not "strictStart" in dirtyWhen) else False
            dirty.append(DirtyWhen(path=path, strictStart=strictStart,
                         strictEnd=strictEnd, extension=exts))
        return dirty

    def build(self):
        steps = self.get_steps()
        dirty = self.get_dirty()
        return PipelineInfo(self.file, self.pipeline, steps, dirty)


class DirtyWhen:

    def __init__(self, path, extension, strictStart, strictEnd):
        self.path = path
        self.extension = extension
        self.strictStart = strictStart
        self.strictEnd = strictEnd

    def calculate_path(self):
        if self.extension and self.path:
            return glob(f"{self.path}.{self.extension}")
        if self.strictEnd and not self.strictStart:
            if not self.extension:
                return glob(f"**/*/{self.path}")
            else:
                return glob(f"*/{self.path}.{self.extension}")
        if self.strictStart and self.strictEnd:
            if not self.extension:
                return glob(f"{self.path}*")
            else:
                return glob(f"{self.path}.{self.extension}")
        if self.strictStart and not self.strictEnd:
            return glob(self.path + '.*')
        if not self.strictStart and not self.strictEnd:
            if not self.extension:
                if "." in self.path:
                    return glob(f"**/*/{self.path}", recursive=True)
                else:
                    return glob(f"{self.path}*")
            else:
                return glob(f"*.{self.extension}")
        raise RuntimeError("invalid state dirty when")

    def __str__(self):
        return f"path: '{self.path}', exts: '{self.extension}', startStrict:{self.strictStart}, startEnd:{self.strictEnd}"


class Step:

    def __init__(self, key, deps, commands):
        self.key = key
        self.deps = deps
        self.commands = commands


class PipelineInfo:

    def __init__(self, file, pipeline, steps, dirty):
        self.file = file
        self.pipeline = pipeline
        self.steps = steps
        self.dirty = dirty

    def keys(self):
        return [step.key for step in self.steps]


parser = argparse.ArgumentParser(description='Executes mina benchmarks')
parser.add_argument("--root", required=True,
                    help="root folder where all dhall files resides")

subparsers = parser.add_subparsers(dest="cmd")
subparsers.add_parser('dirty-when')
subparsers.add_parser('deps')
run = subparsers.add_parser('print-cmd')
run.add_argument("--job", required=True, help="job to run")
run.add_argument("--step", required=False, help="job to run")


args = parser.parse_args()
tmp = tempfile.mkdtemp()

print(f"Artifacts are stored in {tmp}")

for file in [y for x in os.walk(args.root) for y in glob(os.path.join(x[0], '*.dhall'))]:
    name = Path(file).stem
    with open(f"{tmp}/{name}.yml", "w") as outfile:
        subprocess.run(["dhall-to-yaml", "--quoted", "--file",
                       file], stdout=outfile, check=True)


pipelinesInfo = [PipelineInfoBuilder(tmp, file).build()
                 for file in os.listdir(path=tmp)]

if args.cmd == "deps":

    keys = []
    for pipeline in pipelinesInfo:
        keys.extend(pipeline.keys())

    failedSteps = []

    for pipeline in pipelinesInfo:
        for step in pipeline.steps:
            for dep in step.deps:
                if not dep in keys:
                    failedSteps.append((pipeline, step, dep))

    if any(failedSteps):
        print("Fatal: Missing dependency resolution found:")
        for (pipeline, step, dep) in failedSteps:
            file = str.replace(pipeline.file, ".yml", ".dhall")
            print(
                f"\t{CmdColors.FAIL}[FATAL] Unresolved dependency for step '{step.key}' in '{file}' depends on non existing job '{dep}'{CmdColors.ENDC}")
        exit(1)


if args.cmd == "print-cmd":
    pipeline = next(filter(lambda x: args.job in x.file, pipelinesInfo))

    def get_steps():
        if args.step:
            return [next(filter(lambda x: args.step in x.key, pipeline.steps))]
        else:
            return pipeline.steps

    steps = get_steps()

    for step in steps:
        for command in step.commands:
            if not command.startswith("echo"):
                print(command)

if args.cmd == "dirty-when":

    failedSteps = []

    for pipeline in pipelinesInfo:
        for dirty in pipeline.dirty:
            if not bool(dirty.calculate_path()):
                failedSteps.append((pipeline, dirty))

    if any(failedSteps):
        print("Fatal: Non existing dirtyWhen path detected:")
        for (pipeline, dirty) in failedSteps:
            file = str.replace(pipeline.file, ".yml", ".dhall")
            print(
                f"\t{CmdColors.FAIL}[FATAL] Unresolved dirtyWhen path  in '{file}' ('{str(dirty)}'){CmdColors.ENDC}")
        exit(1)
