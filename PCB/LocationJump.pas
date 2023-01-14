{ LocationJump.pas

Reads text file TAB delimited from PcbDoc folder & assumes same units as PcbDoc.
# Idx   X    Y
Idx1     x.x    y.y
Idx2     x.x    y.y
.
.

Inserts "Jump action" messages into MM Panel.

Author: B. Miller
14/01/2023 : POC

need to handle origin offset in report file.

Jump action is relative to board origin.
Zoom process is problematic with ZoomLevel  (ZoomLevel also problem in SchServer)
}

const
    locnfile = 'locations.txt';

procedure Locations;
var
    Board      : IPCB_Board;
    BOL        : IPCB_BoardOutline;
    BUnits     : TUnit;
    BRect      : TCoordRect;
    BOrigin    : TPoint;
    BC         : TPoint;
    WS         : IWorkSpace;
    MM         : IDXPMessagesManager;
    MMM1, MMM2 : WideString;
    LocnList   : TStringList;
    LocnLine   : TStringList;
    L          : integer;
    LIdx       : WideString;
    sTemp      : WideString;
    dValue     : extended;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    BUnits := Board.DisplayUnit;
//    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    BC      := TPoint;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);
//    BRect := Board.BoundingRectangle;
    BOL := Board.BoardOutline;
    BRect := BOL.BoundingRectangle;

    BC.X  := (BRect.X1 + BRect.X2) / 2 - BOrigin.X;
    BC.Y  := (BRect.Y1 + BRect.Y2) / 2 - BOrigin.Y;

    WS := GetWorkSpace;
    MM := WS.DM_MessagesManager;
    MM.ClearMessagesForDocument(WS.DM_FocusedDocument.DM_FileName);
    WS.DM_ShowMessageView;
    MM.BeginUpdate;

    LocnList := TStringList.Create;
    LocnList.Delimiter := #10;
    LocnList.StrictDelimiter := true;
    LocnList.LoadFromFile(ExtractFilePath(Board.FileName) + locnfile);
    LocnLine := TStringList.Create;
    LocnLine.Delimiter := #9;
    LocnLine.StrictDelimiter := true;

    for L := 0 to (LocnList.Count - 1) do
    begin
        LocnLine.Delimitedtext := LocnList.Strings(L);
        if ansipos('#', LocnLine.Text) > 0 then continue;
        if LocnLine.Count > 2 then
        begin
            LIdx := LocnLine.Strings(0);
            sTemp := LocnLine.Strings(1);
            StringToCoordUnit(sTemp, dValue, BUnits);
            BC.X := dValue;
            sTemp := LocnLine.Strings(2);
            StringToCoordUnit(sTemp, dValue, BUnits);
            BC.Y := dValue;

            MMM1 := 'Location.X=' + CoordUnitToString(BC.X, BUnits) + ' | Location.Y=' + CoordUnitToString(BC.Y, BUnits);
// Jump
            MMM2 := 'Object=Location | ' + MMM1;
// Zoom
//            MMM2 := 'ZoomLevel=4|Action=Point|' + MMM1;

// Jump
            MM.AddMessage('[Info]', 'ValorDFM violations  : ' + 'Index=' + LIdx +  MMM1 , 'Locations.pas', WS.DM_FocusedDocument.DM_FileName, 'PCB:Jump', MMM2, 3, false);
// Zoom
//            MM.AddMessage('[Info]', 'ValorDFM violations  : ' + 'Index=' + LIdx + ' ' +  MMM1 , 'Locations.pas', WS.DM_FocusedDocument.DM_FileName, 'PCB:Zoom', MMM2, 3, false);
        end;
    end;

//    Client.SendMessage('PCB:ManageGridsAndGuides', 'Action=PlaceVertLineGuide',256, Client.CurrentView);
//      Client.SendMessage('PCB:ManageGridsAndGuides', 'Action=PlaceManualHotSpot|Location.X='+IntToStr(BC.X)+'|Location.Y='+IntToStr(BC.Y), 256, Client.CurrentView);
    MM.EndUpdate;
    WS.DM_ShowMessageView;
end;
