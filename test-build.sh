#!/usr/bin/env bash
#
# Run a test build for all images.

set -uo pipefail
IFS=$'\n\t'

info() {
  printf "%s\n" "$@"
}

fatal() {
  printf "**********\n"
  printf "%s\n" "$@"
  printf "**********\n"
  exit 1
}

cd "$(cd "${0%/*}" && pwd -P)" || exit;

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
  versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
  # Skip "docs" and other non-docker directories
  [ -f "$version/Dockerfile" ] || continue

  tag=$(grep "ENV NODE_VERSION" "$version/Dockerfile" | cut -d' ' -f3)

  info "Building $tag..."

  if ! docker build -t node:"$tag" "$version"; then
    fatal "Build of $tag failed!"
  else
    info "Build of $tag succeeded."
  fi

  OUTPUT=$(docker run --rm -it node:"$tag" node -e "process.stdout.write(process.versions.node)")
  if [ "$OUTPUT" != "$tag" ]; then
    fatal "Test of $tag failed!"
  else
    info "Test of $tag succeeded."
  fi

  variants=$(echo "$version"/*/ | xargs -n1 basename)

  for variant in $variants; do
    # Skip non-docker directories
    [ -f "$version/$variant/Dockerfile" ] || continue

    info "Building $tag-$variant variant..."

    if ! docker build -t node:"$tag-$variant" "$version/$variant"; then
      fatal "Build of $tag-$variant failed!"
    else
      info "Build of $tag-$variant succeeded."
    fi

    OUTPUT=$(docker run --rm -it node:"$tag-$variant" node -e "process.stdout.write(process.versions.node)")
    if [ "$OUTPUT" != "$tag" ]; then
      fatal "Test of $tag-$variant failed!"
    else
      info "Test of $tag-$variant succeeded."
    fi

  done

done

info "All builds successful!"

exit 0
