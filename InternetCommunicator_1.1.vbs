Option Explicit
Dim shell, fso, baseDir, historyFile, bookmarkFile, configFile, choice, isPrivate, homeUrl, searchEngine
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
historyFile = baseDir & "\ic_history.txt"
bookmarkFile = baseDir & "\ic_bookmarks.txt"
configFile = baseDir & "\ic_config.txt"
isPrivate = False : homeUrl = "https://google.com" : searchEngine = "google"

If fso.FileExists(configFile) Then
    Dim ts, ln : Set ts = fso.OpenTextFile(configFile, 1)
    Do While Not ts.AtEndOfStream
        ln = Trim(ts.ReadLine)
        If Left(ln, 5) = "HOME=" Then homeUrl = Mid(ln, 6)
        If Left(ln, 7) = "ENGINE=" Then searchEngine = LCase(Mid(ln, 8))
    Loop
    ts.Close
End If

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

Sub OpenWeb(url, priv)
    Dim ts, flag
    If priv Then flag = " --inprivate" Else flag = ""
    shell.Run "msedge.exe" & flag & " --app=""" & url & """", 1, False
    If Not priv Then Set ts = fso.OpenTextFile(historyFile, 8, True) : ts.WriteLine Now & " | " & url : ts.Close
End Sub

Do
    choice = InputBox("Internet Communicator 1.1 [" & UCase(searchEngine) & "]" & vbCrLf & "1:Home 2:Google 3:YouTube 4:Wiki 5:GitHub" & vbCrLf & "Commands: /sethome /engine /add /favs /private /history /clear", "Internet Communicator 1.1", "1")
    If choice = "" Then Exit Do
    Select Case LCase(Trim(choice))
        Case "/sethome"
            Dim nh : nh = InputBox("New Homepage:", "Set Home", homeUrl)
            If nh <> "" Then homeUrl = ResolveAddress(nh) : Dim cs : Set cs = fso.OpenTextFile(configFile, 2, True) : cs.WriteLine "HOME=" & homeUrl & vbCrLf & "ENGINE=" & searchEngine : cs.Close
        Case "/engine"
            Dim eg : eg = LCase(Trim(InputBox("google, bing, or duckduckgo:", "Engine", searchEngine)))
            If eg = "google" Or eg = "bing" Or eg = "duckduckgo" Then searchEngine = eg : Dim cs2 : Set cs2 = fso.OpenTextFile(configFile, 2, True) : cs2.WriteLine "HOME=" & homeUrl & vbCrLf & "ENGINE=" & searchEngine : cs2.Close
        Case "/private": isPrivate = Not isPrivate : MsgBox "Private Mode: " & isPrivate, vbInformation, "IC 1.1"
        Case "/add"
            Dim bn, bu, bts
            bn = InputBox("Bookmark name:", "Add Bookmark")
            If bn <> "" Then bu = InputBox("URL:", "Add Bookmark") : If bu <> "" Then Set bts = fso.OpenTextFile(bookmarkFile, 8, True) : bts.WriteLine bn & " = " & ResolveAddress(bu) : bts.Close
        Case "/favs"
            If fso.FileExists(bookmarkFile) Then Dim ft : Set ft = fso.OpenTextFile(bookmarkFile, 1) : MsgBox ft.ReadAll, vbInformation, "Bookmarks" : ft.Close
        Case "/history"
            If fso.FileExists(historyFile) Then Dim ht : Set ht = fso.OpenTextFile(historyFile, 1) : MsgBox ht.ReadAll, vbInformation, "History" : ht.Close
        Case "/clear"
            If fso.FileExists(historyFile) Then fso.DeleteFile historyFile, True : MsgBox "History cleared!", vbInformation, "IC 1.1"
        Case Else
            OpenWeb ResolveAddress(choice), isPrivate
    End Select
Loop
