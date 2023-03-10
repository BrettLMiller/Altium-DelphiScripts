' Focus Altium app & send <enter> keycode
' will close &/or Okay open/blocking/modal dialogs

Dim ObjShell
Dim testArg

Set objArgs = Wscript.Arguments

testArg = 1000

if objArgs.Count > 0 then
    testArg = objArgs(0)
end if

' Wscript.Echo now &": "& testArg

Set ObjShell = CreateObject("Wscript.Shell")

' show user Altium script message
ObjShell.AppActivate("Altium")

Wscript.Sleep testArg

' user may have moved focus to another app/screen/window
ObjShell.AppActivate("Altium")
ObjShell.SendKeys "{ENTER}"
