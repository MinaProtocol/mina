import yaml
import sys
import re
import subprocess
import io

# Generate YAML content from dhall-to-yaml command and load it directly

tag_filters = [
    "FastOnly",
    "Long",
    "LongAndVeryLong",
    "TearDownOnly",
    "ToolchainsOnly",
    "AllTests",
    "Release",
    "Promote",
    "DebianBuild",
    "DockerBuild"
]

yaml_contents = []
for tag in tag_filters:
    dhall_cmd = f"""dhall-to-yaml --quoted <<< '(./src/Monorepo.dhall) {{ selection=(./src/Pipeline/JobSelection.dhall).Type.Full, tagFilter=(./src/Pipeline/TagFilter.dhall).Type.{tag}, scopeFilter=(./src/Pipeline/ScopeFilter.dhall).Type.All  }}'"""
    result = subprocess.run(dhall_cmd, shell=True, capture_output=True, text=True, executable="/bin/bash")
    if result.returncode != 0:
        print(f"Failed to generate YAML from dhall-to-yaml for tagFilter {tag}")
        print(result.stderr)
        sys.exit(1)
    yaml_contents.append(yaml.safe_load(io.StringIO(result.stdout)))

job_names_hit = []
missing_job_names = []

for yaml_content in yaml_contents:
    steps = yaml_content.get('steps', [])

    for step in steps:
        commands = step.get('commands', [])
        block = []

        for command in commands:
            if isinstance(command, str) and '\n' in command:
                lines = command.splitlines()
                temp_block = []
                for line in lines:
                    if line.strip() == '':
                        # End of a logical block
                        block_text = '\n'.join(temp_block)
                        if "dhall-to-yaml --quoted" in block_text:
                            block_text = re.sub(r'dhall-to-yaml --quoted.*', '', block_text)
                        temp_block = []
                    else:
                        temp_block.append(line)
                # Catch any remaining block
                if temp_block:
                    block_text = '\n'.join(temp_block)
                    if "dhall-to-yaml --quoted" in block_text:
                        block_text = re.sub(r'dhall-to-yaml --quoted.*', '', block_text)
                    result = subprocess.run(block_text, shell=True, capture_output=True, text=True, executable="/bin/bash")
                    if result.stdout.startswith("Triggering"):
                        match = re.search(r'Triggering (\w+)', result.stdout)
                        if match:
                            job_names_hit.append(match.group(1))
                    if result.stdout.startswith("Skipping"):
                        match = re.search(r'Skipping (\w+)', result.stdout)
                        if match:
                            missing_job_names.append(match.group(1))
                    if result.stderr:
                        print("== Errors ==")
                        print(result.stderr)

# Remove any intersected items from missing_job_names
missing_job_names = [job for job in missing_job_names if job not in job_names_hit]

if not missing_job_names:
    print("All jobs were found.")
else:
    print("Some jobs are missing:")
    for job in missing_job_names:
        print(f"- {job}")
    sys.exit(1)