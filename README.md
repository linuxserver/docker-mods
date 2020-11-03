# Intro

The purpose of the repository is to provide examples and guidance in creating and storing a user consumable modification layer for the Library of Linuxserver.io Containers.
At it's core a Docker Mod is a tarball of files stored on Dockerhub and/or GitHub Container Registry that is downloaded and extracted on container boot before any init logic is run.
This allows:

* Developers and community users to modify base containers to suit their needs without the need to maintain a fork of the main docker repository
* Mods to be shared with the Linuxserver.io userbase as individual independent projects with their own support channels and development ideologies
* Zero cost hosting and build pipelines for these modifications leveraging GitHub Container Registry and Dockerhub
* Full custom configuration management layers for hooking containers into each other using environment variables contained in a compose file

It is important to note to end users of this system that there are not only extreme security implications to consuming files from souces outside of our control, but by leveraging community Mods you essentially lose direct support from the core LinuxServer team. Our first and foremost troubleshooting step will be to remove the `DOCKER_MODS` environment variable when running into issues and replace the container with a clean LSIO one.

Again, when pulling in logic from external sources practice caution and trust the sources/community you get them from.

## LinuxServer.io Hosted Mods

We host and publish official Mods at the [linuxserver/mods](https://github.com/orgs/linuxserver/packages/container/mods/versions) endpoint as separate tags. Each tag is in the format of `<imagename>-<modname>` for the latest versions, and `<imagename>-<modname>-<commitsha>` for the specific versions.

Here's a list of the official Mods we host: <https://mods.linuxserver.io/>

## Using a Docker Mod

Before consuming a Docker Mod ensure that the source code for it is publicly posted along with it's build pipeline pushing to Dockerhub.

Consumption of a Docker Mod is intended to be as user friendly as possible and can be achieved with the following environment variables being passed to the container:

* DOCKER_MODS- This can be a single endpoint `user/endpoint:tag` or an array of endpoints separated by `|` `user/endpoint:tag|user2/endpoint2:tag`
* RUN_BANNED_MODS- If this is set to any value you will bypass our centralized filter of banned Dockerhub users and run Mods regardless of a ban

Full example:

```bash
docker create \
  --name=nzbget \
  -e DOCKER_MODS=taisun/nzbget-mod:latest \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -p 6789:6789 \
  -v <path to data>:/config \
  -v <path/to/downloads>:/downloads \
  --restart unless-stopped \
  linuxserver/nzbget
```

This will spinup an nzbget container and apply the custom logic found in the following repository:

<https://github.com/Taisun-Docker/Linuxserver-Mod-Demo>

This basic demo installs Pip and a couple dependencies for plugins some users leverage with nzbget.

## Creating and maintaining a Docker Mod

We will always recommend to our users consuming Mods that they leverage ones from active community members or projects so transparency is key here. We understand that image layers can be pushed on the back end behind these pipelines, but every little bit helps.
In this repository we will be going over two basic methods of making a Mod along with an example of the GitHub Actions build logic to get this into a Dockerhub and/or GitHub Container Registry endpoint. Though we are not officially endorsing GitHub Actions here it is built in to GitHub repositories and forks making it very easy to get started. If you prefer others feel free to use them as long as build jobs are transparent.

One of the core ideas to remember when creating a Mod is that it can only contain a single image layer, the examples below will show you how to add files standardly and how to run complex logic to assemble the files in a build layer to copy them over into this single layer.

### Docker Mod Simple - just add scripts

In this repository you will find the `Dockerfile` containing:

```Dockerfile
FROM scratch

# copy local files
COPY root/ /
```

For most users this will suffice and anything in the root/ folder of the repository will be added to the end users Docker container / path.

The most common paths to leverage for Linuxserver images will be:

* root/etc/cont-init.d/<98-script-name> - Contains init logic scripts that run before the services in the container start these should exit 0 and are ordered by filename
* root/etc/services.d/`yourservice`/run - Contains scripts that run in the foreground for persistent services IE NGINX
* root/defaults - Contains base config files that are copied/modified on first spinup

The example files in this repo contain a script to install sshutil and a service file to run the installed utility.

### Docker Mod Complex - Sky is the limit

In this repository you will find the `Dockerfile.complex` containing:

```Dockerfile
## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.12 as buildstage

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache \
	curl && \
 echo "**** grab rclone ****" && \
 mkdir -p /root-layer && \
 curl -o \
	/root-layer/rclone.deb -L \
	"https://downloads.rclone.org/v1.47.0/rclone-v1.47.0-linux-amd64.deb"

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
```

Here we are leveraging a multi stage DockerFile to run custom logic and pull down an Rclone deb from the Internet to include in our image layer for distribution. Any amount of logic can be run in this build stage or even multiple build stages as long as the files in the end are combined into a single folder for the COPY command in the final output.

## Getting a Mod to Dockerhub

To publish a Mod to DocherHub you will need the following accounts:

* Github- <https://github.com/join>
* DockerHub- <https://hub.docker.com/signup>

We recommend using this repository as a template for your first Mod, so in this section we assume the code is finished and we will only concentrate on plugging into GitHub Actions/Dockerhub.

The only code change you need to make to the build logic file `.github/workflows/BuildImage.yml` will be to modify the ENDPOINT to your own image:

```yaml
  ENDPOINT: "user/endpoint"
  BRANCH: "master"
```

User is your Dockerhub user and endpoint is your own custom name (typically the name of the repository where your mod is). You do not need to create this endpoint beforehand, the build logic will push it and create it on first run.

Head over to `https://github.com/user/endpoint/settings/secrets` and click on `New secret`

Add `DOCKERUSER` (your DockerHub username) and `DOCKERPASS` (your DockerHub password or token).

You can create a token by visiting <https://hub.docker.com/settings/security>

GitHub Actions will trigger a build off of your repo when you commit. The image will be pushed to Dockerhub on success. This Dockerhub endpoint is the Mod variable you can use to customize your container now.

## Getting a Mod to GitHub Container Registry

To publish a Mod to GitHub Container Registry you will need the following accounts:

* Github- <https://github.com/join>

We recommend using this repository as a template for your first Mod, so in this section we assume the code is finished and we will only concentrate on plugging into GitHub Actions/GitHub Container Registry.

The only code change you need to make to the build logic file `.github/workflows/BuildImage.yml` will be to modify the ENDPOINT to your own image:

```yaml
  ENDPOINT: "user/endpoint"
  BRANCH: "master"
```

User is your GutHub user and endpoint is your own custom name (typically the name of the repository where your mod is). You do not need to create this endpoint beforehand, the build logic will push it and create it on first run.

Head over to `https://github.com/user/endpoint/settings/secrets` and click on `New secret`

Add `CR_USER` (your GitHub username) and `CR_PAT` (a personal access token with `read:packages` and `write:packages` scopes).

You can create a personal access token by visiting <https://github.com/settings/tokens>

GitHub Actions will trigger a build off of your repo when you commit. The image will be pushed to GitHub Container Registry on success. This GitHub Container Registry endpoint is the Mod variable you can use to customize your container now.

## Submitting a PR for a Mod to be added to the official LinuxServer.io repo

* Fork this repo, checkout the `template` branch.
* Edit the `Dockerfile` for the mod. `Dockerfile.complex` is only an example and included for reference; it should be deleted when done.
* Inspect the `root` folder contents. Edit, add and remove as necessary.
* Edit the readme with pertinent info.
* Finally edit the `.github/workflows/BuildImage.yml`. Customize the vars for `BASEIMAGE` and `MODNAME`.
* Ask the team to create a new branch named `<baseimagename>-<modname>` in this repo. Baseimage should be the name of the image the mod will be applied to. The new branch will be based on the [template branch](https://github.com/linuxserver/docker-mods/tree/template).
* Submit PR against the branch created by the team.
* Make sure that the commits in the PR are squashed.
* Also make sure that the commit and PR titles are in the format of `<imagename>: <modname> <very brief description like "initial release" or "update">`. Detailed description and further info should be provided in the body (ie. `code-server: python2 add python-pip`).

## Appendix

### Inspecting mods

To inspect the file contents of external Mods dive is a great CLI tool:

<https://github.com/wagoodman/dive>

Basic usage:

```bash
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    wagoodman/dive:latest <Image Name>
```
