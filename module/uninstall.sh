#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/config"

RVPATH="/data/adb/rvhc/${MODDIR##*/}.apk"
if command -v nm >/dev/null 2>&1; then
	NM_BIN="nm"
elif [ -x "/data/adb/modules/nomount/bin/nm" ]; then
	NM_BIN="/data/adb/modules/nomount/bin/nm"
elif [ -x "/data/adb/ksu/bin/nm" ]; then
	NM_BIN="/data/adb/ksu/bin/nm"
elif [ -x "/data/adb/ap/bin/nm" ]; then
	NM_BIN="/data/adb/ap/bin/nm"
fi

if [ -n "$NM_BIN" ] && "$NM_BIN" version >/dev/null 2>&1; then
	"$NM_BIN" rule list 2>/dev/null | while read -r line; do
		case "$line" in
			*" -> $RVPATH"*)
				vpath="${line%% -> *}"
				[ -n "$vpath" ] && "$NM_BIN" rule del "$vpath" >/dev/null 2>&1 || :
				;;
		esac
	done
	am force-stop "$PKG_NAME" || :
fi

rm -f "$RVPATH"
rmdir "/data/adb/rvhc" 2>/dev/null || :

rm -f "/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
