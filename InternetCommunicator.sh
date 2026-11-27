#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_FILE="$BASE_DIR/ic_history.txt"
BOOKMARK_FILE="$BASE_DIR/ic_bookmarks.txt"
CONFIG_FILE="$BASE_DIR/ic_config.txt"
DELETED_FLAG="$BASE_DIR/ic_history_deleted.flag"
DOWNLOADS_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"

IS_PRIVATE=false
HOME_URL="https://google.com"
SEARCH_ENGINE="google"
LAST_URL=""

if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key val; do
        [ "$key" = "HOME" ] && HOME_URL="$val"
        [ "$key" = "ENGINE" ] && SEARCH_ENGINE="$val"
        [ "$key" = "LAST" ] && LAST_URL="$val"
    done < "$CONFIG_FILE"
fi

save_config() {
    printf "HOME=%s\nENGINE=%s\nLAST=%s\n" "$HOME_URL" "$SEARCH_ENGINE" "$LAST_URL" > "$CONFIG_FILE"
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
        zenity --info --title="$1" --text="$2" --width=420 2>/dev/null
    else
        echo -e "\n=== $1 ===\n$2\n"
    fi
}

resolve_address() {
    local raw="$1"
    case "$raw" in
        1) echo "$HOME_URL" ;;
        2) echo "https://google.com" ;;
        3) echo "https://youtube.com" ;;
        4) echo "https://wikipedia.org" ;;
        5) echo "https://github.com" ;;
        http://*|https://*) echo "$raw" ;;
        *.*) [[ "$raw" != *" "* ]] && echo "https://$raw" || build_search "$raw" ;;
        *) build_search "$raw" ;;
    esac
}

build_search() {
    local q="${1// /+}"
    case "$SEARCH_ENGINE" in
        bing) echo "https://bing.com" ;;
        duckduckgo) echo "https://duckduckgo.com" ;;
        *) echo "https://google.com/search?q=$q" ;;
    esac
}

open_web_window() {
    local url="$1"
    local priv="$2"
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

while true; do
    [ "$IS_PRIVATE" = true ] && TAG="[INCOGNITO]" || TAG="[${SEARCH_ENGINE^^}]"

    CHOICE=$(prompt_box "Internet Communicator 1.2" \
        "Internet Communicator 1.2  $TAG\n1:Home  2:Google  3:YouTube  4:Wiki  5:GitHub\nEnter URL, search, 1-5, or /help for commands:" "1")

    [ -z "$CHOICE" ] && break
    CMD="${CHOICE,,}"

    case "$CMD" in
        "/help"|"?")
            info_box "Internet Communicator 1.2 - Help" \
                "NAVIGATION\n  1-5, /tabs, /reopen, /yt, /wiki\n\nBOOKMARKS & HISTORY\n  /add, /favs, /history, /clear, /purge\n\nSETTINGS & TOOLS\n  /sethome, /engine, /private, /downloads, /about"
            ;;
        "/sethome")
            NH=$(prompt_box "Set Homepage" "New Homepage URL:" "$HOME_URL")
            [ -n "$NH" ] && HOME_URL=$(resolve_address "$NH") && save_config && info_box "IC 1.2" "Homepage saved!"
            ;;
        "/engine")
            EG=$(prompt_box "Search Engine" "Search engine (google, bing, duckduckgo):" "$SEARCH_ENGINE")
            EG="${EG,,}"
            [[ "$EG" == "google" || "$EG" == "bing" || "$EG" == "duckduckgo" ]] && SEARCH_ENGINE="$EG" && save_config && info_box "IC 1.2" "Engine: ${EG^^}"
            ;;
        "/private")
            [ "$IS_PRIVATE" = true ] && IS_PRIVATE=false || IS_PRIVATE=true
            info_box "IC 1.2" "Incognito Mode: $([ "$IS_PRIVATE" = true ] && echo ON || echo OFF)"
            ;;
        "/reopen")
            [ -n "$LAST_URL" ] && open_web_window "$LAST_URL" "$IS_PRIVATE" || info_box "IC 1.2" "No last site saved yet!"
            ;;
        "/tabs"*)
            TAB_STR="${CHOICE:5}"
            [ -z "${TAB_STR// /}" ] && TAB_STR=$(prompt_box "Open Multiple Tabs" "Enter URLs separated by commas:" "")
            IFS=',' read -ra ITEMS <<< "$TAB_STR"
            for item in "${ITEMS[@]}"; do
                clean=$(echo "$item" | xargs)
                [ -n "$clean" ] && open_web_window "$(resolve_address "$clean")" "$IS_PRIVATE" && sleep 0.3
            done
            ;;
        "/yt"*)
            Q="${CHOICE:3}"
            [ -z "${Q// /}" ] && Q=$(prompt_box "YouTube Search" "Search YouTube for:" "")
            [ -n "$Q" ] && open_web_window "https://youtube.com/results?search_query=${Q// /+}" "$IS_PRIVATE"
            ;;
        "/wiki"*)
            Q="${CHOICE:5}"
            [ -z "${Q// /}" ] && Q=$(prompt_box "Wikipedia Search" "Search Wikipedia for:" "")
            [ -n "$Q" ] && open_web_window "https://wikipedia.org/wiki/Special:Search?search=${Q// /+}" "$IS_PRIVATE"
            ;;
        "/downloads")
            xdg-open "$DOWNLOADS_DIR" >/dev/null 2>&1 &
            ;;
        "/about")
            info_box "About IC 1.2" "Internet Communicator 1.2\nHome: $HOME_URL\nEngine: ${SEARCH_ENGINE^^}\nLast: $LAST_URL"
            ;;
        "/add")
            BN=$(prompt_box "Add Bookmark" "Bookmark name:" "")
            if [ -n "$BN" ]; then
                BU=$(prompt_box "Add Bookmark" "URL for $BN:" "")
                [ -n "$BU" ] && echo "$BN = $(resolve_address "$BU")" >> "$BOOKMARK_FILE" && info_box "IC 1.2" "Saved: $BN"
            fi
            ;;
        "/favs"|"/bookmarks")
            if [ ! -f "$BOOKMARK_FILE" ]; then
                info_box "Bookmarks" "No bookmarks yet! Type /add first."
            else
                LIST=$(nl -w1 -s'. ' "$BOOKMARK_FILE")
                PICK=$(prompt_box "Bookmarks" "$LIST\n\nEnter number or /wipe:" "1")
                if [ "${PICK,,}" = "/wipe" ]; then
                    rm -f "$BOOKMARK_FILE" && info_box "IC 1.2" "Bookmarks cleared!"
                elif [[ "$PICK" =~ ^[0-9]+$ ]]; then
                    LINE=$(sed -n "${PICK}p" "$BOOKMARK_FILE")
                    URL="${LINE#* = }"
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
            info_box "IC 1.2" "All history and backup files permanently erased!"
            ;;
        /*)
            info_box "IC 1.2" "Unknown command: $CHOICE\nType /help to see all valid commands."
            ;;
        *)
            open_web_window "$(resolve_address "$CHOICE")" "$IS_PRIVATE"
            ;;
    esac
done
