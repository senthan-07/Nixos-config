#!/usr/bin/env bash
# rice ecosystem theming: render the matugen templates and reload the apps.
# Run by services/Ecosystem.qml; everything comes in through the environment:
#
#   RICE_MATUGEN_TOML  generated matugen config (already filtered + resolved)
#   RICE_SOURCE        "image:/path/to/wallpaper" or "color:#rrggbb"
#   RICE_SCHEME        matugen scheme type (scheme-tonal-spot, ...)
#   RICE_MODE          dark | light
#   RICE_INDEX         source colour index 0-4 (images only)
#   RICE_CONTRAST      -1 .. 1
#   RICE_TARGETS       space separated enabled targets (kitty gtk qt btop ...)
#   RICE_STATE_DIR     $XDG_STATE_HOME/rice
#   RICE_CONFIG_DIR    where theme files go (the Dotfiles repo, linked into ~/.config)
#   RICE_LIVE          1 to signal running apps (only inside a Hyprland session)
#
#   apply.sh restore <target>   undo what a target changed outside its own files
#
# Output lines understood by Ecosystem.qml:  "wrote <path>", "warn <text>".

set -u

state=${RICE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rice}
xdg_conf=${XDG_CONFIG_HOME:-$HOME/.config}
conf=${RICE_CONFIG_DIR:-$xdg_conf}

# Make sure ~/.config/<app> points at the Dotfiles copy. New folders are
# linked; a real folder already there is left alone (run Dotfiles/symlink).
link_app() {
    local top=$1
    [[ "$conf" == "$xdg_conf" ]] && return
    local src="$conf/$top" dst="$xdg_conf/$top"
    [[ -e "$src" ]] || return
    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$src" ]] || echo "warn $dst links elsewhere; run Dotfiles/symlink"
    elif [[ -e "$dst" ]]; then
        echo "warn $dst is a real folder; run Dotfiles/symlink to link it"
    else
        ln -sn "$src" "$dst" && echo "warn linked $dst -> $src"
    fi
}
marker="rice-matugen"
kitty_files=(dark-theme.auto.conf light-theme.auto.conf no-preference-theme.auto.conf)
import_line='@import url("rice-colors.css");'

has() { [[ " ${RICE_TARGETS:-} " == *" $1 "* ]]; }
live() { [[ "${RICE_LIVE:-0}" == 1 ]]; }
generated() { [[ -f "$1" ]] && head -n 3 "$1" | grep -q "$marker"; }

restore() {
    case "$1" in
    kitty)
        for f in "${kitty_files[@]}"; do
            p="$conf/kitty/$f"
            if [[ -f "$p.pre-rice" ]]; then
                mv -f "$p.pre-rice" "$p"
            elif generated "$p"; then
                rm -f "$p"
            fi
        done
        live && { pkill -USR1 -x kitty || pkill -USR1 -x .kitty-wrapped; } >/dev/null 2>&1
        ;;
    gtk)
        for v in 3.0 4.0; do
            css="$conf/gtk-$v/gtk.css"
            if [[ -f "$css" ]]; then
                { grep -vF "$import_line" "$css" || true; } >"$css.rice-tmp" && mv -f "$css.rice-tmp" "$css"
                [[ -s "$css" ]] || rm -f "$css"
            fi
            rm -f "$conf/gtk-$v/rice-colors.css"
        done
        ;;
    hyprland)
        rm -f "$conf/hypr/Rice/wallpaper-colors.lua" "$state/hypr-colors.lua"
        live && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload >/dev/null 2>&1
        ;;
    esac
    exit 0
}

[[ "${1:-}" == restore ]] && restore "${2:-}"

command -v matugen >/dev/null || { echo "warn matugen is not installed"; exit 127; }

mkdir -p "$state"
cfg="$state/matugen.toml"
printf '%s\n' "${RICE_MATUGEN_TOML:?}" >"$cfg.tmp" && mv -f "$cfg.tmp" "$cfg"

# --- before rendering: keep the user's own files -------------------------------
if has kitty; then
    for f in "${kitty_files[@]}"; do
        p="$conf/kitty/$f"
        if [[ -f "$p" ]] && ! generated "$p" && [[ ! -e "$p.pre-rice" ]]; then
            cp -p "$p" "$p.pre-rice" && echo "warn kept your $f as $f.pre-rice"
        fi
    done
fi

# --- render --------------------------------------------------------------------
mode=${RICE_MODE:-dark}
args=()
case "${RICE_SOURCE:-}" in
image:*) args=(image "${RICE_SOURCE#image:}" --source-color-index "${RICE_INDEX:-0}") ;;
color:*) args=(color hex "${RICE_SOURCE#color:}") ;;
*) echo "warn nothing to generate colours from"; exit 2 ;;
esac

err=$(matugen "${args[@]}" -c "$cfg" -t "${RICE_SCHEME:-scheme-tonal-spot}" -m "$mode" \
    --contrast "${RICE_CONTRAST:-0}" --continue-on-error -q 2>&1 >/dev/null)
rc=$?
[[ -n "$err" ]] && printf '%s\n' "$err" | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^\s*$' | head -n 5 | sed 's/^/warn /'

# --- after rendering: hook files in and reload -------------------------------
if has gtk; then
    for v in 3.0 4.0; do
        css="$conf/gtk-$v/gtk.css"
        [[ -f "$conf/gtk-$v/rice-colors.css" ]] || continue
        if [[ ! -f "$css" ]]; then
            printf '%s\n' "$import_line" >"$css"
        elif ! grep -qF "$import_line" "$css"; then
            { printf '%s\n' "$import_line"; cat "$css"; } >"$css.rice-tmp" && mv -f "$css.rice-tmp" "$css"
        fi
    done
fi

if has qt; then
    for v in 5 6; do
        ini="$conf/qt${v}ct/qt${v}ct.conf"
        [[ -f "$conf/qt${v}ct/colors/rice.conf" && ! -e "$ini" ]] || continue
        printf '[Appearance]\ncustom_palette=true\ncolor_scheme_path=%s\nstyle=Fusion\n' \
            "$conf/qt${v}ct/colors/rice.conf" >"$ini"
    done
fi

# Report what exists now (matugen is quiet about it) and link app folders.
while IFS= read -r out; do
    [[ -f "$out" ]] || continue
    echo "wrote $out"
    if [[ "$out" == "$conf"/* ]]; then
        rel=${out#"$conf"/}
        link_app "${rel%%/*}"
    fi
done < <(sed -n 's/^output_path = "\(.*\)"$/\1/p' "$cfg")

if live; then
    has kitty && { pkill -USR1 -x kitty || pkill -USR1 -x .kitty-wrapped; } >/dev/null 2>&1
    has btop && pkill -USR2 -x btop >/dev/null 2>&1
    has cava && pkill -USR2 -x cava >/dev/null 2>&1
    if has gtk && command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode" >/dev/null 2>&1
    fi
    if has hyprland && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl reload >/dev/null 2>&1
    fi
fi

exit $rc
