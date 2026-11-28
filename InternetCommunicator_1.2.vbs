Option Explicit

Dim shell, fso, baseDir, historyFile, bookmarkFile, configFile, deletedFlagFile, downloadsDir
Dim choice, isPrivate, homeUrl, searchEngine, lastUrl

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
configFile = baseDir & "\ic_config.txt"
deletedFlagFile = baseDir & "\ic_history_deleted.flag"
downloadsDir = shell.ExpandEnvironmentStrings("%USERPROFILE%\Downloads")

isPrivate = False : homeUrl = "https://google.com" : searchEngine = "google" : lastUrl = ""

If fso.FileExists(configFile) Then
    Dim ts, ln : Set ts = fso.OpenTextFile(configFile, 1)
    Do While Not ts.AtEndOfStream
        ln = Trim(ts.ReadLine)
        If Left(ln, 5) = "HOME=" Then homeUrl = Mid(ln, 6)
        If Left(ln, 7) = "ENGINE=" Then searchEngine = LCase(Mid(ln, 8))
        If Left(ln, 5) = "LAST=" Then lastUrl = Mid(ln, 6)
    Loop
    ts.Close
End If

Sub SaveConfig()
    Dim ts : Set ts = fso.OpenTextFile(configFile, 2, True)
    ts.WriteLine "HOME=" & homeUrl & vbCrLf & "ENGINE=" & searchEngine & vbCrLf & "LAST=" & lastUrl
    ts.Close
End Sub

Function ResolveAddress(raw)
    Dim c : c = Trim(raw)
    Select Case c
        Case "1": ResolveAddress = homeUrl
        Case "2": ResolveAddress = "https://google.com"
        Case "3": ResolveAddress = "https://youtube.com"
        Case "4": ResolveAddress = "https://wikipedia.org"
        Case "5": ResolveAddress = "https://github.com"
        Case Else
            If LCase(Left(c, 7)) = "http://" Or LCase(Left(c, 8)) = "https://" Then
                ResolveAddress = c
            ElseIf InStr(c, ".") > 0 And InStr(c, " ") = 0 Then
                ResolveAddress = "https://" & c
            Else
                Dim q : q = Replace(c, " ", "+")
                If searchEngine = "bing" Then ResolveAddress = "https://bing.com" & q Else If searchEngine = "duckduckgo" Then ResolveAddress = "https://duckduckgo.com" & q Else ResolveAddress = "https://google.com/search?q=" & q
            End If
    End Select
End Function

Sub OpenWebWindow(url, priv)
    Dim ts, flag, prof : prof = baseDir & "\ic_profile"
    If priv Then flag = " --inprivate" Else flag = ""
    On Error Resume Next
    Err.Clear
    shell.Run "msedge.exe" & flag & " --user-data-dir=""" & prof & """ --app=""" & url & """ --start-maximized", 3, False
    If Err.Number <> 0 Then Err.Clear : If priv Then flag = " --incognito" Else flag = "" : shell.Run "chrome.exe" & flag & " --user-data-dir=""" & prof & """ --app=""" & url & """ --start-maximized", 3, False
    If Err.Number <> 0 Then Err.Clear : shell.Run """" & url & """", 3, False
    On Error GoTo 0
    If Not priv Then lastUrl = url : SaveConfig : Set ts = fso.OpenTextFile(historyFile, 8, True) : ts.WriteLine Now & "  |  " & url : ts.Close
End Sub

Do
    Dim tag, rawCmd, cmd
    If isPrivate Then tag = "[INCOGNITO]" Else tag = "[" & UCase(searchEngine) & "]"
    choice = InputBox("Internet Communicator 1.2  " & tag & vbCrLf & "1:Home  2:Google  3:YouTube  4:Wiki  5:GitHub" & vbCrLf & "Enter URL, search, 1-5, or /help for commands:", "Internet Communicator 1.2", "1")
    If choice = "" Then Exit Do
    rawCmd = Trim(choice) : cmd = LCase(rawCmd)
    If cmd = "/help" Or cmd = "?" Then
        MsgBox "1-5, /tabs, /reopen, /yt, /wiki, /add, /favs, /history, /clear, /purge, /sethome, /engine, /private, /downloads, /about", vbInformation, "IC 1.2 Help"
    ElseIf cmd = "/sethome" Then
        Dim nh : nh = Trim(InputBox("New Homepage URL:", "Set Homepage", homeUrl)) : If nh <> "" Then homeUrl = ResolveAddress(nh) : SaveConfig
    ElseIf cmd = "/engine" Then
        Dim eg : eg = LCase(Trim(InputBox("google, bing, duckduckgo:", "Engine", searchEngine))) : If eg = "google" Or eg = "bing" Or eg = "duckduckgo" Then searchEngine = eg : SaveConfig
    ElseIf cmd = "/private" Then
        isPrivate = Not isPrivate : MsgBox "Incognito: " & isPrivate, vbInformation, "IC 1.2"
    ElseIf cmd = "/reopen" Then
        If lastUrl <> "" Then OpenWebWindow lastUrl, isPrivate
    ElseIf cmd = "/tabs" Or Left(cmd, 6) = "/tabs " Then
        Dim tabStr, item : If cmd = "/tabs" Then tabStr = InputBox("Comma-separated URLs:") Else tabStr = Mid(rawCmd, 7)
        For Each item In Split(tabStr, ",") : If Trim(item) <> "" Then OpenWebWindow ResolveAddress(item), isPrivate : WScript.Sleep 300 : Next
    ElseIf cmd = "/yt" Or Left(cmd, 4) = "/yt " Then
        Dim yq : If cmd = "/yt" Then yq = InputBox("YouTube search:") Else yq = Mid(rawCmd, 5) : If yq <> "" Then OpenWebWindow "https://youtube.com/results?search_query=" & Replace(yq, " ", "+"), isPrivate
    ElseIf cmd = "/wiki" Or Left(cmd, 6) = "/wiki " Then
        Dim wq : If cmd = "/wiki" Then wq = InputBox("Wiki search:") Else wq = Mid(rawCmd, 7) : If wq <> "" Then OpenWebWindow "https://wikipedia.org/wiki/Special:Search?search=" & Replace(wq, " ", "+"), isPrivate
    ElseIf cmd = "/downloads" Then
        shell.Run "explorer.exe """ & downloadsDir & """", 1, False
    ElseIf cmd = "/about" Then
        MsgBox "Internet Communicator 1.2" & vbCrLf & "Home: " & homeUrl & vbCrLf & "Engine: " & UCase(searchEngine), vbInformation, "About IC 1.2"
    ElseIf cmd = "/add" Then
        Dim bn, bu, bts : bn = InputBox("Bookmark name:") : If bn <> "" Then bu = InputBox("URL:") : If bu <> "" Then Set bts = fso.OpenTextFile(bookmarkFile, 8, True) : bts.WriteLine bn & " = " & ResolveAddress(bu) : bts.Close
    ElseIf cmd = "/favs" Then
        If fso.FileExists(bookmarkFile) Then Dim fts : Set fts = fso.OpenTextFile(bookmarkFile, 1) : MsgBox fts.ReadAll, vbInformation, "Bookmarks" : fts.Close
    ElseIf cmd = "/history" Then
        If fso.FileExists(historyFile) Then Dim hs : Set hs = fso.OpenTextFile(historyFile, 1) : MsgBox hs.ReadAll, vbInformation, "History" : hs.Close
    ElseIf cmd = "/clear" Then
        If fso.FileExists(historyFile) Then fso.CopyFile historyFile, downloadsDir & "\InternetCommunicator_History_Backup.txt", True : fso.DeleteFile historyFile, True
        MsgBox "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB", vbInformation, "History Cleared"
    ElseIf cmd = "/purge" Then
        If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
        If fso.FileExists(downloadsDir & "\InternetCommunicator_History_Backup.txt") Then fso.DeleteFile downloadsDir & "\InternetCommunicator_History_Backup.txt", True
        MsgBox "All history permanently erased!", vbInformation, "IC 1.2"
    Else
        OpenWebWindow ResolveAddress(rawCmd), isPrivate
    End If
Loop
