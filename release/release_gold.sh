#!/bin/bash

source _liferay_common.sh
source _promotion.sh
source _publishing.sh

RELEASE_PROPERTIES_FILE="release-data/release.properties"
LIFERAY_RELEASE_FORK_NAME=${LIFERAY_RELEASE_FORK_NAME:="liferay/liferay-portal.ee"}

function tag_release {
	if ( ! curl --data "{
			\"message\":\"\",
			\"object\":\"$(lc_get_property ${RELEASE_PROPERTIES_FILE} git.hash.liferay-portal-ee)\",
			\"tag\":\"${LIFERAY_RELEASE_VERSION}\",
			\"type\":\"commit\"
			}" \
		--fail \
		--header "Accept: application/vnd.github+json" \
		--header "Authorization: Bearer ${LIFERAY_RELEASE_GITHUB_PAT}" \
		--header "X-GitHub-Api-Version: 2022-11-28" \
		--location https://api.github.com/repos/"${LIFERAY_RELEASE_FORK_NAME}"/git/tags \
		--request POST \
		--silent
		)
	then
		lc_log ERROR "The requested URL could not be accessed."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_usage {
	if [ -z "${LIFERAY_RELEASE_GITHUB_PAT}" ] || [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	_DXP_VERSION="${LIFERAY_RELEASE_VERSION}"

	_ARTIFACT_RC_VERSION="${_DXP_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_PROMOTION_DIR="${PWD}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function copy_rc {
	if (ssh -i lrdcom-vm-1 root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/dxp/${_DXP_VERSION}" | grep -q "${_DXP_VERSION}" &>/dev/null)
	then
		lc_log ERROR "Release was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/dxp/release-candidates/${_ARTIFACT_RC_VERSION}" "/www/releases.liferay.com/dxp/${_DXP_VERSION}"
}

function main {
	check_usage

	lc_time_run prepare_poms_for_promotion xanadu

	lc_time_run prepare_api_jars_for_promotion xanadu

	lc_time_run upload_boms liferay-public-releases

	lc_time_run copy_rc

	lc_time_run tag_release
}

function print_help {
    echo "Usage: (LIFERAY_RELEASE_FORK_NAME=<username/repository_name>) LIFERAY_RELEASE_GITHUB_PAT=<Personal Access Token> LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
    echo ""
    echo "The script reads the following environment variables:"
    echo ""
	echo "    LIFERAY_RELEASE_FORK_NAME (optional): The repository owner's git username, defaults to 'liferay' and the repository's name"
    echo "    LIFERAY_RELEASE_GITHUB_PAT: The user's Personal Access Token"
    echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
    echo "    LIFERAY_RELEASE_VERSION: DXP version of the release to publish"
	echo ""
    echo "Example: LIFERAY_RELEASE_FORK_NAME=<username/repository_name> LIFERAY_RELEASE_GITHUB_PAT=<personal access token> LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

    exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main