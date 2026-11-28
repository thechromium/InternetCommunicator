#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
HISTORY_FILE="$BASE_DIR/ic_history.txt"
BOOKMARK_FILE="$BASE_DIR/ic_bookmarks.txt"
CONFIG_FILE="$BASE_DIR/ic_config.txt"
NOTES_FILE="$BASE_DIR/ic_notes.txt"
BLOCK_FILE="$BASE_DIR/ic_blocked.txt"
DELETED_FLAG="$BASE_DIR/ic_history_deleted.flag"
DOWNLOADS_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"

IS_PRIVATE=false
SEARCH_ENGINE="google"
LAST_URL=""

SD_NAME=("" "Home" "Google" "YouTube" "Wiki" "GitHub")
SD_URL=("" "https://www.google.com" "https://www.google.com" "https://www.youtube.com" "https://en.wikipedia.org" "https://github.com")

if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key val; do
        [ "$key" = "ENGINE" ] && SEARCH_ENGINE="$val"
        [ "$key" = "LAST" ] && LAST_URL="$val"
        for i in 1 2 3 4 5; do
            [ "$key" = "SDN$i" ] && SD_NAME[$i]="$val"
            [ "$key" = "SDU$i" ] && SD_URL[$i]="$val"
        done
    done < "$CONFIG_FILE"
fi

save_config() {
    {
        echo "ENGINE=$SEARCH_ENGINE"
        echo "LAST=$LAST_URL"
        for i in 1 2 3 4 5; do
            echo "SDN$i=${SD_NAME[$i]}"
            echo "SDU$i=${SD_URL[$i]}"
        done
    } > "$CONFIG_FILE"
}

prompt_box() {
    if command -v zenity >/dev/null 2>&1; then
        zenity --entry --title="$1" --text="$2" --entry-text="$3" 2>/dev/null
    else
        read -rp "$2 [$3]: " ans
        echo "${ans:-$3}"
    fi
}

info_box() {
    if command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$1" --text="$2" --width=450 2>/dev/null
    else
        echo -e "\n=== $1 ===\n$2\n"
    fi
}

autocorrect_domain() {
    local s="$1"
    if [[ "$s" != *" "* && "$s" == *","* && "$s" != *"."* ]]; then
        s="${s//,/.}"
    fi
    s="${s//gogle.com/google.com}"
    s="${s//youtub.com/youtube.com}"
    s="${s//githb.com/github.com}"
    s="${s//wikipeida.org/wikipedia.org}"
    echo "$s"
}

resolve_address() {
    local raw
    raw=$(autocorrect_domain "$1")
    case "$raw" in
        1|2|3|4|5) echo "${SD_URL[$raw]}" ;;
        http://*|https://*) echo "$raw" ;;
        *.*) [[ "$raw" != *" "* ]] && echo "https://$raw" || build_search "$raw" ;;
        *) build_search "$raw" ;;
    esac
}

build_search() {
    local q="${1// /+}"
    case "$SEARCH_ENGINE" in
        bing) echo "https://www.bing.com/search?q=$q" ;;
        duckduckgo) echo "https://duckduckgo.com/?q=$q" ;;
        *) echo "https://www.google.com/search?q=$q" ;;
    esac
}

is_blocked_site() {
    local url="${1,,}"
    [ ! -f "$BLOCK_FILE" ] && return 1
    while IFS= read -r dom; do
        dom="${dom,,}"
        dom=$(echo "$dom" | xargs)
        if [ -n "$dom" ] && [[ "$url" == *"$dom"* ]]; then
            return 0
        fi
    done < "$BLOCK_FILE"
    return 1
}

open_web_window() {
    local url="$1"
    local priv="$2"
    if is_blocked_site "$url"; then
        info_box "Focus Filter" "Blocked by Internet Communicator Focus Filter:\n$url\n\n(Edit ic_blocked.txt to manage blocked sites)"
        return
    fi

    local flag=""
    [ "$priv" = true ] && flag="--incognito"

    if [ "$priv" = false ]; then
        LAST_URL="$url"
        save_config
        echo "$(date '+%Y-%m-%d %H:%M:%S')  |  $url" >> "$HISTORY_FILE"
    fi

    for browser in google-chrome chromium chromium-browser brave-browser microsoft-edge; do
        if command -v "$browser" >/dev/null 2>&1; then
            "$browser" $flag --user-data-dir="$BASE_DIR/ic_profile" --app="$url" --start-maximized >/dev/null 2>&1 &
            return
        fi
    done
    xdg-open "$url" >/dev/null 2>&1 &
}

ask_or_arg() {
    local raw="$1"
    local prefix_len="$2"
    local prompt_lbl="$3"
    local arg="${raw:$prefix_len}"
    arg=$(echo "$arg" | xargs)
    if [ -z "$arg" ]; then
        prompt_box "Internet Communicator 1.3" "$prompt_lbl" ""
    else
        echo "$arg"
    fi
}

while true; do
    [ "$IS_PRIVATE" = true ] && TAG="[INCOGNITO]" || TAG="[${SEARCH_ENGINE^^}]"
    FAV_COUNT=0; [ -f "$BOOKMARK_FILE" ] && FAV_COUNT=$(grep -c '[^[:space:]]' "$BOOKMARK_FILE")
    VIS_COUNT=0; [ -f "$HISTORY_FILE" ] && VIS_COUNT=$(grep -c '[^[:space:]]' "$HISTORY_FILE")
    SD_BAR="1:${SD_NAME[1]}  2:${SD_NAME[2]}  3:${SD_NAME[3]}  4:${SD_NAME[4]}  5:${SD_NAME[5]}"

    CHOICE=$(prompt_box "Internet Communicator 1.3" \
        "Internet Communicator 1.3  $TAG  (Favs: $FAV_COUNT | Visits: $VIS_COUNT)\n$SD_BAR\nEnter URL, search, 1-5, or /help for commands:" "1")

    [ -z "$CHOICE" ] && break
    CMD="${CHOICE,,}"

    case "$CMD" in
        "/help"|"?")
            info_box "Internet Communicator 1.3 - Help" \
                "NAVIGATION: 1-5, /tabs, /reopen, /paste, /twitter, /speedtest\n\nSEARCH: /yt, /wiki, /gh, /reddit, /maps, /dict, /amazon, /ebay, /translate, /weather, /newsweb\n\nDATA: /add, /favs, /export, /note, /notes, /history, /clear, /purge\n\nTOOLS: /sethome, /engine, /private, /downloads, /calc, /notepad, /timer, /time, /dice, /coin, /news, /about"
            ;;
        "/news")
            info_box "IC 1.3 Release Notes" \
                "- Live Favs & Visits counter + Custom Speed Dial 1-5\n- Smart domain typo auto-correct & Focus Site Blocker\n- Full Profile Backup via /export\n- /paste, /twitter, /gh, /reddit, /maps, /dict, /amazon, /ebay, /translate, /weather, /newsweb, /speedtest, /note, /timer"
            ;;
        "/paste")
            CLIP=""
            command -v xclip >/dev/null 2>&1 && CLIP=$(xclip -o -selection clipboard 2>/dev/null)
            [ -z "$CLIP" ] && command -v wl-paste >/dev/null 2>&1 && CLIP=$(wl-paste 2>/dev/null)
            [ -n "$CLIP" ] && open_web_window "$(resolve_address "$CLIP")" "$IS_PRIVATE" || info_box "IC 1.3" "Clipboard is empty or xclip/wl-paste not installed."
            ;;
        "/twitter"|"/x") open_web_window "https://x.com" "$IS_PRIVATE" ;;
        "/twitter "*) Q="${CHOICE:9}"; open_web_window "https://x.com/search?q=${Q// /%20}" "$IS_PRIVATE" ;;
        "/x "*) Q="${CHOICE:3}"; open_web_window "https://x.com/search?q=${Q// /%20}" "$IS_PRIVATE" ;;
        "/speedtest") open_web_window "https://fast.com" "$IS_PRIVATE" ;;
        "/sethome")
            SLOT=$(prompt_box "Customize Speed Dial" "Which Speed Dial slot to edit? (1-5):" "1")
            if [[ "$SLOT" =~ ^[1-5]$ ]]; then
                NL=$(prompt_box "Customize Speed Dial" "Button label for Slot #$SLOT:" "${SD_NAME[$SLOT]}")
                if [ -n "$NL" ]; then
                    NU=$(prompt_box "Customize Speed Dial" "URL for $NL:" "${SD_URL[$SLOT]}")
                    [ -n "$NU" ] && SD_NAME[$SLOT]="$NL" && SD_URL[$SLOT]=$(resolve_address "$NU") && save_config && info_box "IC 1.3" "Speed Dial #$SLOT updated!"
                fi
            fi
            ;;
        "/engine")
            EG=$(prompt_box "Search Engine" "Search engine (google, bing, duckduckgo):" "$SEARCH_ENGINE")
            EG="${EG,,}"
            [[ "$EG" == "google" || "$EG" == "bing" || "$EG" == "duckduckgo" ]] && SEARCH_ENGINE="$EG" && save_config && info_box "IC 1.3" "Engine: ${EG^^}"
            ;;
        "/private")
            [ "$IS_PRIVATE" = true ] && IS_PRIVATE=false || IS_PRIVATE=true
            info_box "IC 1.3" "Incognito Mode: $([ "$IS_PRIVATE" = true ] && echo ON || echo OFF)"
            ;;
        "/reopen") [ -n "$LAST_URL" ] && open_web_window "$LAST_URL" "$IS_PRIVATE" || info_box "IC 1.3" "No last site saved yet!" ;;
        "/tabs"*)
            TAB_STR=$(ask_or_arg "$CHOICE" 5 "Enter URLs separated by commas:")
            IFS=',' read -ra ITEMS <<< "$TAB_STR"
            for item in "${ITEMS[@]}"; do
                clean=$(echo "$item" | xargs)
                [ -n "$clean" ] && open_web_window "$(resolve_address "$clean")" "$IS_PRIVATE" && sleep 0.3
            done
            ;;
        "/yt"*) Q=$(ask_or_arg "$CHOICE" 3 "Search YouTube for:"); [ -n "$Q" ] && open_web_window "https://www.youtube.com/results?search_query=${Q// /+}" "$IS_PRIVATE" ;;
        "/wiki"*) Q=$(ask_or_arg "$CHOICE" 5 "Search Wikipedia for:"); [ -n "$Q" ] && open_web_window "https://en.wikipedia.org/wiki/Special:Search?search=${Q// /+}" "$IS_PRIVATE" ;;
        "/gh"*) Q=$(ask_or_arg "$CHOICE" 3 "Search GitHub for:"); [ -n "$Q" ] && open_web_window "https://github.com/search?q=${Q// /+}" "$IS_PRIVATE" ;;
        "/reddit"*) Q=$(ask_or_arg "$CHOICE" 7 "Search Reddit for:"); [ -n "$Q" ] && open_web_window "https://www.reddit.com/search/?q=${Q// /+}" "$IS_PRIVATE" ;;
        "/maps"*) Q=$(ask_or_arg "$CHOICE" 5 "Search Google Maps for:"); [ -n "$Q" ] && open_web_window "https://www.google.com/maps/search/${Q// /+}" "$IS_PRIVATE" ;;
        "/dict"*) Q=$(ask_or_arg "$CHOICE" 5 "Define word:"); [ -n "$Q" ] && open_web_window "https://www.dictionary.com/browse/${Q// /-}" "$IS_PRIVATE" ;;
        "/amazon"*) Q=$(ask_or_arg "$CHOICE" 7 "Search Amazon for:"); [ -n "$Q" ] && open_web_window "https://www.amazon.com/s?k=${Q// /+}" "$IS_PRIVATE" ;;
        "/ebay"*) Q=$(ask_or_arg "$CHOICE" 5 "Search eBay for:"); [ -n "$Q" ] && open_web_window "https://www.ebay.com/sch/i.html?_nkw=${Q// /+}" "$IS_PRIVATE" ;;
        "/translate"*) Q=$(ask_or_arg "$CHOICE" 10 "Text to translate:"); [ -n "$Q" ] && open_web_window "https://translate.google.com/?sl=auto&tl=en&text=${Q// /%20}" "$IS_PRIVATE" ;;
        "/weather"*) Q=$(ask_or_arg "$CHOICE" 8 "City or ZIP code:"); [ -n "$Q" ] && open_web_window "https://www.google.com/search?q=weather+${Q// /+}" "$IS_PRIVATE" ;;
        "/newsweb"*) Q=$(ask_or_arg "$CHOICE" 8 "Search news headlines:"); [ -n "$Q" ] && open_web_window "https://news.google.com/search?q=${Q// /+}" "$IS_PRIVATE" ;;
        "/timer"*)
            MINS=$(ask_or_arg "$CHOICE" 6 "Timer length in minutes:")
            if [[ "$MINS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
(sleep "$(awk "BEGIN {print $MINS * 60}")" && info_box "IC 1.3 Timer" "TIME'S UP! ($MINS minute timer finished)") &
info_box "IC 1.3 Timer" "Timer started for $MINS minute(s)!"
fi
;;
"/time") info_box "IC 1.3 Clock" "Current Date & Time:\n$(date)" ;;
"/dice") info_box "IC 1.3 Dice" "You rolled a $((RANDOM % 6 + 1))!" ;;
"/coin") [ $((RANDOM % 2)) -eq 0 ] && info_box "IC 1.3 Coin Flip" "HEADS!" || info_box "IC 1.3 Coin Flip" "TAILS!" ;;
"/note")
Q=$(ask_or_arg "$CHOICE" 5 "Write a quick note:")
[ -n "$Q" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $Q" >> "$NOTES_FILE" && info_box "IC 1.3" "Note saved!"
;;
"/notes")
if [ ! -f "$NOTES_FILE" ]; then
info_box "Notes" "No notes yet! Type /note to save one."
else
ACT=$(prompt_box "Saved Notes" "$(cat "$NOTES_FILE")\n\nType /wipe to clear notes or click OK:" "")
[ "${ACT,,}" = "/wipe" ] && rm -f "$NOTES_FILE" && info_box "IC 1.3" "Notes cleared!"
fi
;;
"/export")
BDIR="$DOWNLOADS_DIR/InternetCommunicator_Backup"
mkdir -p "$BDIR"
for f in "$BOOKMARK_FILE" "$CONFIG_FILE" "$NOTES_FILE" "$BLOCK_FILE"; do
[ -f "$f" ] && cp "$f" "$BDIR/"
done
info_box "IC 1.3 Backup" "Full profile backed up to:\n$BDIR"
;;
"/downloads") xdg-open "$DOWNLOADS_DIR" >/dev/null 2>&1 & ;;
"/calc") (command -v gnome-calculator >/dev/null 2>&1 && gnome-calculator || xcalc) >/dev/null 2>&1 & ;;
"/notepad") (command -v gedit >/dev/null 2>&1 && gedit || mousepad || kate || xed) >/dev/null 2>&1 & ;;
"/about") info_box "About IC 1.3" "Internet Communicator 1.3\nHome: ${SD_URL[1]}\nEngine: ${SEARCH_ENGINE^^}\nLast: $LAST_URL" ;;
"/add")
BN=$(prompt_box "Add Bookmark" "Bookmark name:" "")
if [ -n "$BN" ]; then
BU=$(prompt_box "Add Bookmark" "URL for $BN:" "")
[ -n "$BU" ] && echo "$BN = $(resolve_address "$BU")" >> "$BOOKMARK_FILE" && info_box "IC 1.3" "Saved: $BN"
fi
;;
"/favs"|"/bookmarks")
if [ ! -f "$BOOKMARK_FILE" ]; then
info_box "Bookmarks" "No bookmarks yet! Type /add first."
else
LIST=$(nl -w1 -s'. ' "$BOOKMARK_FILE")
PICK=$(prompt_box "Bookmarks" "$LIST\n\nEnter number or /wipe:" "1")
if [ "${PICK,,}" = "/wipe" ]; then
rm -f "$BOOKMARK_FILE" && info_box "IC 1.3" "Bookmarks cleared!"
elif [[ "$PICK" =~ ^[0-9]+$ ]]; then
LINE=$(sed -n "${PICK}p" "$BOOKMARK_FILE")
URL="${LINE# = }"
[ -n "$URL" ] && open_web_window "$URL" "$IS_PRIVATE"
fi
fi
;;
"/history")
BANNER=""
BODY=""
[ -f "$DELETED_FLAG" ] && BANNER="HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB\n\n"
[ -f "$HISTORY_FILE" ] && BODY=$(tail -n 15 "$HISTORY_FILE")
[ -z "$BANNER$BODY" ] && info_box "History" "No history yet!" || info_box "History" "$BANNER$BODY"
;;
"/clear")
mkdir -p "$DOWNLOADS_DIR"
[ -f "$HISTORY_FILE" ] && cp "$HISTORY_FILE" "$DOWNLOADS_DIR/InternetCommunicator_History_Backup.txt" && rm -f "$HISTORY_FILE"
date > "$DELETED_FLAG"
info_box "History Cleared" "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB"
;;
"/purge")
rm -f "$HISTORY_FILE" "$DOWNLOADS_DIR/InternetCommunicator_History_Backup.txt" "$DELETED_FLAG"
LAST_URL=""
save_config
info_box "IC 1.3" "All history and backup files permanently erased!"
;;
/*)
info_box "IC 1.3" "Unknown command: $CHOICE\nType /help to see all valid commands."
;;
*)
open_web_window "$(resolve_address "$CHOICE")" "$IS_PRIVATE"
;;
esac
done
