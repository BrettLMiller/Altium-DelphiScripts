{ SUIDToClipboard.pas
Copy Selected Component(s)/Footprint(s) details to Clipboard.

Tests the integrity of Footprint source library

BL Miller
19/09/2019  : v0.10 Initial POC
}

procedure CopySUIDToClipBoard;
var
    Board : IPCB_Board;
    ClipB : TClipBoard;
    SUID  : WideString;
    Obj   : IPCB_Object;
    Comp  : IPCB_Component;
    I     : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    ClipB := TClipboard.Create;
    for I := 0 to (Board.SelectecObjectCount - 1) do
    begin
        Obj := Board.SelectecObject(I);
        if Obj.ObjectId = eComponentObject then
        begin
            Comp := Obj;
            if Comp.SourceFootprintLibrary <> Comp.SourceComponentLibrary  then
            begin
                ClipB.AsText:= 'Footprint Source Warning : ' + Comp.SourceFootprintLibrary + ' <> ' + Comp.SourceComponentLibrary;
            end;
            SUID := Comp.SourceDesignator;
            if SUID = '' then SUID := 'no desg.';
            SUID := PadRight(SUID, 10);
            SUID := SUID + ' | ' + PadRight(Comp.Pattern, 30);
            SUID := SUID + ' | ' + Comp.SourceUniqueId;
            ClipB.AsText := SUID;
        end;
    end;
    ClipB.free;
end;
