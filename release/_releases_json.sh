#!/bin/bash

function generate_releases_json {
	function write {
		echo -en "${1}" >> "${_PROMOTION_DIR}/releases.json.tmp"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log DEBUG "Updating ${_PROMOTION_DIR}/releases.json."

	local major_version="${_PRODUCT_VERSION%.*}"

	sed \
		-e "s@\"\(${major_version}\)\(.*\),\"promoted\":\"true\"\(.*\)@\"\1\2,\"promoted\":\"false\"\3@" \
		-e "s/^\}/,/" \
		-i \
		"${_PROMOTION_DIR}/releases.json.tmp"

	local liferay_product_version=$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.product.version)

	writeln "\"${_PRODUCT_VERSION}\": {"
	writeln "    \"liferayProductVersion\": \"$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.product.version)\","
	writeln "    \"promoted\": \"true\""
	writeln "}"

	echo "}" >> "${_PROMOTION_DIR}/releases.json.tmp"

	jq "." "${_PROMOTION_DIR}/releases.json.tmp" > "${_PROMOTION_DIR}/releases.json"
}

function get_file_release_properties {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${LIFERAY_RELEASE_VERSION}/release.properties"
}

function get_file_releases_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/dxp/releases.json" "${_PROMOTION_DIR}/releases.json.tmp"

	cp -f "${_PROMOTION_DIR}/releases.json.tmp" "${LIFERAY_COMMON_LOG_DIR}/releases.json.BACKUP.txt"

	sed \
		-r \
		-e 's@\r?\n        "@"@g' \
		-e 's@\r?\n    \}(,)?@\}\1@g' \
		-e 's@[ ]+"@"@g' \
		-i -z \
		"${_PROMOTION_DIR}/releases.json.tmp"
}

function upload_releases_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log INFO "Backing up to /www/releases.liferay.com/dxp/releases.json.BACKUP."

	ssh root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/dxp/releases.json" "/www/releases.liferay.com/dxp/releases.json.BACKUP"

	lc_log DEBUG "Uploading ${_PROMOTION_DIR}/releases.json to /www/releases.liferay.com/dxp/releases.json"

	scp "${_PROMOTION_DIR}/releases.json" root@lrdcom-vm-1:/www/releases.liferay.com/dxp/releases.json
}