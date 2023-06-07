#!/bin/bash

#
# Do NOT edit this file unless you are editing this file in the root directory
# of the the liferay-docker repository. Edit that file, and then fork it to the
# repository where it is used.
#

function lc_cd {
	cd "${1}" || exit ${LIFERAY_COMMON_EXIT_CODE_CD}
}

function lc_check_utils {
	for util in "${@}"
	do
		if (! command -v "${util}" &>/dev/null)
		then
			lc_log ERROR "The utility ${util} is not installed."

			exit ${LIFERAY_COMMON_EXIT_CODE_BAD}
		fi
	done
}

function lc_date {
	export LC_ALL=en_US.UTF-8
	export TZ=America/Los_Angeles

	if [ -z ${1+x} ] || [ -z ${2+x} ]
	then
		if [ "$(uname)" == "Darwin" ]
		then
			/bin/date
		elif [ -e /bin/date ]
		then
			/bin/date --iso-8601=seconds
		else
			/usr/bin/date --iso-8601=seconds
		fi
	else
		if [ "$(uname)" == "Darwin" ]
		then
			/bin/date -jf "%a %b %e %H:%M:%S %Z %Y" "${1}" "${2}"
		elif [ -e /bin/date ]
		then
			/bin/date -d "${1}" "${2}"
		else
			/usr/bin/date -d "${1}" "${2}"
		fi
	fi
}

function lc_download {
	local file_url=${1}

	if [ -z "${file_url}" ]
	then
		lc_log ERROR "File URL is not set."

		return ${LIFERAY_COMMON_EXIT_CODE_BAD}
	fi

	local file_name=${2}

	if [ -z "${file_name}" ]
	then
		file_name=${file_url##*/}
	fi

	if [ -e "${file_name}" ]
	then
		lc_log DEBUG "Skipping the download of ${file_url} because it already exists."

		return
	fi

	local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

	if [ -e "${cache_file}" ]
	then
		lc_log DEBUG "Copying file from cache: ${cache_file}."

		cp "${cache_file}" "${file_name}"

		return
	fi

	mkdir -p $(dirname "${cache_file}")

	lc_log DEBUG "Downloading ${file_url}."

	local current_date=$(lc_date)

	local timestamp=$(lc_date "${current_date}" "+%Y%m%d%H%M%S")

	if (! curl "${file_url}" --fail --output "${cache_file}.temp${timestamp}" --silent)
	then
		lc_log ERROR "Unable to download ${file_url}."

		return ${LIFERAY_COMMON_EXIT_CODE_BAD}
	else
		mv "${cache_file}.temp${timestamp}" "${cache_file}"

		cp "${cache_file}" "${file_name}"
	fi
}

function lc_log {
	local level=${1}
	local message=${2}

	if [ "${level}" != "DEBUG" ] || [ "${LIFERAY_COMMON_LOG_LEVEL}" == "DEBUG" ]
	then
		echo "$(lc_date) [${level}] ${message}"
	fi
}

function _lc_init {
	if [ -z "${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}" ]
	then
		LIFERAY_COMMON_DOWNLOAD_CACHE_DIR=${HOME}/.liferay-common-cache
	fi

	LIFERAY_COMMON_EXIT_CODE_BAD=1
	LIFERAY_COMMON_EXIT_CODE_CD=3
	LIFERAY_COMMON_EXIT_CODE_HELP=2
	LIFERAY_COMMON_EXIT_CODE_OK=0
}

_lc_init