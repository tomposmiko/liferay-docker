#!/bin/bash

source _bom.sh
source _liferay_common.sh
source _publishing.sh

function check_usage {
	if [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	ARTIFACT_RC_VERSION="${LIFERAY_RELEASE_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

    lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_PROMOTION_DIR="${PWD}/release-data/promotion/files"

    rm -rf "${_PROMOTION_DIR}"
    mkdir -p "${_PROMOTION_DIR}"

    lc_cd "${_PROMOTION_DIR}"

    LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function _download_from_nexus {
	local file_url="${1}"
	local file_name="${2}"

	lc_log DEBUG "Downloading ${file_url} to ${file_name}."

	curl \
		--fail \
		--max-time 300 \
		--output "${file_name}" \
		--retry 3 \
		--retry-delay 10 \
		--silent \
		--user "${NEXUS_REPOSITORY_USER}:${NEXUS_REPOSITORY_PASSWORD}" \
		"${file_url}"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download ${file_url} to ${file_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _download_bom_file {
	if [ -z "${NEXUS_REPOSITORY_USER}" ] || [ -z "${NEXUS_REPOSITORY_PASSWORD}" ]
	then
		 lc_log ERROR "Either \${NEXUS_REPOSITORY_USER} or \${NEXUS_REPOSITORY_PASSWORD} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local file_url="${1}"
	local file_name="${2}"

	_download_from_nexus "${file_url}" "${file_name}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.md5" "${file_name}.md5" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.sha512" "${file_name}.sha512" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	verify_checksum "${file_name}"
}

function _verify_checksum {
	file="${1}"

	(
		sed -z "s/\n$//" "${file}.sha512"
		echo "  ${file}"
	) | sha512sum -c - --status

	if [ "${?}" != "0" ]
	then
		lc_log ERROR "Unable verify the checksum of ${file}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function prepare_jars {
	local repository_name="${1}"

	local nexus_url="https://repository.liferay.com/nexus/service/local/repositories"

	for jar_rc_name in "release.dxp.api-${ARTIFACT_RC_VERSION}.jar" "release.dxp.api-${ARTIFACT_RC_VERSION}-sources.jar"
	do
		jar_release_name="${jar_rc_name/-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}/}"

        _download_from_nexus "${nexus_url}/${repository_name}/content/com/liferay/portal/release.dxp.api/${ARTIFACT_RC_VERSION}/${jar_rc_name}" "${_PROMOTION_DIR}/${jar_release_name}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
    done
}

function prepare_poms {
	local repository_name="${1}"

	local nexus_url="https://repository.liferay.com/nexus/service/local/repositories"

	for pom_name in release.dxp.api release.dxp.bom release.dxp.bom.compile.only release.dxp.bom.third.party
    do
        _download_from_nexus "${nexus_url}/${repository_name}/content/com/liferay/portal/${pom_name}/${ARTIFACT_RC_VERSION}/${pom_name}-${ARTIFACT_RC_VERSION}.pom" "${_PROMOTION_DIR}/${pom_name}-${LIFERAY_RELEASE_VERSION}.pom" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
    done

	sed -i "s#<version>${ARTIFACT_RC_VERSION}</version>#<version>${LIFERAY_RELEASE_VERSION}</version>#" ./*.pom
}

function copy_rc {
	if (ssh -i lrdcom-vm-1 root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}" | grep -q "${LIFERAY_RELEASE_VERSION}" &>/dev/null)
	then
		lc_log ERROR "Release was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/dxp/release-candidates/${LIFERAY_RELEASE_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" "/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}"
}

function main {
	check_usage

	#lc_time_run copy_rc

	lc_time_run prepare_poms xanadu
	lc_time_run prepare_jars xanadu
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_VERSION: DXP version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main