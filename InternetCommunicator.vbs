Option Explicit

Dim shell, fso, baseDir, historyFile, bookmarkFile, configFile
Dim choice, targetUrl, isPrivate, homeUrl, searchEngine

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
configFile = baseDir & "\ic_config.txt"

isPrivate = False
homeUrl = "https://google.com"
searchEngine = "google"

Sub LoadConfig()
    If fso.FileExists(configFile) Then
        Dim ts, lineText
        Set ts = fso.OpenTextFile(configFile, 1)
        Do While Not ts.AtEndOfStream
            lineText = Trim(ts.ReadLine)
            If Left(lineText, 5) = "HOME=" Then homeUrl = Mid(lineText, 6)
            If Left(lineText, 7) = "ENGINE=" Then searchEngine = LCase(Mid(lineText, 8))
        Loop
        ts.Close
    End If
End Sub

Sub SaveConfig()
    Dim ts
    Set ts = fso.OpenTextFile(configFile, 2, True)
    ts.WriteLine "HOME=" & homeUrl
    ts.WriteLine "ENGINE=" & searchEngine
    ts.Close
End Sub

Function BuildSearchUrl(query)
    Dim encoded
    encoded = Replace(query, " ", "+")
    Select Case searchEngine
        Case "bing"
            BuildSearchUrl = "https://bing.com" & encoded
        Case "duckduckgo"
            BuildSearchUrl = "https://duckduckgo.com" & encoded
        Case Else
            BuildSearchUrl = "https://google.com/search?q=" & encoded
    End Select
End Function

Function ResolveAddress(rawInput)
    Dim clean
    clean = Trim(rawInput)

    Select Case clean
        Case "1"
            ResolveAddress = homeUrl
        Case "2"
            ResolveAddress = "https://google.com"
        Case "3"
            ResolveAddress = "https://youtube.com"
        Case "4"
            ResolveAddress = "https://wikipedia.org"
        Case "5"
            ResolveAddress = "https://github.com"
        Case Else
            If LCase(Left(clean, 7)) = "http://" Or LCase(Left(clean, 8)) = "https://" Then
                ResolveAddress = clean
            ElseIf InStr(clean, ".") > 0 And InStr(clean, " ") = 0 Then
                ResolveAddress = "https://" & clean
            Else
                ResolveAddress = BuildSearchUrl(clean)
            End If
    End Select
End Function

Sub OpenWebWindow(url, privateSession)
    Dim ts, flags
    If privateSession Then flags = " --inprivate" Else flags = ""
    shell.Run "msedge.exe" & flags & " --app=""" & url & """ --window-size=1100,760", 1, False

    If Not privateSession Then
        On Error Resume Next
        Set ts = fso.OpenTextFile(historyFile, 8, True)
        ts.WriteLine Now & "  |  " & url
        ts.Close
        On Error GoTo 0
    End If
End Sub

Sub AddBookmark()
    Dim bName, bUrl, ts
    bName = Trim(InputBox("Enter a short name for this bookmark:", "Internet Communicator 1.1 - Add Bookmark"))
    If bName = "" Then Exit Sub
    bUrl = Trim(InputBox("Enter the URL for '" & bName & "':", "Internet Communicator 1.1 - Add Bookmark"))
    If bUrl = "" Then Exit Sub
    bUrl = ResolveAddress(bUrl)

    Set ts = fso.OpenTextFile(bookmarkFile, 8, True)
    ts.WriteLine bName & " = " & bUrl
    ts.Close
    MsgBox "Saved bookmark: " & bName, vbInformation, "Internet Communicator 1.1"
End Sub

Sub OpenBookmarkMenu()
    If Not fso.FileExists(bookmarkFile) Then
        MsgBox "No custom bookmarks yet! Type /add to save one.", vbInformation, "Internet Communicator 1.1 - Bookmarks"
        Exit Sub
    End If

    Dim ts, lines(), count, lineText, menuText, pick, parts
    Set ts = fso.OpenTextFile(bookmarkFile, 1)
    count = 0
    menuText = "INTERNET COMMUNICATOR 1.1 - BOOKMARKS" & vbCrLf & "==========================================" & vbCrLf

    Do While Not ts.AtEndOfStream
        lineText = Trim(ts.ReadLine)
        If lineText <> "" And InStr(lineText, " = ") > 0 Then
            count = count + 1
            ReDim Preserve lines(count)
            lines(count) = lineText
            menuText = menuText & "  [" & count & "] " & lineText & vbCrLf
        End If
    Loop
    ts.Close

    If count = 0 Then Exit Sub

    pick = Trim(InputBox(menuText & "==========================================" & vbCrLf & _
                         "Type bookmark number (1-" & count & ") or /wipe to clear:", _
                         "Internet Communicator 1.1 - Bookmarks", "1"))
    If pick = "" Then Exit Sub
    If LCase(pick) = "/wipe" Then
        fso.DeleteFile bookmarkFile, True
        MsgBox "All custom bookmarks cleared!", vbInformation, "Internet Communicator 1.1"
        Exit Sub
    End If
    If IsNumeric(pick) Then
        Dim idx : idx = CInt(pick)
        If idx >= 1 And idx <= count Then
            parts = Split(lines(idx), " = ")
            OpenWebWindow parts(1), isPrivate
        End If
    End If
End Sub

LoadConfig

Do
    Dim modeTag
    If isPrivate Then modeTag = "[INCOGNITO]" Else modeTag = "[" & UCase(searchEngine) & "]"

    choice = InputBox( _
        "==========================================" & vbCrLf & _
        "   INTERNET COMMUNICATOR 1.1  " & modeTag & vbCrLf & _
        "==========================================" & vbCrLf & _
        "1: Home   2: Google   3: YouTube   4: Wiki   5: GitHub" & vbCrLf & _
        "Bookmarks: /add | /favs    Settings: /sethome | /engine" & vbCrLf & _
        "Privacy: /private          History: /history | /clear" & vbCrLf & _
        "Enter 1-5, a URL, search words, or /command:", _
        "Internet Communicator 1.1", "1")

    If choice = "" Then
        Exit Do
    Else
        Select Case LCase(Trim(choice))
            Case "/sethome"
                Dim newHome
                newHome = Trim(InputBox("Enter your new Homepage URL (Speed Dial #1):", "Internet Communicator 1.1 - Homepage", homeUrl))
                If newHome <> "" Then
                    homeUrl = ResolveAddress(newHome)
                    SaveConfig
                    MsgBox "Homepage updated to:" & vbCrLf & homeUrl, vbInformation, "Internet Communicator 1.1"
                End If

            Case "/engine"
                Dim eng
                eng = LCase(Trim(InputBox("Choose your default search engine:" & vbCrLf & _
                                          "Type:  google   |   bing   |   duckduckgo", "Internet Communicator 1.1 - Search Engine", searchEngine)))
                If eng = "google" Or eng = "bing" Or eng = "duckduckgo" Then
                    searchEngine = eng
                    SaveConfig
                    MsgBox "Default search engine set to " & UCase(searchEngine) & "!", vbInformation, "Internet Communicator 1.1"
                End If

            Case "/private"
                isPrivate = Not isPrivate
                MsgBox "Private / Incognito Mode: " & IIf(isPrivate, "ON", "OFF"), vbInformation, "Internet Communicator 1.1"

            Case "/add"
                AddBookmark

            Case "/favs", "/bookmarks"
                OpenBookmarkMenu

            Case "/history"
                If fso.FileExists(historyFile) Then
                    Dim hs, ht : Set hs = fso.OpenTextFile(historyFile, 1)
                    If Not hs.AtEndOfStream Then ht = hs.ReadAll Else ht = "(Empty)"
                    hs.Close
                    MsgBox ht, vbInformation, "Internet Communicator 1.1 - History"
                Else
                    MsgBox "No history recorded yet!", vbInformation, "Internet Communicator 1.1"
                End If

            Case "/clear"
                If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
                MsgBox "History cleared!", vbInformation, "Internet Communicator 1.1"

            Case Else
                If LCase(Left(Trim(choice), 9)) = "/private " Then
                    OpenWebWindow ResolveAddress(Mid(Trim(choice), 10)), True
                Else
                    OpenWebWindow ResolveAddress(choice), isPrivate
                End If
        End Select
    End If
Loop

