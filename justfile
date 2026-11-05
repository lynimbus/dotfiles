# atomic-workstation — standalone justfile for this branch
#
# This branch only contains the atomic-workstation subsystem, so its justfile
# holds the image-* recipes plus the user-side seed/install recipes (the
# NixOS recipes of the main branch do not apply here). Parameters come from
# image-template.env via dotenv.
# ═════════════════════════════════════════════════════════════════════════════
# atomic-workstation — OCI image build (Bazzite + niri/noctalia)
#
# Recipes ported from the ublue-os/image-template Justfile
# (https://github.com/ublue-os/image-template). They are prefixed with
# `image-` because this repo already uses `build`/`check` for NixOS.
# Parameters come from image-template.env (loaded via dotenv below).
# CI: .github/workflows/build.yml. See docs/installation.md.
# ═════════════════════════════════════════════════════════════════════════════

set dotenv-filename := "image-template.env"
set dotenv-load

image_name := env_var_or_default("IMAGE_NAME", "atomic-workstation")
repo_organization := env_var_or_default("REPO_ORGANIZATION", "lynimbus")
source_repo := env_var_or_default("SOURCE_REPO", "lynimbus/dotfiles")
image_desc := env_var_or_default("IMAGE_DESC", "Bazzite with an additional niri session")
image_keywords := env_var_or_default("IMAGE_KEYWORDS", "bazzite,niri,bootc,atomic")
image_logo_url := env_var_or_default("IMAGE_LOGO_URL", "")
default_tag := env_var_or_default("DEFAULT_TAG", "latest")
base_image := env_var_or_default("BASE_IMAGE", "ghcr.io/ublue-os/bazzite:stable")
bib_image := env_var_or_default("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

# Validate that the justfile and every *.just recipe file parse correctly (standalone version of this branch)
[group('image')]
image-check:
    #!/usr/bin/env bash
    set -euo pipefail
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just -f "$file" --list >/dev/null
    done
    echo "Checking syntax: justfile"
    just -f justfile --list >/dev/null
    echo "OK"

# ── user-side seeds & release apps (ported from main's NixOS packages) ─────

# Install/refresh the pinned GitHub-release apps (magpie, ghostty,
# opengrep, r8, mygo) into ~/.local — the pkgs/ overlay of the main branch
#
# `just user-apps` installs everything; `just user-apps magpie r8` only those;
# `just user-apps --check` compares the pins with upstream.
[group('user')]
user-apps *args:
    #!/usr/bin/env bash
    set -euo pipefail
    # The variadic arguments are expanded to individually shell-quoted words
    # by just — do NOT wrap the expansion in quotes, that would splice all
    # arguments into one string.
    exec ./scripts/install-user-apps.sh {{args}}

# First-boot CLI seed: the brew translation of main's home/packages/*.nix
[group('user')]
brew-seed:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v brew >/dev/null 2>&1; then
        echo "brew is not installed — on Bazzite: ujust install-brew" >&2
        exit 1
    fi
    exec brew bundle --file apps/profiles/base.Brewfile

# First-boot GUI seed: the flathub translation of main's GUI packages
[group('user')]
flatpak-seed:
    #!/usr/bin/env bash
    set -euo pipefail
    # The seed list carries comment lines (# …) and prose with apostrophes, and
    # xargs honours quotes/backslashes — `xargs -a` on the raw file dies with
    # "unmatched single quote". Filter to IDs, then install one at a time so a
    # single unavailable app does not abort the rest of the seed.
    mapfile -t ids < <(grep -Ev '^[[:space:]]*(#|$)' apps/profiles/base.flatpak.txt)
    if [[ ${#ids[@]} -eq 0 ]]; then
        echo "no flatpak IDs in apps/profiles/base.flatpak.txt" >&2
        exit 0
    fi
    failed=0
    for id in "${ids[@]}"; do
        flatpak install --user --noninteractive flathub "$id" ||
            { echo "flatpak install failed: $id" >&2; failed=1; }
    done
    exit "$failed"

# Print the image name (used by CI)
[group('image')]
image-name:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ image_name }}"

# Build the image using the specified parameters:
#   just image-build [target_image] [tag]
[group('image')]
image-build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -euo pipefail

    BUILD_ARGS=()
    LABELS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ source_repo }}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.documentation=https://raw.githubusercontent.com/{{ source_repo }}/${GIT_SHA}/docs/installation.md")
        LABELS+=("--label" "org.opencontainers.image.source=https://github.com/{{ source_repo }}/blob/${GIT_SHA}/Containerfile")
        LABELS+=("--label" "org.opencontainers.image.url=https://github.com/{{ source_repo }}/tree/${GIT_SHA}")
        LABELS+=("--label" "org.opencontainers.image.version={{ default_tag }}.$(date +%Y%m%d)-${GIT_SHA}")
    fi

    # Image metadata for https://artifacthub.io/
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords={{ image_keywords }}")
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url={{ image_logo_url }}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description={{ image_desc }}")
    LABELS+=("--label" "org.opencontainers.image.title={{ image_name }}")
    LABELS+=("--label" "org.opencontainers.image.vendor={{ repo_organization }}")

    # atomic-workstation: configurable base image (see image-template.env)
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE={{ base_image }}")

    # This actually builds the image!
    PODMAN_BUILD_ARGS=("${BUILD_ARGS[@]}" "${LABELS[@]}" --pull=newer --tag "${target_image}:${tag}" --file Containerfile)

    podman build "${PODMAN_BUILD_ARGS[@]}" .

# Split the image for smaller updates (new, chunkah)
[group('image')]
image-rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    CHUNKAH_CONFIG_FILE="$(mktemp)"

    # You may run into space issues on github runners as we are making a
    # complete copy of the image, which likely has no shared layers, unless your
    # base image is also using chunkah
    CHUNKAH_OUTPUT_DIR="$(mktemp -d ./"${target_image}"_chunkah_XXXXXX)"

    trap 'rm -f "${CHUNKAH_CONFIG_FILE}"; rm -rf "${CHUNKAH_OUTPUT_DIR}"' EXIT
    podman inspect "${target_image}:${tag}" > "${CHUNKAH_CONFIG_FILE}"

    podman run --rm \
      --mount=type=image,src="${target_image}:${tag}",target=/chunkah \
      -v "${CHUNKAH_CONFIG_FILE}:/chunkah-config.json:ro,Z" \
      -v "${CHUNKAH_OUTPUT_DIR}:/run/out:Z" \
      quay.io/coreos/chunkah:latest \
      build \
      --verbose \
      --compressed \
      --max-layers 128 \
      --prune /sysroot/ \
      --label ostree.commit- --label ostree.final-diffid- \
      --config /chunkah-config.json \
      --output oci:/run/out/chunked

    CHUNKED_IMAGE="$(podman pull "oci:${CHUNKAH_OUTPUT_DIR}/chunked")"
    podman tag "${CHUNKED_IMAGE}" "${target_image}:${tag}"

# Split the image for smaller updates (classical rpm-ostree; used by CI)
[group('image')]
image-ostree-rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    # Use the already-built local image to avoid pulling from a remote registry
    RPM_OSTREE_CHUNKER_IMAGE="localhost/${target_image}:${tag}"

    GRAPHROOT="$(podman info --format '{{ '{{.Store.GraphRoot}}' }}')"

    podman run --rm --pull=never --privileged \
      --mount=type=image,src="${target_image}:${tag}",target=/rpm-ostree \
      --mount=type=bind,src=${GRAPHROOT},target=/run/host-container-storage,rw \
      --mount=type=tmpfs,target=/run/rpm-ostree-storage \
      --entrypoint /usr/bin/rpm-ostree \
      "${RPM_OSTREE_CHUNKER_IMAGE}" \
      compose build-chunked-oci \
      --max-layers 127 \
      --format-version=2 \
      --bootc \
      --rootfs /rpm-ostree \
      --output "containers-storage:[overlay@/run/host-container-storage+/run/rpm-ostree-storage]localhost/${target_image}:${tag}"

# Generate Default Tag
[group('image')]
image-generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "${tag}"

# Generate Tags
[group('image')]
image-generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
        BUILD_TAGS+=("${DATE}-${GIT_SHA}")
    fi

    BUILD_TAGS+=("${DATE}")
    BUILD_TAGS+=("${tag}")
    BUILD_TAGS+=("${tag}-${DATE}")

    echo "${BUILD_TAGS[@]}"

# Tag Images
[group('image')]
image-tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Get Image, and untag
    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}

    # Tag Image
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done

    # Show Images
    podman images

# Clean image build outputs
[group('image')]
image-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    touch _build
    find *_build* -exec rm -rf {} +
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/
