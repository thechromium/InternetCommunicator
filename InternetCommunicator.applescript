property homeUrl : "https://google.com"
property searchEngine : "google"
property isPrivate : false
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
		set end of historyList to ((current date) as string) & " | " & targetUrl
	end if
	
	try
		if privateMode then
			do shell script "open -na 'Google Chrome' --args --incognito --app=" & quoted form of targetUrl
		else
			do shell script "open -na 'Google Chrome' --args --app=" & quoted form of targetUrl
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
	
	set promptText to "==========================================" & return & ¬
		"   INTERNET COMMUNICATOR 1.1  " & modeTag & return & ¬
		"==========================================" & return & ¬
		"1: Home   2: Google   3: YouTube   4: Wiki   5: GitHub" & return & ¬
		"Bookmarks: /add | /favs    Settings: /sethome | /engine" & return & ¬
		"Privacy: /private          History: /history | /clear" & return & ¬
		"Enter 1-5, a URL, search words, or /command:"
	
	try
		set userChoice to text returned of (display dialog promptText default answer "1" with title "Internet Communicator 1.1")
	on error
		exit repeat
	end try
	
	if userChoice is "" then exit repeat
	
	if userChoice is "/sethome" then
		set newHome to text returned of (display dialog "Enter new Homepage URL:" default answer homeUrl with title "Internet Communicator 1.1 - Homepage")
		if newHome is not "" then
			set homeUrl to my resolveAddress(newHome)
			display alert "Internet Communicator 1.1" message "Homepage updated to: " & homeUrl
		end if
		
	else if userChoice is "/engine" then
		set chosenEngine to choose from list {"google", "bing", "duckduckgo"} with prompt "Select default search engine:" default items {searchEngine} with title "Internet Communicator 1.1"
		if chosenEngine is not false then
			set searchEngine to item 1 of chosenEngine
			display alert "Internet Communicator 1.1" message "Search engine set to " & searchEngine
		end if
		
	else if userChoice is "/private" then
		set isPrivate to not isPrivate
		if isPrivate then
			display alert "Internet Communicator 1.1" message "Private / Incognito Mode is now ON."
		else
			display alert "Internet Communicator 1.1" message "Private / Incognito Mode is now OFF."
		end if
		
	else if userChoice is "/add" then
		set bName to text returned of (display dialog "Enter bookmark name:" default answer "" with title "Internet Communicator 1.1 - Add Bookmark")
		if bName is not "" then
			set bUrl to text returned of (display dialog "Enter URL for " & bName & ":" default answer "" with title "Internet Communicator 1.1 - Add Bookmark")
			if bUrl is not "" then
				set end of bookmarkNames to bName
				set end of bookmarkUrls to my resolveAddress(bUrl)
				display alert "Internet Communicator 1.1" message "Saved bookmark: " & bName
			end if
		end if
		
	else if userChoice is "/favs" then
		if (count of bookmarkNames) is 0 then
			display alert "Internet Communicator 1.1" message "No custom bookmarks saved yet! Type /add first."
		else
			set pickedFav to choose from list bookmarkNames with prompt "Choose a bookmark to open:" with title "Internet Communicator 1.1 - Bookmarks"
			if pickedFav is not false then
				set targetName to item 1 of pickedFav
				repeat with i from 1 to count of bookmarkNames
					if item i of bookmarkNames is targetName then
						my openWebWindow(item i of bookmarkUrls, isPrivate)
						exit repeat
					end if
				end repeat
			end if
		end if
		
	else if userChoice is "/history" then
		if (count of historyList) is 0 then
			display alert "Internet Communicator 1.1" message "No browsing history recorded yet!"
		else
			set AppleScript's text item delimiters to return
			set histOutput to historyList as string
			set AppleScript's text item delimiters to ""
			display dialog histOutput with title "Internet Communicator 1.1 - History" buttons {"OK"} default button "OK"
		end if
		
	else if userChoice is "/clear" then
		set historyList to {}
		display alert "Internet Communicator 1.1" message "Browsing history cleared!"
		
	else
		set resolvedUrl to my resolveAddress(userChoice)
		my openWebWindow(resolvedUrl, isPrivate)
	end if
end repeat
