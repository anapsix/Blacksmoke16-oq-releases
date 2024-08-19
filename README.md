[![DockerHub](https://img.shields.io/badge/dockerhub-image-blue?style=flat&logo=docker)][dockerhub]
[![GHCR](https://img.shields.io/badge/ghcr-image-blue?style=flat&logo=github)][ghcr]

This repo creates and publishes [`oq`][1] static binaries for `linux/amd64` and
`linux/arm64` architectures.
See repo's [releases page][2], as well as upstream repo's [releases][3].

Container images are published to Docker Hub and GHCR:
- [`docker.io/anapsix/oq:<release_tag>`][dockerhub]
- [`ghcr.io/anapsix/oq:<release_tag>`][ghcr]

## attestation / validations

The release binaries and container images have attestations generated and
published to the repo with [`actions/attest-build-provenance`][attest] action.

Verification is possible with `gh attestation verify` (see [docs][gh-docs]).

<details><summary>verification examples</summary>

- binaries
  ```shell
  gh attestation verify ./bin/oq-v1.3.5-linux-amd64 --owner anapsix
  gh attestation verify ./bin/oq-v1.3.5-linux-amd64 --repo anapsix/Blacksmoke16-oq-releases
  ```
- images
  ```shell
  # docker
  gh attestation verify oci://docker.io/anapsix/oq:v1.3.5 --owner anapsix
  gh attestation verify oci://docker.io/anapsix/oq:v1.3.5 --repo anapsix/Blacksmoke16-oq-releases

  # ghcr
  gh attestation verify oci://ghcr.io/anapsix/oq:v1.3.5 --owner anapsix
  gh attestation verify oci://ghcr.io/anapsix/oq:v1.3.5 --repo anapsix/Blacksmoke16-oq-releases
  ```
</details>

## misc

Though inspired by [Blacksmoke16/oq#130][upstreamPR], this repo primarily serves
as an experimental playground for arguably over-engineered GitHub Actions
workflows, and easing my engineering cravings during sabbatical.

## acknowledgments

Thank you @blacksmoke16 for introducing me to Crystal, and your contributions
to OSS ❤️🙏

[links]::
[1]: https://github.com/Blacksmoke16/oq
[2]: https://github.com/anapsix/Blacksmoke16-oq-releases/releases
[3]: https://github.com/Blacksmoke16/oq/releases
[attest]: https://github.com/marketplace/actions/attest-build-provenance
[gh-docs]: https://cli.github.com/manual/gh_attestation_verify
[upstreamPR]: https://github.com/Blacksmoke16/oq/pull/130
[dockerhub]: https://hub.docker.com/r/anapsix/oq
[ghcr]: https://github.com/anapsix/Blacksmoke16-oq-releases/pkgs/container/oq
