property sdNames : {"Home", "Google", "YouTube", "Wiki", "GitHub"}
property sdUrls : {"https://www.google.com", "https://www.google.com", "https://www.youtube.com", "https://en.wikipedia.org", "https://github.com"}
property searchEngine : "google"
property isPrivate : false
property lastUrl : ""
property historyList : {}
property bookmarkNames : {}
property bookmarkUrls : {}
property noteList : {}
property blockedDomains : {}

on urlEncode(str)
	return do shell script "python3 -c \"import urllib.parse, sys; print(urllib.parse.quote(sys.argv))\" " & quoted form of str
end urlEncode

on autoCorrectDomain(txt)
	if txt does not contain " " and txt contains "," and txt does not contain "." then
		set AppleScript's text item delimiters to ","
		set parts to text items of txt
		set AppleScript's text item delimiters to "."
		set txt to parts as string
		set AppleScript's text item delimiters to ""
	end if
	return txt
end autoCorrectDomain

on resolveAddress(rawInput)
	set c to my autoCorrectDomain(rawInput)
	if c is "1" or c is "2" or c is "3" or c is "4" or c is "5" then
		return item (c as integer) of sdUrls
	else if c starts with "http://" or c starts with "https://" then
		return c
	else if c contains "." and c does not contain " " then
		return "https://" & c
	else
		set q to my urlEncode(c)
		if searchEngine is "bing" then
			return "https://www.bing.com/search?q=" & q
		else if searchEngine is "duckduckgo" then
			return "https://duckduckgo.com/?q=" & q
		else
			return "https://www.google.com/search?q=" & q
		end if
	end if
end resolveAddress

on openWebWindow(targetUrl, privateMode)
	repeat with b in blockedDomains
		if (b as string) is not "" and targetUrl contains (b as string) then
			display alert "Focus Filter" message "Blocked by Internet Communicator Focus Filter:" & return & targetUrl
			return
		end if
	end repeat
	
	if not privateMode then
		set lastUrl to targetUrl
		set end of historyList to ((current date) as string) & " | " & targetUrl
	end if
	try
		if privateMode then
			do shell script "open -na 'Google Chrome' --args --incognito --start-maximized --app=" & quoted form of targetUrl
		else
			do shell script "open -na 'Google Chrome' --args --start-maximized --app=" & quoted form of targetUrl
		end if
	on error
		do shell script "open " & quoted form of targetUrl
	end try
end openWebWindow

on askOrArg(fullStr, prefixLen, promptMsg)
	if (length of fullStr) < prefixLen then
		return text returned of (display dialog promptMsg default answer "")
	else
		return text prefixLen thru -1 of fullStr
	end if
end askOrArg

repeat
	if isPrivate then set modeTag to "[INCOGNITO]" else set modeTag to "[" & searchEngine & "]"
	set sdBar to "1:" & item 1 of sdNames & "  2:" & item 2 of sdNames & "  3:" & item 3 of sdNames & "  4:" & item 4 of sdNames & "  5:" & item 5 of sdNames
	set statsLine to "Favs: " & (count of bookmarkNames) & " | Visits: " & (count of historyList)
	
	try
		set userChoice to text returned of (display dialog "Internet Communicator 1.3  " & modeTag & "  (" & statsLine & ")" & return & ¬
			sdBar & return & ¬
			"Enter URL, search, 1-5, or /help for commands:" default answer "1" with title "Internet Communicator 1.3")
	on error
		exit repeat
	end try
	
	if userChoice is "" then exit repeat
	
	if userChoice is "/help" or userChoice is "?" then
		display alert "Internet Communicator 1.3 - Help" message ¬
			"NAVIGATION: 1-5, /tabs, /reopen, /paste, /twitter, /speedtest" & return & ¬
			"SEARCH: /yt, /wiki, /gh, /reddit, /maps, /dict, /amazon, /ebay, /translate, /weather, /newsweb" & return & ¬
			"DATA: /add, /favs, /export, /note, /notes, /history, /clear, /purge" & return & ¬
			"TOOLS: /sethome, /engine, /private, /block, /downloads, /calc, /notepad, /timer, /time, /dice, /coin, /news, /about"
	else if userChoice is "/news" then
		display alert "What's New in 1.3" message "Live stats, customizable Speed Dial 1-5, Focus Filter (/block), /paste, /twitter, /gh, /reddit, /maps, /dict, /amazon, /ebay, /translate, /weather, /newsweb, /speedtest, /note, /timer, /export."
	else if userChoice is "/paste" then
		set clipTxt to the clipboard as string
		if clipTxt is not "" then my openWebWindow(my resolveAddress(clipTxt), isPrivate)
	else if userChoice is "/twitter" or userChoice is "/x" then
		my openWebWindow("https://x.com", isPrivate)
	else if userChoice starts with "/twitter " then
		my openWebWindow("https://x.com/search?q=" & my urlEncode(text 10 thru -1 of userChoice), isPrivate)
	else if userChoice starts with "/x " then
		my openWebWindow("https://x.com/search?q=" & my urlEncode(text 4 thru -1 of userChoice), isPrivate)
	else if userChoice is "/speedtest" then
		my openWebWindow("https://fast.com", isPrivate)
	else if userChoice is "/sethome" then
		set slotStr to text returned of (display dialog "Which Speed Dial slot to edit? (1-5):" default answer "1")
		if slotStr is "1" or slotStr is "2" or slotStr is "3" or slotStr is "4" or slotStr is "5" then
			set idx to slotStr as integer
			set newLbl to text returned of (display dialog "Button label for Slot #" & idx & ":" default answer (item idx of sdNames))
			if newLbl is not "" then
				set newU to text returned of (display dialog "URL for " & newLbl & ":" default answer (item idx of sdUrls))
				if newU is not "" then
					set item idx of sdNames to newLbl
					set item idx of sdUrls to my resolveAddress(newU)
				end if
			end if
		end if
	else if userChoice is "/block" then
		set dom to text returned of (display dialog "Enter domain to block (e.g. tiktok.com) or /wipe:" default answer "")
		if dom is "/wipe" then
			set blockedDomains to {}
		else if dom is not "" then
			set end of blockedDomains to dom
		end if
	else if userChoice is "/engine" then
		set pickedEng to choose from list {"google", "bing", "duckduckgo"} with prompt "Select search engine:" default items {searchEngine}
		if pickedEng is not false then set searchEngine to item 1 of pickedEng
	else if userChoice is "/private" then
		set isPrivate to not isPrivate
		display alert "IC 1.3" message "Incognito Mode toggled."
	else if userChoice is "/reopen" then
		if lastUrl is not "" then my openWebWindow(lastUrl, isPrivate)
	else if userChoice is "/tabs" or userChoice starts with "/tabs " then
		set tabStr to my askOrArg(userChoice, 7, "Enter URLs separated by commas:")
		set AppleScript's text item delimiters to ","
		set urlItems to text items of tabStr
		set AppleScript's text item delimiters to ""
		repeat with u in urlItems
			set cleanU to do shell script "echo " & quoted form of (u as string) & " | xargs"
			if cleanU is not "" then my openWebWindow(my resolveAddress(cleanU), isPrivate)
		end repeat
	else if userChoice is "/yt" or userChoice starts with "/yt " then
		set q to my askOrArg(userChoice, 5, "Search YouTube for:")
		if q is not "" then my openWebWindow("https://www.youtube.com/results?search_query=" & my urlEncode(q), isPrivate)
	else if userChoice is "/wiki" or userChoice starts with "/wiki " then
		set q to my askOrArg(userChoice, 7, "Search Wikipedia for:")
		if q is not "" then my openWebWindow("https://en.wikipedia.org/wiki/Special:Search?search=" & my urlEncode(q), isPrivate)
	else if userChoice is "/gh" or userChoice starts with "/gh " then
		set q to my askOrArg(userChoice, 5, "Search GitHub for:")
		if q is not "" then my openWebWindow("https://github.com/search?q=" & my urlEncode(q), isPrivate)
	else if userChoice is "/reddit" or userChoice starts with "/reddit " then
		set q to my askOrArg(userChoice, 9, "Search Reddit for:")
		if q is not "" then my openWebWindow("https://www.reddit.com/search/?q=" & my urlEncode(q), isPrivate)
	else if userChoice is "/maps" or userChoice starts with "/maps " then
		set q to my askOrArg(userChoice, 7, "Search Google Maps for:")
		if q is not "" then my openWebWindow("https://www.google.com/maps/search/" & my urlEncode(q), isPrivate)
	else if userChoice is "/dict" or userChoice starts with "/dict " then
		set q to my askOrArg(userChoice, 7, "Define word:")
		if q is not "" then my openWebWindow("https://www.dictionary.com/browse/" & my urlEncode(q), isPrivate)
	else if userChoice is "/amazon" or userChoice starts with "/amazon " then
		set q to my askOrArg(userChoice, 9, "Search Amazon for:")
		if q is not "" then my openWebWindow("https://www.amazon.com/s?k=" & my urlEncode(q), isPrivate)
	else if userChoice is "/ebay" or userChoice starts with "/ebay " then
		set q to my askOrArg(userChoice, 7, "Search eBay for:")
		if q is not "" then my openWebWindow("https://www.ebay.com/sch/i.html?_nkw=" & my urlEncode(q), isPrivate)
	else if userChoice is "/translate" or userChoice starts with "/translate " then
		set q to my askOrArg(userChoice, 12, "Text to translate:")
		if q is not "" then my openWebWindow("https://translate.google.com/?sl=auto&tl=en&text=" & my urlEncode(q), isPrivate)
	else if userChoice is "/weather" or userChoice starts with "/weather " then
		set q to my askOrArg(userChoice, 10, "City or ZIP code:")
		if q is not "" then my openWebWindow("https://www.google.com/search?q=weather+" & my urlEncode(q), isPrivate)
	else if userChoice is "/newsweb" or userChoice starts with "/newsweb " then
		set q to my askOrArg(userChoice, 10, "Search news headlines:")
		if q is not "" then my openWebWindow("https://news.google.com/search?q=" & my urlEncode(q), isPrivate)
	else if userChoice is "/timer" or userChoice starts with "/timer " then
		set mins to my askOrArg(userChoice, 8, "Timer length in minutes:")
		if mins is not "" then
			delay ((mins as number) * 60)
			display alert "Time's Up!" message mins & " minute timer finished!"
		end if
	else if userChoice is "/time" then
		display alert "Current Date & Time" message ((current date) as string)
	else if userChoice is "/dice" then
display alert "Dice Roll" message "You rolled a " & (random number from 1 to 6) & "!"
else if userChoice is "/coin" then
if (random number from 0 to 1) is 0 then display alert "Coin Flip" message "HEADS!" else display alert "Coin Flip" message "TAILS!"
else if userChoice is "/note" or userChoice starts with "/note " then
set nTxt to my askOrArg(userChoice, 7, "Write a quick note:")
if nTxt is not "" then set end of noteList to ((current date) as string) & ": " & nTxt
else if userChoice is "/notes" then
set AppleScript's text item delimiters to return
set nOut to noteList as string
set AppleScript's text item delimiters to ""
display alert "Saved Notes" message nOut
else if userChoice is "/export" then
set AppleScript's text item delimiters to return
set bOut to bookmarkUrls as string
set AppleScript's text item delimiters to ""
do shell script "mkdir -p ~/Downloads/InternetCommunicator_Backup && printf %s " & quoted form of bOut & " > ~/Downloads/InternetCommunicator_Backup/ic_bookmarks.txt"
display alert "IC 1.3" message "Profile backed up to ~/Downloads/InternetCommunicator_Backup!"
else if userChoice is "/downloads" then
do shell script "open ~/Downloads"
else if userChoice is "/calc" then
do shell script "open -a Calculator"
else if userChoice is "/notepad" then
do shell script "open -a TextEdit"
else if userChoice is "/about" then
display alert "Internet Communicator 1.3" message "Home: " & item 1 of sdUrls & return & "Engine: " & searchEngine & return & "Last: " & lastUrl
else if userChoice is "/add" then
set bName to text returned of (display dialog "Bookmark name:" default answer "")
if bName is not "" then
set bUrl to text returned of (display dialog "URL for " & bName & ":" default answer "")
if bUrl is not "" then
set end of bookmarkNames to bName
set end of bookmarkUrls to my resolveAddress(bUrl)
end if
end if
else if userChoice is "/favs" then
if (count of bookmarkNames) > 0 then
set pickedFav to choose from list bookmarkNames with prompt "Open bookmark:"
if pickedFav is not false then
repeat with i from 1 to count of bookmarkNames
if item i of bookmarkNames is (item 1 of pickedFav) then
my openWebWindow(item i of bookmarkUrls, isPrivate)
exit repeat
end if
end repeat
end if
end if
else if userChoice is "/history" then
set AppleScript's text item delimiters to return
set hOut to historyList as string
set AppleScript's text item delimiters to ""
display alert "History" message hOut
else if userChoice is "/clear" then
set AppleScript's text item delimiters to return
set hOut to historyList as string
set AppleScript's text item delimiters to ""
do shell script "printf %s " & quoted form of hOut & " > ~/Downloads/InternetCommunicator_History_Backup.txt"
set historyList to {}
display alert "History Cleared" message "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB"
else if userChoice is "/purge" then
set historyList to {}
set lastUrl to ""
do shell script "rm -f ~/Downloads/InternetCommunicator_History_Backup.txt"
display alert "IC 1.3" message "All history and backup files permanently erased!"
else
my openWebWindow(my resolveAddress(userChoice), isPrivate)
end if
end repeat
