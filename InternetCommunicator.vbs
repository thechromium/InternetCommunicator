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

isPrivate = False
homeUrl = "https://google.com"
searchEngine = "google"
lastUrl = ""

If fso.FileExists(configFile) Then
    Dim ts, ln
    Set ts = fso.OpenTextFile(configFile, 1)
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
                If searchEngine = "bing" Then
                    ResolveAddress = "https://bing.com" & q
                ElseIf searchEngine = "duckduckgo" Then
                    ResolveAddress = "https://duckduckgo.com" & q
                Else
                    ResolveAddress = "https://google.com/search?q=" & q
                End If
            End If
    End Select
End Function

Sub OpenWebWindow(url, priv)
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

Do
    Dim tag, rawCmd, cmd
    If isPrivate Then tag = "[INCOGNITO]" Else tag = "[" & UCase(searchEngine) & "]"

    choice = InputBox( _
        "Internet Communicator 1.2  " & tag & vbCrLf & _
        "1:Home  2:Google  3:YouTube  4:Wiki  5:GitHub" & vbCrLf & _
        "Enter URL, search, 1-5, or /help for commands:", _
        "Internet Communicator 1.2", "1")

    If choice = "" Then Exit Do
    rawCmd = Trim(choice)
    cmd = LCase(rawCmd)

    If cmd = "/help" Or cmd = "?" Then
        MsgBox "NAVIGATION" & vbCrLf & _
               "  1-5 - Speed Dial sites" & vbCrLf & _
               "  /tabs - Open multiple sites" & vbCrLf & _
               "  /reopen - Reopen last site" & vbCrLf & _
               "  /yt - Search YouTube" & vbCrLf & _
               "  /wiki - Search Wikipedia" & vbCrLf & vbCrLf & _
               "BOOKMARKS & HISTORY" & vbCrLf & _
               "  /add - Save a bookmark" & vbCrLf & _
               "  /favs - Open bookmarks" & vbCrLf & _
               "  /history - View history" & vbCrLf & _
               "  /clear - Wipe & backup history" & vbCrLf & _
               "  /purge - Permanently erase history" & vbCrLf & vbCrLf & _
               "SETTINGS & TOOLS" & vbCrLf & _
               "  /sethome - Set Speed Dial #1" & vbCrLf & _
               "  /engine - Switch search engine" & vbCrLf & _
               "  /private - Toggle Incognito" & vbCrLf & _
               "  /downloads - Open Downloads" & vbCrLf & _
               "  /about - App & settings info", _
               vbInformation, "Internet Communicator 1.2 - Help"

    ElseIf cmd = "/sethome" Then
        Dim nh : nh = Trim(InputBox("New Homepage URL:", "Set Homepage", homeUrl))
        If nh <> "" Then homeUrl = ResolveAddress(nh) : SaveConfig : MsgBox "Homepage saved!", vbInformation, "IC 1.2"

    ElseIf cmd = "/engine" Then
        Dim eg : eg = LCase(Trim(InputBox("Search engine (google, bing, duckduckgo):", "Search Engine", searchEngine)))
        If eg = "google" Or eg = "bing" Or eg = "duckduckgo" Then searchEngine = eg : SaveConfig : MsgBox "Engine: " & UCase(eg), vbInformation, "IC 1.2"

    ElseIf cmd = "/private" Then
        isPrivate = Not isPrivate
        If isPrivate Then
            MsgBox "Incognito Mode: ON", vbInformation, "IC 1.2"
        Else
            MsgBox "Incognito Mode: OFF", vbInformation, "IC 1.2"
        End If

    ElseIf cmd = "/reopen" Then
        If lastUrl <> "" Then OpenWebWindow lastUrl, isPrivate Else MsgBox "No last site saved yet!", vbInformation, "IC 1.2"

    ElseIf cmd = "/tabs" Or Left(cmd, 6) = "/tabs " Then
        Dim tabStr, item
        If cmd = "/tabs" Then
            tabStr = Trim(InputBox("Enter URLs or searches separated by commas:", "Open Multiple Tabs"))
        Else
            tabStr = Trim(Mid(rawCmd, 7))
        End If
        For Each item In Split(tabStr, ",")
            If Trim(item) <> "" Then OpenWebWindow ResolveAddress(item), isPrivate : WScript.Sleep 300
        Next

    ElseIf cmd = "/yt" Or Left(cmd, 4) = "/yt " Then
        Dim ytQuery
        If cmd = "/yt" Then ytQuery = Trim(InputBox("Search YouTube for:", "YouTube Search")) Else ytQuery = Trim(Mid(rawCmd, 5))
        If ytQuery <> "" Then OpenWebWindow "https://youtube.com/results?search_query=" & Replace(ytQuery, " ", "+"), isPrivate

    ElseIf cmd = "/wiki" Or Left(cmd, 6) = "/wiki " Then
        Dim wikiQuery
        If cmd = "/wiki" Then wikiQuery = Trim(InputBox("Search Wikipedia for:", "Wikipedia Search")) Else wikiQuery = Trim(Mid(rawCmd, 7))
        If wikiQuery <> "" Then OpenWebWindow "https://wikipedia.org/wiki/Special:Search?search=" & Replace(wikiQuery, " ", "+"), isPrivate

    ElseIf cmd = "/downloads" Then
        shell.Run "explorer.exe """ & downloadsDir & """", 1, False

    ElseIf cmd = "/about" Then
        MsgBox "Internet Communicator 1.2" & vbCrLf & "Home: " & homeUrl & vbCrLf & "Engine: " & UCase(searchEngine) & vbCrLf & "Last: " & lastUrl, vbInformation, "About IC 1.2"

    ElseIf cmd = "/add" Then
        Dim bn, bu, bts
        bn = Trim(InputBox("Bookmark name:", "Add Bookmark"))
        If bn <> "" Then
            bu = Trim(InputBox("URL for " & bn & ":", "Add Bookmark"))
            If bu <> "" Then
                Set bts = fso.OpenTextFile(bookmarkFile, 8, True)
                bts.WriteLine bn & " = " & ResolveAddress(bu)
                bts.Close
                MsgBox "Saved: " & bn, vbInformation, "IC 1.2"
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
                    fso.DeleteFile bookmarkFile, True : MsgBox "Bookmarks cleared!", vbInformation, "IC 1.2"
                ElseIf IsNumeric(fpick) Then
                    If CInt(fpick) >= 1 And CInt(fpick) <= fc Then OpenWebWindow Split(flist(CInt(fpick)), " = ")(1), isPrivate
                End If
            End If
        End If

    ElseIf cmd = "/history" Then
        Dim hBanner, hBody
        hBanner = ""
        hBody = ""
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
        If hBanner = "" And hBody = "" Then
MsgBox "No history yet!", vbInformation, "History"
Else
MsgBox hBanner & hBody, vbInformation, "History"
End If
ElseIf cmd = "/clear" Then
Dim backupPath, df
backupPath = downloadsDir & "\InternetCommunicator_History_Backup.txt"
If fso.FileExists(historyFile) Then
fso.CopyFile historyFile, backupPath, True
fso.DeleteFile historyFile, True
End If
Set df = fso.OpenTextFile(deletedFlagFile, 2, True)
df.WriteLine Now
df.Close
MsgBox "HISTORY WAS PREVIOUSLY DELETED. A DOWLOADED COPY HAS BEEN SAVED TO YOUR COMPUTER. IF YOU WANT IT CHECK THE DOWNLOADS TAB", vbInformation, "History Cleared"
ElseIf cmd = "/purge" Then
Dim oldBackup
oldBackup = downloadsDir & "\InternetCommunicator_History_Backup.txt"
If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
If fso.FileExists(oldBackup) Then fso.DeleteFile oldBackup, True
If fso.FileExists(deletedFlagFile) Then fso.DeleteFile deletedFlagFile, True
lastUrl = ""
SaveConfig
MsgBox "All history and backup files have been permanently erased!", vbInformation, "IC 1.2"
ElseIf Left(cmd, 1) = "/" Then
MsgBox "Unknown command: " & rawCmd & vbCrLf & "Type /help to see all valid commands.", vbExclamation, "IC 1.2"
Else
OpenWebWindow ResolveAddress(rawCmd), isPrivate
    End If
Loop

