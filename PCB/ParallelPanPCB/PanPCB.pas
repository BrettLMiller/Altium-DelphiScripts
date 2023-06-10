{ PanPCB.PrjScr PanPCB.pas PanPCBForm.pas .dfm

Allows Pan & zoom across multiple PcbDocs w.r.t individual board origin.
Any Pcbdoc can be used to move all others.

Set to 1sec refresh.
Click or mouse over the form to start.

Author BL Miller

202306010  0.10 POC
20230611   0.11 fix tiny mem leak, form to show cursor not BR, failed attempt set current layer.

tbd:
mirror visible layers       ;
set same current layer      ; seems not to work with scope & is TV6_layer.
cross highlight CMP with same designator
}

function GetViewRect(dummy : integer) : TCoordRect; forward;

var
    WS         : IWorkSpace;
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
    if Doc.DM_DocumentKind = cDocKind_Pcb then
        CurrentPCB := PCBServer.GetCurrentPCBBoard;

    PanPCBForm.Show;
end;

function FocusedPCB(dummy : integer) : boolean;
var
    Doc : IDocument;
begin
    Result := false;
    WS := GetWorkSpace;
    Doc := WS.DM_FocusedDocument;
    if Doc .DM_DocumentKind = cDocKind_Pcb then
    begin
        CurrentPCB := PCBServer.GetCurrentPCBBoard;
        if CurrentPCB <> nil then
            Result := true;
    end;
end;

function AllPcbDocs(dummy : integer) : TStringList;
var
    Prj : IProject;
    Doc : IDocument;
    I, J : integer;
begin
    if WS = nil then WS := GetWorkSpace;

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
    BLSM     : IPCB_BoardLayerSetManager;
    LSet    : IPCB_LayerSet;
    OBO      : TCoordPoint;
    VR       : TcoordRect;
    BrdList  : TStringlist;
    I        : integer;
    CLSName  : WideString;
    CLSIndex : integer;
    CLayer   : TLayer;
    CLO      : IPCB_LayerObject;
    CLName   : WideString;
begin
    Result := false;

    CLayer := CurrentPCB.GetState_CurrentLayer;
    CLName := CurrentPCB.LayerName(CLayer);
//    LSet := CurrentPCB.VisibleLayers.Replicate;
//    BLSM := CurrentPCB.BoardLayerSetManager;
//    CLSIndex := BLSM.CurrentLayersetName;
//    BLSet := BLSM.BoardLayerSetByIndex(LSCount-1);
//    CLSName := BLSM.BoardLayerSetByName(CurrentLSName);
//            BLSM := OBrd.BoardLayerSetManager; //  TBoardLayerSetManager;
//            BLSM.MakeCurrent(CLSIndex);
//                CLO.IsDisplayed[OBrd] := true;

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
            if (OBrd.CurrentLayer <> CLayer) then
            begin
                if not OBrd.VisibleLayers.Contains(CLayer) then
                    OBrd.VisibleLayers.Include(CLayer);

                OBrd.CurrentLayer := CLayer;
//                Client.SendMessage('PCB:SetCurrentLayer', 'Layer=' + IntToStr(CLayer) , 255, Client.CurrentView);
                OBrd.ViewManager_UpdateLayerTabs;
            end;
            OBO := Point(OBrd.XOrigin, OBrd.YOrigin);
            OBrd.GraphicalView_ZoomOnRect(VR.X1+OBO.X, VR.Y1+OBO.Y, VR.X2+OBO.X, VR.Y2+OBO.Y);
            OBrd.GraphicalView_ZoomRedraw;
            Result := true;
        end;
    end;
    BrdList.Clear;
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

