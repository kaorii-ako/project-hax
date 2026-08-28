#!/usr/bin/env bash
#
# install.sh — ParrotOS 7 "Echo" tool installer
# Source: ParrotSec/parrot-tools (official metapackage definitions)
# Repo:   https://github.com/kaorii-ako/project-hax
#
# Installs the full ParrotOS "Echo" toolset, grouped by category.
# Packages are installed per-category; if a package is unavailable in the
# configured repositories the script logs it and keeps going instead of
# aborting the whole run.
#
# Usage:
#   sudo ./install.sh                 # install everything
#   sudo ./install.sh -c Development  # install only listed categories
#   ./install.sh -l                   # list categories and exit
#   ./install.sh -h                   # help
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
# Package definitions (category -> space-separated package list)
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

# Ordered list of categories (associative arrays are unordered)
CATEGORY_ORDER=(AI Development Crypto Privacy InformationGathering VulnerabilityAnalysis \
    WebApplicationAnalysis ExploitationTools MaintainingAccess PostExploitation \
    PasswordAttacks WirelessAttacks SniffingSpoofing Forensics Automotive \
    ReverseEngineering Reporting Cloud)

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
SUDO=""
FAILED_PKGS=()
INSTALLED_COUNT=0

usage() {
    cat << EOF
${C_BOLD}install.sh${C_RESET} — ParrotOS 7 "Echo" tool installer

Usage:
  sudo ./install.sh [options]

Options:
  -c CAT[,CAT...]   Install only the given categories (comma-separated)
  -l                List categories and exit
  -y                Assume yes; do not prompt before installing
  -h                Show this help and exit

Categories:
$(for c in "${CATEGORY_ORDER[@]}"; do printf '  - %s\n' "$c"; done)
EOF
}

need_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
            log "Not running as root; using sudo for privileged commands."
        else
            err "This script needs root privileges and sudo is not available."
            err "Re-run as root: su -c './install.sh'"
            exit 1
        fi
    fi
}

check_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        err "apt-get not found. This script targets ParrotOS / Debian-based systems."
        exit 1
    fi
}

apt_update() {
    header "Updating package lists"
    $SUDO apt-get update || warn "apt-get update returned a non-zero status; continuing."
}

# Install a single category. Tries the whole list first; on failure falls back
# to installing packages one at a time so one bad package doesn't block the rest.
install_category() {
    local name="$1"
    local pkgs="${CATEGORIES[$name]}"
    header "Installing category: $name"

    # shellcheck disable=SC2086
    if $SUDO apt-get install -y --no-install-recommends $pkgs; then
        ok "Category '$name' installed."
        return
    fi

    warn "Batch install for '$name' failed; retrying package by package."
    local p
    for p in $pkgs; do
        if $SUDO apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1; then
            ok "installed: $p"
            ((INSTALLED_COUNT++))
        else
            err "unavailable/failed: $p"
            FAILED_PKGS+=("$p")
        fi
    done
}

# ----------------------------------------------------------------------------
# Arg parsing
# ----------------------------------------------------------------------------
SELECTED=()
ASSUME_YES=0

while getopts ":c:lyh" opt; do
    case "$opt" in
        c) IFS=',' read -r -a SELECTED <<< "$OPTARG" ;;
        l) for c in "${CATEGORY_ORDER[@]}"; do printf '%s\n' "$c"; done; exit 0 ;;
        y) ASSUME_YES=1 ;;
        h) usage; exit 0 ;;
        \?) err "Unknown option: -$OPTARG"; usage; exit 1 ;;
        :)  err "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done

# Default to all categories
if [[ ${#SELECTED[@]} -eq 0 ]]; then
    SELECTED=("${CATEGORY_ORDER[@]}")
fi

# Validate selected categories
for c in "${SELECTED[@]}"; do
    if [[ -z "${CATEGORIES[$c]+x}" ]]; then
        err "Unknown category: $c"
        err "Run './install.sh -l' to see valid categories."
        exit 1
    fi
done

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
check_apt
need_root

log "ParrotOS 7 \"Echo\" tool installer"
log "Categories to install: ${SELECTED[*]}"

if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "Proceed with installation? [y/N] " ans
    case "$ans" in
        [yY]|[yY][eE][sS]) ;;
        *) log "Aborted by user."; exit 0 ;;
    esac
fi

apt_update

for c in "${SELECTED[@]}"; do
    install_category "$c"
done

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
header "Summary"
if [[ ${#FAILED_PKGS[@]} -eq 0 ]]; then
    ok "All requested packages processed successfully."
else
    warn "The following ${#FAILED_PKGS[@]} package(s) were unavailable or failed to install:"
    printf '    %s\n' "${FAILED_PKGS[@]}"
    echo
    warn "These are often provided by the Parrot repositories. Ensure Parrot's"
    warn "apt sources are configured, then re-run for the affected categories."
fi

ok "Done."
