#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
export MODDIR
. "$MODDIR/utils.sh"

echo ""

DFILE="$MODDIR/disabled_by_action"

if ! is_injected; then
	rm -f "$DFILE"
	if mount_rv_now; then
		echo "* Enabled successfully"
		cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
	else
		echo "* Failed to enable"
	fi
	echo ""
	if has_nomount; then
		$(get_nm_bin) rule list 2>/dev/null | grep -F " -> $RVPATH"
	else
		get_mounts
	fi
else
	touch "$DFILE"
	umount_all
	echo "* Disabled successfully"

	ch_desc "⛔ Disabled by action"
fi
