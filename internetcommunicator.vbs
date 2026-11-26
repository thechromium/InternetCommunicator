Option Explicit

Dim shell, fso, baseDir, historyFile, bookmarkFile, choice, targetUrl, isPrivate
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
isPrivate = False

Function ResolveAddress(rawInput)
    Dim clean
    clean = Trim(rawInput)

    Select Case clean
        Case "1"
            ResolveAddress = "https://github.io"
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
                ResolveAddress = "https://google.com/search?q=" & Replace(clean, " ", "+")
            End If
    End Select
End Function

Sub OpenWebWindow(url, privateSession)
    Dim ts, flags
    If privateSession Then
        flags = " --inprivate"
    Else
        flags = ""
    End If

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
    bName = Trim(InputBox("Enter a short name for this bookmark:" & vbCrLf & "(Example: Roblox or My Channel)", "Add Custom Bookmark"))
    If bName = "" Then Exit Sub

    bUrl = Trim(InputBox("Enter the website URL for '" & bName & "':" & vbCrLf & "(Example: roblox.com)", "Add Custom Bookmark"))
    If bUrl = "" Then Exit Sub
    bUrl = ResolveAddress(bUrl)

    Set ts = fso.OpenTextFile(bookmarkFile, 8, True)
    ts.WriteLine bName & " = " & bUrl
    ts.Close
    MsgBox "Saved bookmark: " & bName & vbCrLf & bUrl, vbInformation, "Internet Communicator 1.0"
End Sub

Sub OpenBookmarkMenu()
    If Not fso.FileExists(bookmarkFile) Then
        MsgBox "No custom bookmarks yet! Type /add in the address bar to save one.", vbInformation, "Custom Bookmarks"
        Exit Sub
    End If

    Dim ts, lines(), count, lineText, menuText, pick, parts
    Set ts = fso.OpenTextFile(bookmarkFile, 1)
    count = 0
    menuText = "CUSTOM BOOKMARKS" & vbCrLf & "==========================================" & vbCrLf

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

    If count = 0 Then
        MsgBox "Your bookmark list is empty! Type /add to create one.", vbInformation, "Custom Bookmarks"
        Exit Sub
    End If

    pick = Trim(InputBox(menuText & "==========================================" & vbCrLf & _
                         "Type a bookmark number (1-" & count & ") to open it, or /wipe to clear all:", _
                         "Internet Communicator 1.0 - Bookmarks", "1"))

    If pick = "" Then Exit Sub
    If LCase(pick) = "/wipe" Then
        fso.DeleteFile bookmarkFile, True
        MsgBox "All custom bookmarks cleared!", vbInformation, "Custom Bookmarks"
        Exit Sub
    End If

    If IsNumeric(pick) Then
        Dim idx
        idx = CInt(pick)
        If idx >= 1 And idx <= count Then
            parts = Split(lines(idx), " = ")
            OpenWebWindow parts(1), isPrivate
        End If
    End If
End Sub

Do
    Dim modeTag
    If isPrivate Then
        modeTag = "[INCOGNITO ON]"
    Else
        modeTag = "[ONLINE]"
    End If

    choice = InputBox( _
        "INTERNET COMMUNICATOR 1.0  " & modeTag & vbCrLf & _
        "1: NexOS   2: Google   3: YouTube   4: Wiki   5: GitHub" & vbCrLf & _
        "Bookmarks: /add  |  /favs       Privacy: /private" & vbCrLf & _
        "History: /history  |  /clear" & vbCrLf & _
        "Enter 1-5, a URL, search terms, or /command:", _
        "Internet Communicator 1.0", "1")

    If choice = "" Then
        Exit Do
    Else
        Select Case LCase(Trim(choice))
            Case "/private"
                isPrivate = Not isPrivate
                If isPrivate Then
                    MsgBox "Private / Incognito Mode is now ON." & vbCrLf & _
                           "Pages will open in Edge InPrivate and will NOT be saved to history.", _
                           vbInformation, "Internet Communicator 1.0 - Privacy"
                Else
                    MsgBox "Private / Incognito Mode is now OFF (Standard Mode).", _
                           vbInformation, "Internet Communicator 1.0 - Privacy"
                End If

            Case "/add"
                AddBookmark

            Case "/favs", "/bookmarks"
                OpenBookmarkMenu

            Case "/history"
                If fso.FileExists(historyFile) Then
                    Dim histStream, histText
                    Set histStream = fso.OpenTextFile(historyFile, 1)
                    If Not histStream.AtEndOfStream Then
                        histText = histStream.ReadAll
                    Else
                        histText = "(History is empty)"
                    End If
                    histStream.Close
                    MsgBox histText, vbInformation, "Internet Communicator 1.0 - History"
                Else
                    MsgBox "No browsing history recorded yet!", vbInformation, "Internet Communicator 1.0 - History"
                End If

            Case "/clear"
                If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
                MsgBox "Browsing history cleared!", vbInformation, "Internet Communicator 1.0"

            Case Else
                If LCase(Left(Trim(choice), 9)) = "/private " Then
                    targetUrl = ResolveAddress(Mid(Trim(choice), 10))
                    OpenWebWindow targetUrl, True
                Else
                    targetUrl = ResolveAddress(choice)
                    OpenWebWindow targetUrl, isPrivate
                End If
        End Select
    End If
Loop

