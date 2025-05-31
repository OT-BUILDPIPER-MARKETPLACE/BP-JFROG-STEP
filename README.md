# BP-JFROG-STEP

This repository provides scripts and utilities for archiving and uploading artifacts to JFrog Artifactory, as well as Docker image push automation.

## Docker Image

- **Image:** `registry.buildpiper.in/okts/jfrog:0.0.1`

## Setup

* Clone the code available at [BP-JFROG-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-JFROG-STEP)

* Build the docker image
```
git submodule init
git submodule update
docker build -t registry.buildpiper.in/okts/jfrog:0.0.1 .
```

## Local Testing

```
docker run --rm -v "$PWD/data:/workspace/data" \
  -e SOURCE_PATH="/workspace/data/my_folder_or_file" \
  -e TARGET_FILENAME="upload_artifact" \
  -e ARCHIVE_FORMAT="zip" \
  -e ARTIFACTORY_URL="https://your-artifactory.example.com/artifactory" \
  -e ARTIFACTORY_REPO_PATH="my-repo/folder" \
  -e JFROG_USER="username" \
  -e JFROG_API_KEY="your_api_key" \
  registry.buildpiper.in/okts/jfrog:0.0.1
```

## Debug

```
docker run -it --rm -v $PWD:/src -e var1="key1" -e var2="key2" --entrypoint sh registry.buildpiper.in/okts/jfrog:0.0.1
```

## Environment Variables

| Variable                | Description                                 | Required |
|-------------------------|---------------------------------------------|----------|
| `ARTIFACTORY_URL`       | JFrog Artifactory URL                       | Yes      |
| `ARTIFACTORY_REPO_PATH` | Repository path in Artifactory              | Yes      |
| `JFROG_USER`            | JFrog username                              | Yes      |
| `JFROG_API_KEY`         | JFrog API key (or use `JFROG_PASSWORD`)     | Yes*     |
| `JFROG_PASSWORD`        | JFrog password (or use `JFROG_API_KEY`)     | Yes*     |
| `SOURCE_PATH`           | Path to file or directory to archive        | Yes      |
| `TARGET_FILENAME`       | Name for the archive file                   | Yes      |
| `ARCHIVE_FORMAT`        | `zip` or `tar.gz`                           | No (default: zip) |
| `SLEEP_DURATION`        | Sleep before processing (seconds)           | No       |
| `WORKSPACE`             | Workspace directory                         | Yes      |
| `CODEBASE_DIR`          | Codebase directory inside workspace         | Yes      |

\* Either `JFROG_API_KEY` or `JFROG_PASSWORD` must be provided.

## Features

- Archive files or directories as `.zip` or `.tar.gz`
- Upload artifacts to JFrog Artifactory using JFrog CLI
- Handles authentication with API key or password
- Retries on login block errors
- Docker image push support (see `main.py` and `push.py`)
