#!/usr/bin/env bash
# set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x
set -e

##

RELEASE="prometheus-extra-dashboards"
DESCRIPTION="BOSH release add-on for prometheus-boshrelease to add custom resources: alerts, dashboards, etc"
GITHUB_REPO="dohq/prometheus-extra-dashboards-boshrelease"

##
MAIN_MANIFEST="manifests/prometheus-extra-dashboards.yml"

###

BOSH_CLI=${BOSH_CLI:-bosh}
JQ=jq
CURL="curl -s"
SHA1="sha1sum -b"
RE_VERSION_NUMBER='^[0-9]+([0-9\.]*[0-9]+)*$'

###
case $# in
    0)
        echo "*** Creating a new release. Automatically calculating next release version number"
        ;;
    1)
        if [ $1 == "-h" ] || [ $1 == "--help" ]
        then
            echo "Usage:  $0 [version-number]"
            echo "  Creates a new boshrelease, commits the changes to this repository using tags and uploads "
            echo "  the release to Github releases. It also adds comments based on previous git commits and "
            echo "  calculates the sha1 checksum."
            exit 0
        else
            version=$1
            if ! [[ $version =~ $RE_VERSION_NUMBER ]]
            then
                echo "ERROR: Incorrect version number!"
                exit 1
            fi
            echo "*** Creating a new release. Using release version number $version."
        fi
        ;;
    *)
        echo "ERROR: incorrect argument. See '$0 --help'"
        exit 1
        ;;
esac


# Get the last git commit made by this script
lastcommit=$(git log --format="%h" --grep="$RELEASE v*" | head -1)
echo "* Changes since last version with commit $lastcommit: "
git_changes=$(git log --pretty="%h %aI %s (%an)" $lastcommit..@ | sed 's/^/- /')
if [ -z "$git_changes" ]
then
    echo "Error, no commits since last release with commit $lastcommit!. Please "
    echo "commit your changes to create and publish a new release!"
    exit 1
fi
echo "$git_changes"

# Bump to manifest
echo "* Auto Bump Version manifest to $version"
sed -i -e "s/version:.*/version: $version/g" $MAIN_MANIFEST
git add $MAIN_MANIFEST
git commit -m "[mod] Bump version to v$version"

# tagging
git tag v$version


# Uploading blobs
echo "* Uploading blobs to the blobstore ..."
$BOSH_CLI upload-blobs

# Creating the release
if [ -z "$version" ]
then
    echo "* Creating final release ..."
    $BOSH_CLI create-release --force --final --tarball="/tmp/$RELEASE-$$.tgz" --name "$RELEASE"
    # Get the version of the release
    version=$(ls releases/$RELEASE/$RELEASE-*.yml | sed 's/.*\/.*-\(.*\)\.yml$/\1/' | sort -rn | head -1)
else
    echo "* Creating final release version $version ..."
    $BOSH_CLI create-release --force --final --tarball="/tmp/$RELEASE-$$.tgz" --name "$RELEASE" --version "$version"
fi

# Create a new tag and update the changes
echo "* Commiting git changes ..."
git add .final_builds releases/$RELEASE/index.yml "releases/$RELEASE/$RELEASE-$version.yml" final_blobs
git commit -m "$RELEASE v$version Boshrelease"
git push
git push --tags

# Create a release in Github
echo "* Creating a new release in Github ... "
sha1=$($SHA1 "/tmp/$RELEASE-$$.tgz" | cut -d' ' -f1)
description=$(cat <<EOF
# $RELEASE version $version

$DESCRIPTION

## Changes since last version

$git_changes

## Using in a bosh Deployment

    releases:
    - name: $RELEASE
      url: https://github.com/${GITHUB_REPO}/releases/download/v${version}/${RELEASE}-${version}.tgz
      version: $version
      sha1: $sha1
EOF
)
printf -v DATA '{"tag_name": "v%s","target_commitish": "master","name": "v%s","body": %s,"draft": false, "prerelease": false}' "$version" "$version" "$(echo "$description" | $JQ -R -s '@text')"
releaseid=$($CURL -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/json" -XPOST --data "$DATA" "https://api.github.com/repos/$GITHUB_REPO/releases" | $JQ '.id')

# Upload the release
echo "* Uploading tarball to Github releases section ... "
echo -n "  URL: "
$CURL -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @"/tmp/$RELEASE-$$.tgz" "https://uploads.github.com/repos/$GITHUB_REPO/releases/$releaseid/assets?name=$RELEASE-$version.tgz" | $JQ -r '.browser_download_url'

# Delete the release
rm -f "/tmp/$RELEASE-$$.tgz"

echo
echo "*** Description https://github.com/$GITHUB_REPO/releases/tag/v$version: "
echo
echo "$description"
exit 0
