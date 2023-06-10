{ PanPCB.PrjScr PanPCB.pas PanPCBForm.pas .dfm

Allows Pan & zoom across multiple PcbDocs w.r.t individual board origin.
Any Pcbdoc can be used to move all others.

Set to 1sec refresh.
Click or mouse over the form to start.

Author BL Miller

202306010  0.10 POC

tbd:
mirror visible layers
set same current layer
cross highlight CMP with same designator
}

function GetViewRect(dummy : integer) : TCoordRect; forward;

var
    WS         : IWorkSpace;
    Doc        : IDocument;
    SerDoc     : IServerDocument;
    CurrentPCB : IPCB_Board;
    LastPCB    : IPCB_Board;

procedure PanPCBs;
var
    Prj             : IProject;
    Doc             : IDocument;
    I               : integer;
begin
    If Client = Nil Then Exit;
    If PcbServer = nil then exit;

    WS := GetWorkSpace;
    Prj := WS.DM_FocusedProject;
    Doc := WS.DM_FocusedDocument;

    LastPCB    := nil;
    if Doc .DM_DocumentKind = cDocKind_Pcb then
        CurrentPCB := PCBServer.GetCurrentPCBBoard;

    PanPCBForm.Show;
end;

function FocusedPCB(dummy : integer) : boolean;
begin
    Result := false;
    WS := GetWorkSpace;
    Doc := WS.DM_FocusedDocument;
    if Doc .DM_DocumentKind = cDocKind_Pcb then
    begin
        CurrentPCB := PCBServer.GetCurrentPCBBoard;
        Result := true;
    end;
end;

function AllPcbDocs(dummy : integer) : TStringList;
var
    Prj : IProject;
    Doc : IDocument;
    I, J : integer;
begin
    WS := GetWorkSpace;
    Result := TStringlist.Create;
    for I := 0 to (WS.DM_ProjectCount -1) do
    begin
        Prj := WS.DM_Projects(I);
        for J := 0 to (Prj.DM_LogicalDocumentCount - 1) do
        begin
            Doc := Prj.DM_LogicalDocuments(J);
            if Doc.DM_DocumentKind = cDocKind_Pcb then
                Result.AddObject(Doc.DM_FullPath, Doc);
        end;
    end;
end;

function PanOtherPCBDocs(dummy : integer) : boolean;
var
    DocFPath : IDocument;
    OBrd     : IPCB_Board;
    OBO      : TCoordPoint;
    VR       : TcoordRect;
    BrdList  : TStringlist;
    I        : integer;
begin
    Result := false;
    VR := GetViewRect(1);
    BrdList := AllPcbDocs(1);
    for I := 0 to (BrdList.Count -1 ) do
    begin
        DocFPath := BrdList.Strings(I);
        OBrd := PCBServer.GetPCBBoardByPath(DocFPath);

// check if not open in PcbServer & ignore.
        if OBrd = nil then continue;

        If (OBrd.BoardID <> CurrentPCB.BoardID) then
        begin
            OBO := Point(OBrd.XOrigin, OBrd.YOrigin);
            OBrd.GraphicalView_ZoomOnRect(VR.X1+OBO.X, VR.Y1+OBO.Y, VR.X2+OBO.X, VR.Y2+OBO.Y);
//            OBrd.GraphicalView_ZoomOnRect(VR.X1, VR.Y1, VR.X2, VR.Y2);
            OBrd.GraphicalView_ZoomRedraw;
        end;
    end;
    PCBServer.GetPCBBoardByBoardID(CurrentPCB.BoardID);
end;

function GetViewCentre(dummy : integer) : TCoordPoint;
begin
    Result := TPoint;
    Result := Point(CurrentPCB.XCursor - CurrentPCB.XOrigin, CurrentPCB.YCursor - CurrentPCB.YOrigin);
end;

function GetViewRect(dummy : integer) : TCoordRect;
begin
    Result := TRect;
    Result := CurrentPCB.GraphicalView_ViewportRect;
    Result := RectToCoordRect(Rect(Result.X1 - CurrentPCB.XOrigin, Result.Y2 - CurrentPCB.YOrigin,
                                   Result.X2 - CurrentPCB.XOrigin, Result.Y1 - CurrentPCB.YOrigin) );
end;

function GetViewScale(dummy : integer) : extended;
begin
    Result := CurrentPCB.Viewport.Scale;
end;

