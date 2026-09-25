#!/system/bin/sh

RVPATH=/data/adb/rvhc/${MODDIR##*/}.apk
. "$MODDIR/config"

ch_desc() {
	sed -i "s|^description=.*|description=${1}|" "$MODDIR/module.prop"
}

ch_desc_err() {
	ch_desc "⚠️ Needs reflash: '${1}'"
}

get_nm_bin() {
	if command -v nm >/dev/null 2>&1; then
		echo "nm"
	elif [ -x "/data/adb/modules/nomount/bin/nm" ]; then
		echo "/data/adb/modules/nomount/bin/nm"
	elif [ -x "/data/adb/ksu/bin/nm" ]; then
		echo "/data/adb/ksu/bin/nm"
	elif [ -x "/data/adb/ap/bin/nm" ]; then
		echo "/data/adb/ap/bin/nm"
	fi
}

has_nomount() {
	local nm_bin
	nm_bin=$(get_nm_bin)
	[ -n "$nm_bin" ] && "$nm_bin" version >/dev/null 2>&1
}

pmex() {
	OP=$(pm "$@" 2>&1 </dev/null)
	RET=$?
	echo "$OP"
	return $RET
}

get_app_version() {
	VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName=) VERSION="${VERSION#*=}"
	echo "$VERSION"
}

get_basepath() {
	BASEPATH=$(pmex path "$PKG_NAME")
	SVCL=$?

	BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
	echo "$BASEPATH"
	return $SVCL
}

umount_all() {
	if has_nomount; then
		local nm_bin
		nm_bin=$(get_nm_bin)
		if BASEPATH=$(get_basepath 2>/dev/null); then
			"$nm_bin" rule del "${BASEPATH}/base.apk" >/dev/null 2>&1 || :
		fi
		"$nm_bin" rule list 2>/dev/null | while read -r line; do
			case "$line" in
				*" -> $RVPATH"*)
					vpath="${line%% -> *}"
					[ -n "$vpath" ] && "$nm_bin" rule del "$vpath" >/dev/null 2>&1 || :
					;;
			esac
		done
	fi
	su -M -c grep -F "$PKG_NAME" /proc/mounts | while read -r line; do
		mp=${line#* } mp=${mp%% *} mp=${mp%%\\*}
		su -M -c umount -l "${mp}"
	done
	am force-stop "$PKG_NAME" || :
}

get_mounts() {
	su -M -c grep -F "$PKG_NAME" /proc/mounts || :
}

is_injected() {
	if has_nomount; then
		local nm_bin
		nm_bin=$(get_nm_bin)
		"$nm_bin" rule list 2>/dev/null | grep -qF " -> $RVPATH"
	else
		[ -n "$(get_mounts)" ]
	fi
}

mount_rv() {
	local target_base="${1}/base.apk"
	if [ ! -d "${1}/lib" ]; then
		ch_desc_err "Your installation got broken. Dont report this, consider using rvmm-zygisk-mount."
		return 1
	fi
	VERSION=$(get_app_version)
	if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
		ch_desc_err "Version mismatch (installed:$VERSION, module:$PKG_VER)"
		return 1
	fi
	umount_all
	if ! OP=$(chcon u:object_r:apk_data_file:s0 "$RVPATH" 2>&1); then
		ch_desc_err "Error chcon: '$OP'"
		return 1
	fi

	if has_nomount; then
		local nm_bin
		nm_bin=$(get_nm_bin)
		"$nm_bin" rule del "$target_base" >/dev/null 2>&1 || :
		if "$nm_bin" rule add "$target_base" "$RVPATH"; then
			am force-stop "$PKG_NAME"
			cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
			return 0
		fi
	fi

	mount -o bind "$RVPATH" "$target_base"
	am force-stop "$PKG_NAME"
	cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
	return 0
}

mount_rv_now() {
	if ! BASEPATH=$(get_basepath); then
		ch_desc_err "App not installed: '$BASEPATH'"
		return 1
	fi
	mount_rv "$BASEPATH"
}
