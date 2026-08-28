#!/usr/bin/env bash
#
# install.sh — ParrotOS 7 "Echo" tool installer (cross-platform)
# Source: ParrotSec/parrot-tools (official metapackage definitions)
# Repo:   https://github.com/kaorii-ako/project-hax
#
# These tools are packaged for ParrotOS / Debian. This installer works in two
# modes:
#
#   1. NATIVE  — detects your package manager (apt, dnf, rpm-ostree, pacman,
#                zypper, brew) and installs every tool that exists under a
#                matching name, one package at a time, and reports the rest.
#
#   2. CONTAINER (-d) — the recommended path on Fedora/Bazzite/macOS/immutable
#                systems: creates a ParrotOS distrobox and runs the full apt
#                install inside it, giving 100% coverage without touching your
#                base OS. Requires distrobox + podman/docker.
#
# Usage:
#   ./install.sh                 # native best-effort install for this OS
#   ./install.sh -d              # install everything inside a Parrot distrobox
#   ./install.sh -c Dev,Cloud    # only listed categories (native)
#   ./install.sh -l              # list categories and exit
#   ./install.sh -y              # assume yes (no prompt)
#   ./install.sh -h              # help
#
set -uo pipefail

# ----------------------------------------------------------------------------
# Colors / logging
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
    C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_BOLD=$'\033[1m'
else
    C_RESET=''; C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_BOLD=''
fi
log()   { printf '%s[*]%s %s\n' "$C_BLU" "$C_RESET" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YEL" "$C_RESET" "$*"; }
err()   { printf '%s[-]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
header(){ printf '\n%s%s==> %s%s\n' "$C_BOLD" "$C_BLU" "$*" "$C_RESET"; }

# ----------------------------------------------------------------------------
# Package definitions (category -> space-separated Debian package names)
# ----------------------------------------------------------------------------
declare -A CATEGORIES
CATEGORIES[AI]="hexstrike-ai"
CATEGORIES[Development]="geany codium git neovim python3 python3-pip python3-venv g++ gcc golang gdb cgdb dbeaver git-cola meld sqlitebrowser build-essential cmake cython3 devscripts edb-debugger flasm jad mono-devel mono-runtime nasm qtcreator valgrind clang python3-aiohttp python3-keras python3-matplotlib python3-opencv python3-requests python3-virtualenv nodejs npm powershell nim libnim-gintro-dev"
CATEGORIES[Crypto]="zulucrypt-cli zulucrypt-gui zulumount-gui zulupolkit cryfs encryptpad gocryptfs seahorse gpa sirikali"
CATEGORIES[Privacy]="anonsurf anonsurf-cli anonsurf-gtk tor torbrowser-launcher mat2 nyx onionshare onioncircuits"
CATEGORIES[InformationGathering]="0trace 2ping amap arp-scan arping autorecon braa dmitry dnsenum dnsmap emailharvester enum4linux etherape fping gobuster hping3 ike-scan inspy instaloader intrace irpas ismtp lbd maltego masscan nbtscan netcat-openbsd netdiscover nmap nmapsi4 onesixtyone p0f patchleaks python3-shodan recon-ng rocket sherlock smbclient smbmap smtp-user-enum snmpcheck ssldump sslh sslscan sslyze swaks thc-ipv6 theharvester unicornscan"
CATEGORIES[VulnerabilityAnalysis]="afl cisco-ocs cisco-torch copy-router-config dhcpig doona dsniff enumiax gvm iaxflood inviteflood ohrwurm protos-sip rocket rtpbreak rtpflood rtpinsertsound rtpmixsound sctpscan siparmyknife sipp sipvicious slowhttptest spike thc-ssl-dos unix-privesc-check voiphopper yersinia"
CATEGORIES[WebApplicationAnalysis]="burpsuite caido commix davtest dirb dirbuster ffuf gobuster goshs joomscan jsql-injection nikto padbuster parsero rocket skipfish wafw00f wfuzz whatweb wig wpscan xsser zaproxy"
CATEGORIES[ExploitationTools]="armitage backdoor-factory beef-xss bloodhound commix convoc2 evil-winrm jsql-injection kerberoast king-phisher mdbtools metasploit-framework mimikatz netexec oscanner pompem powershell powershell-empire rocket set shellnoob sidguesser sqldict sqlitebrowser sqlmap sqlninja sqlsus starkiller thc-ipv6 unicorn-magic websploit"
CATEGORIES[MaintainingAccess]="backdoor-factory chisel convoc2 dbd dns2tcp evil-winrm hyperion iodine laudanum ncat-w32 netcat-openbsd nishang powercat powershell powershell-empire proxychains proxytunnel ptunnel pwnat rocket sbd shellter sliver socat sslh starkiller stunnel4 udptunnel webacoo webshells weevely windows-binaries"
CATEGORIES[PostExploitation]="linux-exploit-suggester lynis mimikatz passing-the-hash peass powersploit wce xspy"
CATEGORIES[PasswordAttacks]="brutespray cewl changeme chntpw cmospwd crackle crunch device-pharmer fcrackzip hashcat hashid hydra john johnny medusa onesixtyone ophcrack ophcrack-cli pack pdfcrack pipal pixiewps rainbowcrack rarcrack rcracki-mt rsmangler samdump2 sipcrack statsprocessor sucrack thc-pptp-bruter truecrack twofi wordlists"
CATEGORIES[WirelessAttacks]="aircrack-ng airgeddon asleap bluelog blueranger bluesnarfer bluez-hcidump btscanner bully cowpatty crackle eapmd5pass fern-wifi-cracker hackrf inspectrum king-phisher libfreefare-bin libnfc-bin mdk3 mfcuk mfoc mfterm pixiewps reaver redfang rfcat rtlsdr-scanner ubertooth wifi-honey wifite yersinia"
CATEGORIES[SniffingSpoofing]="bettercap chaosreader darkstat dnschef driftnet dsniff etherape ettercap-graphical fiked hamster-sidejack hexinject isr-evilgrade mitmproxy netsniff-ng rebind responder sniffjoke sslsniff sslsplit tcpflow tcpreplay thc-ipv6 wifi-honey wireshark yersinia"
CATEGORIES[Forensics]="afflib-tools autopsy binwalk cabextract dc3dd dcfldd ddrescue dex2jar dumpzilla ewf-tools extundelete foremost forensic-artifacts galleta gpp-decrypt gtkhash guymager hashdeep magicrescue missidentify pasco pdf-parser pdfid pev recoverjpeg reglookup regripper rifiuti rifiuti2 rsync safecopy scalpel scrounge-ntfs sleuthkit smartmontools vinetto xplico yara"
CATEGORIES[Automotive]="can-utils gscanbus ow-shell ow-tools scantool"
CATEGORIES[ReverseEngineering]="bpf-linker clang dex2jar edb-debugger firmware-mod-kit gdb ghidra javasnoop rizin rizin-cutter smali"
CATEGORIES[Reporting]="eyewitness logseq"
CATEGORIES[Cloud]="arping awscli azure-cli cloud-enum cloudbrute davtest dirb dirbuster dmitry dns2tcp dnschef dnsenum dnsmap etherwake fping godoh hping3 iodine isr-evilgrade joomscan maskprocessor medusa metasploit-framework ncrack netdiscover netexec nikto node-aws4 nmap p0f rclone rsync s3backer s3scanner sbd sfuzz siege skipfish socat sqlmap sqlninja sqlsus syft t50 tcpdump thc-ipv6 thc-ssl-dos traceroute trufflehog webshells websploit weevely whatweb whois"

CATEGORY_ORDER=(AI Development Crypto Privacy InformationGathering VulnerabilityAnalysis \
    WebApplicationAnalysis ExploitationTools MaintainingAccess PostExploitation \
    PasswordAttacks WirelessAttacks SniffingSpoofing Forensics Automotive \
    ReverseEngineering Reporting Cloud)

# ----------------------------------------------------------------------------
# Per-manager name remaps: "debianname" -> "actual package name for this mgr"
# Only entries that genuinely exist & differ. Empty string = skip (no equiv).
# ----------------------------------------------------------------------------
declare -A MAP_BREW MAP_DNF
# Homebrew (formula names; things that exist cross-platform)
MAP_BREW=( [g++]="gcc" [golang]="go" [netcat-openbsd]="netcat" [ncat-w32]="ncat"
    [python3-pip]="python@3.12" [python3-venv]="" [build-essential]="" [codium]=""
    [python3-requests]="" [python3-shodan]="shodan" [john]="john-jumbo"
    [rizin-cutter]="cutter" [metasploit-framework]="metasploit" )
# Fedora / dnf
MAP_DNF=( [g++]="gcc-c++" [build-essential]="@development-tools" [golang]="golang"
    [netcat-openbsd]="nmap-ncat" [python3-pip]="python3-pip" [codium]=""
    [python3-venv]="python3-virtualenv" [sqlitebrowser]="sqlitebrowser"
    [mono-devel]="mono-devel" [john]="john" )

# ----------------------------------------------------------------------------
# Globals
# ----------------------------------------------------------------------------
SUDO=""
PKG_MGR=""
INSTALL_CMD=""
UPDATE_CMD=""
FAILED_PKGS=()
INSTALLED_COUNT=0

usage() {
    cat << EOF
${C_BOLD}install.sh${C_RESET} — ParrotOS 7 "Echo" tool installer (cross-platform)

Usage:
  ./install.sh [options]

Options:
  -d                Container mode: install everything in a ParrotOS distrobox
                    (recommended on Fedora/Bazzite/macOS/immutable systems).
  -c CAT[,CAT...]   Install only the given categories (native mode).
  -l                List categories and exit.
  -y                Assume yes; do not prompt.
  -h                Show this help.

Categories:
$(for c in "${CATEGORY_ORDER[@]}"; do printf '  - %s\n' "$c"; done)
EOF
}

# ----------------------------------------------------------------------------
# Package-manager detection
# ----------------------------------------------------------------------------
detect_pkg_mgr() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt";   UPDATE_CMD="apt-get update"; INSTALL_CMD="apt-get install -y --no-install-recommends"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf";   UPDATE_CMD="dnf -y makecache"; INSTALL_CMD="dnf install -y"
    elif command -v rpm-ostree >/dev/null 2>&1; then
        PKG_MGR="rpm-ostree"; UPDATE_CMD=":"; INSTALL_CMD="rpm-ostree install -y --idempotent"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"; UPDATE_CMD="pacman -Sy"; INSTALL_CMD="pacman -S --needed --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"; UPDATE_CMD="zypper refresh"; INSTALL_CMD="zypper install -y"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew";  UPDATE_CMD="brew update"; INSTALL_CMD="brew install"
    else
        PKG_MGR=""
    fi
}

# Root handling — brew must NOT run as root; system managers need it.
setup_privilege() {
    case "$PKG_MGR" in
        brew) SUDO="" ;;
        *)
            if [[ $EUID -ne 0 ]]; then
                if command -v sudo >/dev/null 2>&1; then SUDO="sudo"
                else err "Root required and sudo missing."; exit 1; fi
            fi ;;
    esac
}

# Resolve a Debian package name to this manager's name (or "" to skip)
resolve_name() {
    local p="$1"
    case "$PKG_MGR" in
        brew) [[ -n "${MAP_BREW[$p]+x}" ]] && { printf '%s' "${MAP_BREW[$p]}"; return; } ;;
        dnf|rpm-ostree) [[ -n "${MAP_DNF[$p]+x}" ]] && { printf '%s' "${MAP_DNF[$p]}"; return; } ;;
    esac
    printf '%s' "$p"
}

# Install one package with this manager; returns 0 on success.
install_one() {
    local name="$1"
    if [[ "$PKG_MGR" == "brew" ]]; then
        brew install "$name" >/dev/null 2>&1 && return 0
        brew install --cask "$name" >/dev/null 2>&1 && return 0
        return 1
    fi
    # shellcheck disable=SC2086
    $SUDO $INSTALL_CMD "$name" >/dev/null 2>&1
}

# ----------------------------------------------------------------------------
# Native install (best-effort, per package)
# ----------------------------------------------------------------------------
native_update() {
    [[ "$UPDATE_CMD" == ":" ]] && return 0
    header "Refreshing package metadata ($PKG_MGR)"
    # shellcheck disable=SC2086
    if [[ "$PKG_MGR" == "brew" ]]; then $UPDATE_CMD || true
    else $SUDO $UPDATE_CMD || warn "metadata refresh returned non-zero; continuing."; fi
}

native_install_category() {
    local cat="$1" p resolved
    header "[$PKG_MGR] Category: $cat"
    for p in ${CATEGORIES[$cat]}; do
        resolved="$(resolve_name "$p")"
        if [[ -z "$resolved" ]]; then
            warn "no $PKG_MGR equivalent: $p (skipped)"; FAILED_PKGS+=("$p"); continue
        fi
        if install_one "$resolved"; then
            ok "installed: $p${resolved:+ ($resolved)}"; ((INSTALLED_COUNT++))
        else
            err "unavailable: $p"; FAILED_PKGS+=("$p")
        fi
    done
}

run_native() {
    detect_pkg_mgr
    if [[ -z "$PKG_MGR" ]]; then
        err "No supported package manager found (apt/dnf/rpm-ostree/pacman/zypper/brew)."
        err "On Bazzite/immutable systems, run with -d to use a ParrotOS distrobox."
        exit 1
    fi
    setup_privilege
    log "Package manager: ${C_BOLD}$PKG_MGR${C_RESET}"

    if [[ "$PKG_MGR" != "apt" ]]; then
        warn "This is a Debian/Parrot toolset. Many packages have no native"
        warn "$PKG_MGR equivalent and will be reported as unavailable."
        warn "For full coverage, re-run with: ${C_BOLD}./install.sh -d${C_RESET}"
    fi

    if [[ $ASSUME_YES -ne 1 ]]; then
        read -r -p "Proceed with native best-effort install? [y/N] " a
        [[ "$a" =~ ^[yY] ]] || { log "Aborted."; exit 0; }
    fi

    native_update
    for c in "${SELECTED[@]}"; do native_install_category "$c"; done
    print_summary "native ($PKG_MGR)"
}

# ----------------------------------------------------------------------------
# Container mode — ParrotOS distrobox (full coverage)
# ----------------------------------------------------------------------------
BOX_NAME="parrot-hax"
BOX_IMAGE="docker.io/parrotsec/security:latest"

run_container() {
    header "Container mode: ParrotOS distrobox"
    if ! command -v distrobox >/dev/null 2>&1; then
        err "distrobox not found."
        cat << EOF
Install it first (Bazzite ships it; otherwise):
  brew install distrobox        # or: your package manager
  # plus a backend: podman (preferred) or docker
Then re-run: ./install.sh -d
EOF
        exit 1
    fi
    if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        err "Need a container backend: install 'podman' (recommended) or 'docker'."
        exit 1
    fi

    # Build the flat package list for selected categories
    local pkgs=""
    for c in "${SELECTED[@]}"; do pkgs+=" ${CATEGORIES[$c]}"; done

    log "Container : $BOX_NAME"
    log "Image     : $BOX_IMAGE"
    log "Categories: ${SELECTED[*]}"
    if [[ $ASSUME_YES -ne 1 ]]; then
        read -r -p "Create the distrobox and install everything inside it? [y/N] " a
        [[ "$a" =~ ^[yY] ]] || { log "Aborted."; exit 0; }
    fi

    if ! distrobox list 2>/dev/null | grep -q "\b${BOX_NAME}\b"; then
        header "Creating distrobox '$BOX_NAME'"
        distrobox create --name "$BOX_NAME" --image "$BOX_IMAGE" --yes \
            || { err "Failed to create distrobox."; exit 1; }
    else
        log "Reusing existing distrobox '$BOX_NAME'."
    fi

    header "Updating apt inside the box"
    distrobox enter "$BOX_NAME" -- sudo apt-get update || warn "apt update non-zero; continuing."

    header "Installing tools inside the box (per-package fallback)"
    # Run the install loop inside the container so one bad pkg won't abort.
    distrobox enter "$BOX_NAME" -- bash -c '
        set -uo pipefail
        failed=()
        for p in '"$pkgs"'; do
            if sudo apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1; then
                echo "[+] installed: $p"
            else
                echo "[-] unavailable/failed: $p"; failed+=("$p")
            fi
        done
        echo
        if [ ${#failed[@]} -eq 0 ]; then
            echo "[+] All packages installed inside the container."
        else
            echo "[!] ${#failed[@]} package(s) failed inside the container:"
            printf "    %s\n" "${failed[@]}"
        fi
    '
    header "Done"
    ok "Tools are installed inside the '$BOX_NAME' distrobox."
    log "Enter it any time with:  ${C_BOLD}distrobox enter $BOX_NAME${C_RESET}"
    log "Exported GUI/CLI apps can be surfaced with 'distrobox-export' from inside."
}

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
print_summary() {
    header "Summary — $1"
    ok "Installed/processed OK: $INSTALLED_COUNT"
    if [[ ${#FAILED_PKGS[@]} -eq 0 ]]; then
        ok "No failures."
    else
        warn "${#FAILED_PKGS[@]} package(s) unavailable on this platform:"
        printf '    %s\n' "${FAILED_PKGS[@]}"
        echo
        warn "Most of these are Parrot/Debian-only. For full coverage run:"
        warn "  ${C_BOLD}./install.sh -d${C_RESET}   (ParrotOS distrobox)"
    fi
}

# ----------------------------------------------------------------------------
# Arg parsing + main
# ----------------------------------------------------------------------------
SELECTED=(); ASSUME_YES=0; MODE="native"
while getopts ":dc:lyh" opt; do
    case "$opt" in
        d) MODE="container" ;;
        c) IFS=',' read -r -a SELECTED <<< "$OPTARG" ;;
        l) for c in "${CATEGORY_ORDER[@]}"; do printf '%s\n' "$c"; done; exit 0 ;;
        y) ASSUME_YES=1 ;;
        h) usage; exit 0 ;;
        \?) err "Unknown option: -$OPTARG"; usage; exit 1 ;;
        :)  err "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done

[[ ${#SELECTED[@]} -eq 0 ]] && SELECTED=("${CATEGORY_ORDER[@]}")
for c in "${SELECTED[@]}"; do
    [[ -z "${CATEGORIES[$c]+x}" ]] && { err "Unknown category: $c (see -l)"; exit 1; }
done

log "ParrotOS 7 \"Echo\" tool installer — cross-platform"
if [[ "$MODE" == "container" ]]; then run_container; else run_native; fi
