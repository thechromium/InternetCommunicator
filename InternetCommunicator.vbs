Option Explicit

Dim shell, fso, baseDir, historyFile, bookmarkFile, configFile, notesFile, blockFile, deletedFlagFile, downloadsDir
Dim choice, isPrivate, searchEngine, lastUrl
Dim sdName(5), sdUrl(5)

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
configFile = baseDir & "\ic_config.txt"
notesFile = baseDir & "\ic_notes.txt"
blockFile = baseDir & "\ic_blocked.txt"
deletedFlagFile = baseDir & "\ic_history_deleted.flag"
downloadsDir = shell.ExpandEnvironmentStrings("%USERPROFILE%\Downloads")

isPrivate = False
searchEngine = "google"
lastUrl = ""
Randomize

sdName(1) = "Home"    : sdUrl(1) = "https://google.com"
sdName(2) = "Google"  : sdUrl(2) = "https://google.com"
sdName(3) = "YouTube" : sdUrl(3) = "https://youtube.com"
sdName(4) = "Wiki"    : sdUrl(4) = "https://wikipedia.org"
sdName(5) = "GitHub"  : sdUrl(5) = "https://github.com"

If fso.FileExists(configFile) Then
    Dim ts, ln, idx
    Set ts = fso.OpenTextFile(configFile, 1)
    Do While Not ts.AtEndOfStream
        ln = Trim(ts.ReadLine)
        If Left(ln, 7) = "ENGINE=" Then searchEngine = LCase(Mid(ln, 8))
        If Left(ln, 5) = "LAST=" Then lastUrl = Mid(ln, 6)
        For idx = 1 To 5
            If Left(ln, 4) = "SDN" & idx & "=" Then sdName(idx) = Mid(ln, 5)
            If Left(ln, 4) = "SDU" & idx & "=" Then sdUrl(idx) = Mid(ln, 5)
        Next
    Loop
    ts.Close
End If

Sub SaveConfig()
    Dim ts, idx
    Set ts = fso.OpenTextFile(configFile, 2, True)
    ts.WriteLine "ENGINE=" & searchEngine & vbCrLf & "LAST=" & lastUrl
    For idx = 1 To 5
        ts.WriteLine "SDN" & idx & "=" & sdName(idx) & vbCrLf & "SDU" & idx & "=" & sdUrl(idx)
    Next
    ts.Close
End Sub

Function AutoCorrectDomain(txt)
    Dim s : s = txt
    If InStr(s, " ") = 0 And InStr(s, ",") > 0 And InStr(s, ".") = 0 Then s = Replace(s, ",", ".")
    s = Replace(s, "gogle.com", "google.com", 1, -1, 1)
    s = Replace(s, "youtub.com", "youtube.com", 1, -1, 1)
    s = Replace(s, "githb.com", "github.com", 1, -1, 1)
    s = Replace(s, "wikipeida.org", "wikipedia.org", 1, -1, 1)
    AutoCorrectDomain = s
End Function

Function ResolveAddress(raw)
    Dim c : c = AutoCorrectDomain(Trim(raw))
    If c = "1" Or c = "2" Or c = "3" Or c = "4" Or c = "5" Then
        ResolveAddress = sdUrl(CInt(c))
    ElseIf LCase(Left(c, 7)) = "http://" Or LCase(Left(c, 8)) = "https://" Then
        ResolveAddress = c
    ElseIf InStr(c, ".") > 0 And InStr(c, " ") = 0 Then
        ResolveAddress = "https://" & c
    Else
        Dim q : q = Replace(c, " ", "+")
        If searchEngine = "bing" Then
            ResolveAddress = "https://bing.com" & q
        ElseIf searchEngine = "duckduckgo" Then
            ResolveAddress = "https://duckduckgo.com" & q
        Else
            ResolveAddress = "https://google.com/search?q=" & q
        End If
    End If
End Function

Function IsBlockedSite(url)
    IsBlockedSite = False
    If Not fso.FileExists(blockFile) Then Exit Function
    Dim bs, bln
    Set bs = fso.OpenTextFile(blockFile, 1)
    Do While Not bs.AtEndOfStream
        bln = LCase(Trim(bs.ReadLine))
        If bln <> "" And InStr(1, LCase(url), bln, 1) > 0 Then
            IsBlockedSite = True
            Exit Do
        End If
    Loop
    bs.Close
End Function

Function CountFileLines(filePath)
    CountFileLines = 0
    If Not fso.FileExists(filePath) Then Exit Function
    Dim fs, fl
    Set fs = fso.OpenTextFile(filePath, 1)
    Do While Not fs.AtEndOfStream
        fl = Trim(fs.ReadLine)
        If fl <> "" Then CountFileLines = CountFileLines + 1
    Loop
    fs.Close
End Function

Sub OpenWebWindow(url, priv)
    If IsBlockedSite(url) Then
        MsgBox "Blocked by Internet Communicator Focus Filter:" & vbCrLf & url & vbCrLf & vbCrLf & "(Edit ic_blocked.txt to manage blocked sites)", vbExclamation, "Focus Filter"
        Exit Sub
    End If

    Dim ts, flag, prof
    prof = baseDir & "\ic_profile"
    If priv Then flag = " --inprivate" Else flag = ""

    On Error Resume Next
    Err.Clear
    shell.Run "msedge.exe" & flag & " --user-data-dir=""" & prof & """ --app=""" & url & """ --start-maximized", 3, False
    If Err.Number <> 0 Then
        Err.Clear
        If priv Then flag = " --incognito" Else flag = ""
        shell.Run "chrome.exe" & flag & " --user-data-dir=""" & prof & """ --app=""" & url & """ --start-maximized", 3, False
    End If
    If Err.Number <> 0 Then
        Err.Clear
        shell.Run """" & url & """", 3, False
    End If
    On Error GoTo 0

    If Not priv Then
        lastUrl = url
        SaveConfig
        On Error Resume Next
        Set ts = fso.OpenTextFile(historyFile, 8, True)
        ts.WriteLine Now & "  |  " & url
        ts.Close
        On Error GoTo 0
    End If
End Sub

Function AskOrArg(cmdText, fullRaw, prefixLen, promptLabel, titleLabel)
    If cmdText = Left(LCase(fullRaw), prefixLen - 1) Then
        AskOrArg = Trim(InputBox(promptLabel, titleLabel))
    Else
        AskOrArg = Trim(Mid(fullRaw, prefixLen + 1))
    End If
End Function

Do
    Dim tag, rawCmd, cmd, qVal, sdBar, statsLine
    If isPrivate Then tag = "[INCOGNITO]" Else tag = "[" & UCase(searchEngine) & "]"
    sdBar = "1:" & sdName(1) & "  2:" & sdName(2) & "  3:" & sdName(3) & "  4:" & sdName(4) & "  5:" & sdName(5)
    statsLine = "Favs: " & CountFileLines(bookmarkFile) & " | Visits: " & CountFileLines(historyFile)

    choice = InputBox( _
        "Internet Communicator 1.3  " & tag & "  (" & statsLine & ")" & vbCrLf & _
        sdBar & vbCrLf & _
        "Enter URL, search, 1-5, or /help for commands:", _
        "Internet Communicator 1.3", "1")

    If choice = "" Then Exit Do
    rawCmd = Trim(choice)
    cmd = LCase(rawCmd)

    If cmd = "/help" Or cmd = "?" Then
        MsgBox "NAVIGATION & QUICK SITES" & vbCrLf & _
               "  1-5 | /tabs | /reopen | /paste | /twitter | /speedtest" & vbCrLf & vbCrLf & _
               "DIRECT SEARCHES" & vbCrLf & _
               "  /yt | /wiki | /gh | /reddit | /maps | /dict" & vbCrLf & _
               "  /amazon | /ebay | /translate | /weather | /newsweb" & vbCrLf & vbCrLf & _
               "BOOKMARKS, NOTES & HISTORY" & vbCrLf & _
               "  /add | /favs | /export | /note | /notes" & vbCrLf & _
               "  /history | /clear | /purge" & vbCrLf & vbCrLf & _
               "TOOLS & SETTINGS" & vbCrLf & _
               "  /sethome (customize Speed Dial 1-5) | /engine | /private" & vbCrLf & _
               "  /downloads | /calc | /notepad | /timer | /time | /dice | /coin" & vbCrLf & _
               "  /news | /about", _
               vbInformation, "Internet Communicator 1.3 - Help"

    ElseIf cmd = "/news" Then
        MsgBox "WHAT'S NEW IN 1.3" & vbCrLf & _
               "----------------------------------------" & vbCrLf & _
               "- Live Favs & Visits counter + Custom Speed Dial 1-5" & vbCrLf & _
               "- Smart domain typo auto-correct & Focus Site Blocker" & vbCrLf & _
               "- Full Profile Backup via /export" & vbCrLf & _
               "- /paste, /twitter, /gh, /reddit, /maps, /dict, /amazon, /ebay" & vbCrLf & _
               "- /translate, /weather, /newsweb, /speedtest, /note, /timer", vbInformation, "IC 1.3 Release Notes"

    ElseIf cmd = "/paste" Then
        Dim htmlObj, clipText
        Set htmlObj = CreateObject("htmlfile")
        clipText = Trim(htmlObj.ParentWindow.ClipboardData.GetData("text"))
        If clipText <> "" Then OpenWebWindow ResolveAddress(clipText), isPrivate Else MsgBox "Clipboard is empty!", vbExclamation, "IC 1.3"

    ElseIf cmd = "/twitter" Or cmd = "/x" Or Left(cmd, 9) = "/twitter " Or Left(cmd, 3) = "/x " Then
        Dim twQuery
        If cmd = "/twitter" Or cmd = "/x" Then
            OpenWebWindow "https://x.com", isPrivate
        ElseIf Left(cmd, 9) = "/twitter " Then
            twQuery = Trim(Mid(rawCmd, 10))
            OpenWebWindow "https://x.com" & Replace(twQuery, " ", "%20"), isPrivate
        Else
            twQuery = Trim(Mid(rawCmd, 4))
            OpenWebWindow "https://x.com" & Replace(twQuery, " ", "%20"), isPrivate
        End If

    ElseIf cmd = "/speedtest" Then
        OpenWebWindow "https://fast.com", isPrivate

    ElseIf cmd = "/sethome" Then
        Dim slotPick, newLabel, newUrl
        slotPick = Trim(InputBox("Which Speed Dial slot to edit? (1-5):", "Customize Speed Dial", "1"))
        If slotPick = "1" Or slotPick = "2" Or slotPick = "3" Or slotPick = "4" Or slotPick = "5" Then
            Dim sIdx : sIdx = CInt(slotPick)
            newLabel = Trim(InputBox("Button label for Slot #" & sIdx & ":", "Customize Speed Dial", sdName(sIdx)))
            If newLabel <> "" Then
                newUrl = Trim(InputBox("URL for " & newLabel & ":", "Customize Speed Dial", sdUrl(sIdx)))
                If newUrl <> "" Then
                    sdName(sIdx) = newLabel
                    sdUrl(sIdx) = ResolveAddress(newUrl)
                    SaveConfig
                    MsgBox "Speed Dial #" & sIdx & " updated to " & newLabel & "!", vbInformation, "IC 1.3"
                End If
            End If
        End If

    ElseIf cmd = "/engine" Then
        Dim eg : eg = LCase(Trim(InputBox("Search engine (google, bing, duckduckgo):", "Search Engine", searchEngine)))
        If eg = "google" Or eg = "bing" Or eg = "duckduckgo" Then searchEngine = eg : SaveConfig : MsgBox "Engine: " & UCase(eg), vbInformation, "IC 1.3"

    ElseIf cmd = "/private" Then
        isPrivate = Not isPrivate
        If isPrivate Then MsgBox "Incognito Mode: ON", vbInformation, "IC 1.3" Else MsgBox "Incognito Mode: OFF", vbInformation, "IC 1.3"

    ElseIf cmd = "/reopen" Then If lastUrl <> "" Then OpenWebWindow lastUrl, isPrivate Else MsgBox "No last site saved yet!", vbInformation, "IC 1.3"
ElseIf cmd = "/tabs" Or Left(cmd, 6) = "/tabs " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Enter URLs separated by commas:", "Open Multiple Tabs")
Dim item
For Each item In Split(qVal, ",")
If Trim(item) <> "" Then OpenWebWindow ResolveAddress(item), isPrivate : WScript.Sleep 300
Next
ElseIf cmd = "/yt" Or Left(cmd, 4) = "/yt " Then
qVal = AskOrArg(cmd, rawCmd, 4, "Search YouTube for:", "YouTube Search")
If qVal <> "" Then OpenWebWindow "youtube.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/wiki" Or Left(cmd, 6) = "/wiki " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Search Wikipedia for:", "Wikipedia Search")
If qVal <> "" Then OpenWebWindow "wikipedia.org" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/gh" Or Left(cmd, 4) = "/gh " Then
qVal = AskOrArg(cmd, rawCmd, 4, "Search GitHub for:", "GitHub Search")
If qVal <> "" Then OpenWebWindow "github.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/reddit" Or Left(cmd, 8) = "/reddit " Then
qVal = AskOrArg(cmd, rawCmd, 8, "Search Reddit for:", "Reddit Search")
If qVal <> "" Then OpenWebWindow "reddit.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/maps" Or Left(cmd, 6) = "/maps " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Search Google Maps for:", "Google Maps")
If qVal <> "" Then OpenWebWindow "google.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/dict" Or Left(cmd, 6) = "/dict " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Define word:", "Dictionary")
If qVal <> "" Then OpenWebWindow "dictionary.com" & Replace(qVal, " ", "-"), isPrivate
ElseIf cmd = "/amazon" Or Left(cmd, 8) = "/amazon " Then
qVal = AskOrArg(cmd, rawCmd, 8, "Search Amazon for:", "Amazon Search")
If qVal <> "" Then OpenWebWindow "amazon.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/ebay" Or Left(cmd, 6) = "/ebay " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Search eBay for:", "eBay Search")
If qVal <> "" Then OpenWebWindow "ebay.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/translate" Or Left(cmd, 11) = "/translate " Then
qVal = AskOrArg(cmd, rawCmd, 11, "Text to translate:", "Google Translate")
If qVal <> "" Then OpenWebWindow "google.com" & Replace(qVal, " ", "%20"), isPrivate
ElseIf cmd = "/weather" Or Left(cmd, 9) = "/weather " Then
qVal = AskOrArg(cmd, rawCmd, 9, "City or ZIP code for weather:", "Weather")
If qVal <> "" Then OpenWebWindow "google.com+" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/newsweb" Or Left(cmd, 9) = "/newsweb " Then
qVal = AskOrArg(cmd, rawCmd, 9, "Search news headlines for:", "Google News")
If qVal <> "" Then OpenWebWindow "google.com" & Replace(qVal, " ", "+"), isPrivate
ElseIf cmd = "/timer" Or Left(cmd, 7) = "/timer " Then
qVal = AskOrArg(cmd, rawCmd, 7, "Timer length in minutes:", "Countdown Timer")
If IsNumeric(qVal) Then
If CDbl(qVal) > 0 Then
MsgBox "Timer started for " & qVal & " minute(s)! Click OK to wait.", vbInformation, "IC 1.3 Timer"
WScript.Sleep CLng(CDbl(qVal) * 60000)
MsgBox "TIME'S UP! (" & qVal & " minute timer finished)", vbExclamation, "IC 1.3 Timer"
End If
End If
ElseIf cmd = "/time" Then
MsgBox "Current Date & Time:" & vbCrLf & WeekdayName(Weekday(Now)) & ", " & Now, vbInformation, "IC 1.3 Clock"
ElseIf cmd = "/dice" Then
MsgBox "You rolled a " & (Int(Rnd * 6) + 1) & "!", vbInformation, "IC 1.3 Dice"
ElseIf cmd = "/coin" Then
If Rnd < 0.5 Then MsgBox "HEADS!", vbInformation, "IC 1.3 Coin Flip" Else MsgBox "TAILS!", vbInformation, "IC 1.3 Coin Flip"
ElseIf cmd = "/note" Or Left(cmd, 6) = "/note " Then
qVal = AskOrArg(cmd, rawCmd, 6, "Write a quick note:", "Quick Note")
If qVal <> "" Then
Dim nts : Set nts = fso.OpenTextFile(notesFile, 8, True)
nts.WriteLine "[" & Now & "] " & qVal : nts.Close
MsgBox "Note saved!", vbInformation, "IC 1.3"
End If
ElseIf cmd = "/notes" Then
If Not fso.FileExists(notesFile) Then
MsgBox "No notes yet! Type /note to save one.", vbInformation, "Notes"
Else
Dim nread, ncontent, nact
Set nread = fso.OpenTextFile(notesFile, 1)
If Not nread.AtEndOfStream Then ncontent = nread.ReadAll Else ncontent = "(Empty)"
nread.Close
nact = Trim(InputBox(ncontent & vbCrLf & "Type /wipe to clear notes or click OK:", "Saved Notes", ""))
If LCase(nact) = "/wipe" Then fso.DeleteFile notesFile, True : MsgBox "Notes cleared!", vbInformation, "IC 1.3"
End If
ElseIf cmd = "/export" Then
Dim backupDir : backupDir = downloadsDir & "\InternetCommunicator_Backup"
If Not fso.FolderExists(backupDir) Then fso.CreateFolder backupDir
If fso.FileExists(bookmarkFile) Then fso.CopyFile bookmarkFile, backupDir & "\ic_bookmarks.txt", True
If fso.FileExists(configFile) Then fso.CopyFile configFile, backupDir & "\ic_config.txt", True
If fso.FileExists(notesFile) Then fso.CopyFile notesFile, backupDir & "\ic_notes.txt", True
If fso.FileExists(blockFile) Then fso.CopyFile blockFile, backupDir & "\ic_blocked.txt", True
MsgBox "Full profile backed up to:" & vbCrLf & backupDir, vbInformation, "IC 1.3 Backup"
ElseIf cmd = "/downloads" Then
shell.Run "explorer.exe """ & downloadsDir & """", 1, False
ElseIf cmd = "/calc" Then
shell.Run "calc.exe", 1, False
ElseIf cmd = "/notepad" Then
shell.Run "notepad.exe", 1, False
ElseIf cmd = "/about" Then
MsgBox "Internet Communicator 1.3" & vbCrLf & "Home: " & sdUrl(1) & vbCrLf & "Engine: " & UCase(searchEngine) & vbCrLf & "Last: " & lastUrl, vbInformation, "About IC 1.3"
ElseIf cmd = "/add" Then
Dim bn, bu, bts
bn = Trim(InputBox("Bookmark name:", "Add Bookmark"))
If bn <> "" Then
bu = Trim(InputBox("URL for " & bn & ":", "Add Bookmark"))
If bu <> "" Then
Set bts = fso.OpenTextFile(bookmarkFile, 8, True)
bts.WriteLine bn & " = " & ResolveAddress(bu) : bts.Close
MsgBox "Saved: " & bn, vbInformation, "IC 1.3"
End If
End If
ElseIf cmd = "/favs" Or cmd = "/bookmarks" Then
If Not fso.FileExists(bookmarkFile) Then
MsgBox "No bookmarks yet! Type /add first.", vbInformation, "Bookmarks"
Else
Dim fts, flist(), fc, fln, fmenu, fpick
Set fts = fso.OpenTextFile(bookmarkFile, 1)
fc = 0 : fmenu = ""
Do While Not fts.AtEndOfStream
fln = Trim(fts.ReadLine)
If InStr(fln, " = ") > 0 Then
fc = fc + 1 : ReDim Preserve flist(fc) : flist(fc) = fln
fmenu = fmenu & "[" & fc & "] " & fln & vbCrLf
End If
Loop
fts.Close
If fc = 0 Then
MsgBox "No bookmarks yet! Type /add first.", vbInformation, "Bookmarks"
Else
fpick = Trim(InputBox(fmenu & vbCrLf & "Enter number (1-" & fc & ") or /wipe:", "Bookmarks", "1"))
If LCase(fpick) = "/wipe" Then
fso.DeleteFile bookmarkFile, True : MsgBox "Bookmarks cleared!", vbInformation, "IC 1.3"
ElseIf IsNumeric(fpick) Then
If CInt(fpick) >= 1 And CInt(fpick) <= fc Then OpenWebWindow Split(flist(CInt(fpick)), " = ")(1), isPrivate
End If
End If
End If
ElseIf cmd = "/history" Then
Dim hBanner, hBody
hBanner = "" : hBody = ""
If fso.FileExists(deletedFlagFile) Then
hBanner = "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB" & vbCrLf & vbCrLf
End If
If fso.FileExists(historyFile) Then
Dim hs, hLines, startIdx, i
Set hs = fso.OpenTextFile(historyFile, 1)
If Not hs.AtEndOfStream Then
hLines = Split(hs.ReadAll, vbCrLf)
startIdx = UBound(hLines) - 15
If startIdx < 0 Then startIdx = 0
For i = startIdx To UBound(hLines)
If Trim(hLines(i)) <> "" Then hBody = hBody & hLines(i) & vbCrLf
Next
End If
hs.Close
End If
If hBanner = "" And hBody = "" Then MsgBox "No history yet!", vbInformation, "History" Else MsgBox hBanner & hBody, vbInformation, "History"
ElseIf cmd = "/clear" Then
If fso.FileExists(historyFile) Then
fso.CopyFile historyFile, downloadsDir & "\InternetCommunicator_History_Backup.txt", True
fso.DeleteFile historyFile, True
End If
Dim df : Set df = fso.OpenTextFile(deletedFlagFile, 2, True)
df.WriteLine Now : df.Close
MsgBox "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB", vbInformation, "History Cleared"
ElseIf cmd = "/purge" Then
If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
If fso.FileExists(downloadsDir & "\InternetCommunicator_History_Backup.txt") Then fso.DeleteFile downloadsDir & "\InternetCommunicator_History_Backup.txt", True
If fso.FileExists(deletedFlagFile) Then fso.DeleteFile deletedFlagFile, True
lastUrl = "" : SaveConfig
MsgBox "All history and backup files have been permanently erased!", vbInformation, "IC 1.3"
ElseIf Left(cmd, 1) = "/" Then
MsgBox "Unknown command: " & rawCmd & vbCrLf & "Type /help to see all valid commands.", vbExclamation, "IC 1.3"
Else
OpenWebWindow ResolveAddress(rawCmd), isPrivate
End If
Loop
