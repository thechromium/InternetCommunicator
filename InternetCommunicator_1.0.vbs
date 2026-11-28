Option Explicit
Dim shell, fso, baseDir, historyFile, bookmarkFile, choice, isPrivate
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
isPrivate = False

Function ResolveAddress(raw)
    Dim c : c = Trim(raw)
    Select Case c
        Case "1": ResolveAddress = "https://google.com"
        Case "2": ResolveAddress = "https://youtube.com"
        Case "3": ResolveAddress = "https://wikipedia.org"
        Case "4": ResolveAddress = "https://github.com"
        Case "5": ResolveAddress = "https://github.io"
        Case Else
            If LCase(Left(c, 7)) = "http://" Or LCase(Left(c, 8)) = "https://" Then
                ResolveAddress = c
            ElseIf InStr(c, ".") > 0 And InStr(c, " ") = 0 Then
                ResolveAddress = "https://" & c
            Else
                ResolveAddress = "https://google.com/search?q=" & Replace(c, " ", "+")
            End If
    End Select
End Function

Sub OpenWeb(url, priv)
    Dim ts, flag
    If priv Then flag = " --inprivate" Else flag = ""
    shell.Run "msedge.exe" & flag & " --app=""" & url & """", 1, False
    If Not priv Then
        Set ts = fso.OpenTextFile(historyFile, 8, True)
        ts.WriteLine Now & " | " & url
        ts.Close
    End If
End Sub

Do
    choice = InputBox("Internet Communicator 1.0" & vbCrLf & "1:Google 2:YouTube 3:Wiki 4:GitHub 5:IC Home" & vbCrLf & "Commands: /add /favs /private /history /clear", "Internet Communicator 1.0", "1")
    If choice = "" Then Exit Do
    Select Case LCase(Trim(choice))
        Case "/private": isPrivate = Not isPrivate : MsgBox "Private Mode: " & isPrivate, vbInformation, "IC 1.0"
        Case "/add"
            Dim bn, bu, bts
            bn = InputBox("Bookmark name:", "Add Bookmark")
            If bn <> "" Then
                bu = InputBox("URL:", "Add Bookmark")
                If bu <> "" Then Set bts = fso.OpenTextFile(bookmarkFile, 8, True) : bts.WriteLine bn & " = " & ResolveAddress(bu) : bts.Close
            End If
        Case "/favs"
            If fso.FileExists(bookmarkFile) Then
                Dim ft : Set ft = fso.OpenTextFile(bookmarkFile, 1) : MsgBox ft.ReadAll, vbInformation, "Bookmarks" : ft.Close
            Else
                MsgBox "No bookmarks yet!", vbInformation, "IC 1.0"
            End If
        Case "/history"
            If fso.FileExists(historyFile) Then
                Dim ht : Set ht = fso.OpenTextFile(historyFile, 1) : MsgBox ht.ReadAll, vbInformation, "History" : ht.Close
            Else
                MsgBox "No history yet!", vbInformation, "IC 1.0"
            End If
        Case "/clear"
            If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True
            MsgBox "History cleared!", vbInformation, "IC 1.0"
        Case Else
            OpenWeb ResolveAddress(choice), isPrivate
    End Select
Loop
