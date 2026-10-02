import json
import subprocess
import sys


query = json.load(sys.stdin)
name = query["name"]
region = query["region"]

result = subprocess.run(
    [
        "aws",
        "ecr",
        "describe-repositories",
        "--repository-names",
        name,
        "--region",
        region,
        "--output",
        "json",
    ],
    capture_output=True,
    text=True,
    check=False,
)

if result.returncode:
    if "RepositoryNotFoundException" in result.stderr:
        print(json.dumps({"exists": "false", "name": name, "repository_url": ""}))
        raise SystemExit(0)
    print(result.stderr, file=sys.stderr)
    raise SystemExit(result.returncode)

repository = json.loads(result.stdout)["repositories"][0]
print(
    json.dumps(
        {
            "exists": "true",
            "name": repository["repositoryName"],
            "repository_url": repository["repositoryUri"],
        }
    )
)