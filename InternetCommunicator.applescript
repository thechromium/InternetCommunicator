property homeUrl : "https://google.com"
property searchEngine : "google"
property isPrivate : false
property lastUrl : ""
property historyList : {}
property bookmarkNames : {}
property bookmarkUrls : {}

on resolveAddress(rawInput)
	if rawInput is "1" then
		return homeUrl
	else if rawInput is "2" then
		return "https://google.com"
	else if rawInput is "3" then
		return "https://youtube.com"
	else if rawInput is "4" then
		return "https://wikipedia.org"
	else if rawInput is "5" then
		return "https://github.com"
	else if rawInput starts with "http://" or rawInput starts with "https://" then
		return rawInput
	else if rawInput contains "." and rawInput does not contain " " then
		return "https://" & rawInput
	else
		set encodedQuery to do shell script "python3 -c \"import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))\" " & quoted form of rawInput
		if searchEngine is "bing" then
			return "https://bing.com" & encodedQuery
		else if searchEngine is "duckduckgo" then
			return "https://duckduckgo.com" & encodedQuery
		else
			return "https://google.com/search?q=" & encodedQuery
		end if
	end if
end resolveAddress

on openWebWindow(targetUrl, privateMode)
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

repeat
	if isPrivate then
		set modeTag to "[INCOGNITO]"
	else
		set modeTag to "[" & searchEngine & "]"
	end if
	
	try
		set userChoice to text returned of (display dialog "Internet Communicator 1.2  " & modeTag & return & ¬
			"1:Home  2:Google  3:YouTube  4:Wiki  5:GitHub" & return & ¬
			"Enter URL, search, 1-5, or /help for commands:" default answer "1" with title "Internet Communicator 1.2")
	on error
		exit repeat
	end try
	
	if userChoice is "" then exit repeat
	
	if userChoice is "/help" or userChoice is "?" then
		display alert "Internet Communicator 1.2 Commands" message ¬
			"NAVIGATION" & return & ¬
			"1-5, /tabs, /reopen, /yt, /wiki" & return & return & ¬
			"BOOKMARKS & HISTORY" & return & ¬
			"/add, /favs, /history, /clear, /purge" & return & return & ¬
			"SETTINGS & TOOLS" & return & ¬
			"/sethome, /engine, /private, /downloads, /about"
	else if userChoice is "/sethome" then
		set newHome to text returned of (display dialog "Enter new Homepage URL:" default answer homeUrl with title "Set Homepage")
		if newHome is not "" then set homeUrl to my resolveAddress(newHome)
	else if userChoice is "/engine" then
		set pickedEng to choose from list {"google", "bing", "duckduckgo"} with prompt "Select search engine:" default items {searchEngine}
		if pickedEng is not false then set searchEngine to item 1 of pickedEng
	else if userChoice is "/private" then
		set isPrivate to not isPrivate
		display alert "IC 1.2" message "Incognito Mode toggled."
	else if userChoice is "/reopen" then
		if lastUrl is not "" then my openWebWindow(lastUrl, isPrivate)
	else if userChoice starts with "/tabs " then
		set AppleScript's text item delimiters to ","
		set urlItems to text items of (text 7 thru -1 of userChoice)
		set AppleScript's text item delimiters to ""
		repeat with u in urlItems
			set cleanU to do shell script "echo " & quoted form of (u as string) & " | xargs"
			if cleanU is not "" then my openWebWindow(my resolveAddress(cleanU), isPrivate)
		end repeat
	else if userChoice starts with "/yt " then
		set q to do shell script "python3 -c \"import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))\" " & quoted form of (text 5 thru -1 of userChoice)
		my openWebWindow("https://youtube.com/results?search_query=" & q, isPrivate)
	else if userChoice starts with "/wiki " then
		set q to do shell script "python3 -c \"import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))\" " & quoted form of (text 7 thru -1 of userChoice)
		my openWebWindow("https://wikipedia.org/wiki/Special:Search?search=" & q, isPrivate)
	else if userChoice is "/downloads" then
		do shell script "open ~/Downloads"
	else if userChoice is "/about" then
		display alert "Internet Communicator 1.2" message "Home: " & homeUrl & return & "Engine: " & searchEngine & return & "Last: " & lastUrl
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
		display alert "IC 1.2" message "All history and backup files permanently erased!"
	else
		my openWebWindow(my resolveAddress(userChoice), isPrivate)
	end if
end repeat

