function __print_pb_functions_help() {
    cat <<EOF
Additional PBRP functions (standard lunch and m remain available):
- breakfast <product> <release> [variant]: A17 lunch; variant defaults to userdebug.
  breakfast <product>-<release>-<variant> also accepts a full lunch target.
- mka [arguments]: Alias-style wrapper for m; normal A17 job selection applies.
- recoverybuild <bootimage|recoveryimage|vendorbootimage> [m arguments]:
  Build the image required by the selected device; never flash or reboot.
- recoveryout: Change directory to the selected product's output directory.
- recoverypackage <repo-relative Python script> [arguments]: Run the selected
  device's packaging/validation script; no Alioth path is assumed.
- repopick: Fetch changes from Gerrit.
EOF
}

function breakfast() {
    if [[ $# == 1 && "$1" == *-*-* ]]; then
        lunch "$1"
    elif [[ $# == 2 || $# == 3 ]]; then
        lunch "$1" "$2" "${3:-userdebug}"
    else
        echo "Usage: breakfast <product> <release> [variant] or <product>-<release>-<variant>" >&2
        return 2
    fi
}

function recoverybuild() {
    if [[ -z "${TARGET_PRODUCT:-}" || -z "${TARGET_BUILD_VARIANT:-}" ]]; then
        echo "Select a device first: lunch <product> <release> <variant>" >&2
        return 2
    fi
    local image="${1:-}"
    case "$image" in
        bootimage|recoveryimage|vendorbootimage) shift ;;
        *) echo "Usage: recoverybuild <bootimage|recoveryimage|vendorbootimage> [m arguments]" >&2; return 2 ;;
    esac
    m "$@" "$image"
}

function recoveryout() {
    local output
    output="${ANDROID_PRODUCT_OUT:-}"
    [[ -n "$output" && -d "$output" ]] || {
        echo "Product output does not exist; select and build a device first." >&2
        return 1
    }
    cd "$output"
}

function recoverypackage() {
    local top script
    top=$(gettop) || return
    if [[ -z "$top" || -z "${TARGET_PRODUCT:-}" || $# == 0 ]]; then
        echo "Usage after lunch: recoverypackage <repo-relative Python script> [arguments]" >&2
        return 2
    fi
    script=$(realpath -e -- "$top/$1") || return
    case "$script" in
        "$top"/*.py) ;;
        *) echo "Packaging script must be a Python file inside this recovery checkout." >&2; return 2 ;;
    esac
    [[ -f "$script" ]] || return 2
    shift
    (cd "$top" && python3 "$script" "$@")
}

alias bib=breakfast
alias cout=recoveryout

function mka() {
    m "$@"
}

alias twrppick='repopick -g https://gerrit.twrp.me'
