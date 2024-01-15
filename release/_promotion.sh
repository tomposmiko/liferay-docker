#!/bin/bash

function prepare_api_jars_for_promotion {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" ] || [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ]
	then
		 lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local nexus_repository_name="${1}"
	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	for jar_rc_name in "release.dxp.api-${_ARTIFACT_RC_VERSION}.jar" "release.dxp.api-${_ARTIFACT_RC_VERSION}-sources.jar"
	do
		local jar_release_name="${jar_rc_name/-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}/}"

		_download_bom_file "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/release.dxp.api/${_ARTIFACT_RC_VERSION}/${jar_rc_name}" "${_PROMOTION_DIR}/${jar_release_name}"
	done
}

function prepare_poms_for_promotion {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ] || [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" ]
	then
		 lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local nexus_repository_name="${1}"
	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	for pom_name in release.dxp.api release.dxp.bom release.dxp.bom.compile.only release.dxp.bom.third.party
	do
		_download_bom_file "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${pom_name}/${_ARTIFACT_RC_VERSION}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom" "${_PROMOTION_DIR}/${pom_name}-${LIFERAY_RELEASE_VERSION}.pom"
	done

	sed -i "s#<version>${_ARTIFACT_RC_VERSION}</version>#<version>${LIFERAY_RELEASE_VERSION}</version>#" ./*.pom
}

function _download_bom_file {
	local file_name="${2}"
	local file_url="${1}"

	_download_from_nexus "${file_url}" "${file_name}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.md5" "${file_name}.MD5" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.sha512" "${file_name}.sha512" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	_verify_checksum "${file_name}"
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
		--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" \
		"${file_url}"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download ${file_url} to ${file_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _verify_checksum {
	file="${1}"

	(
		sed -z "s/\n$//" "${file}.sha512"

		echo "  ${file}"
	) | sha512sum -c - --status

	if [ "${?}" != "0" ]
	then
		lc_log ERROR "Unable to verify the checksum of ${file}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}