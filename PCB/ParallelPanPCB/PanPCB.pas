{ PanPCB.PrjScr PanPCB.pas PanPCBForm.pas .dfm

Allows Pan & zoom across multiple PcbDocs w.r.t individual board origin.
Any Pcbdoc can be used to move all others.

Set to 1sec refresh.
Click or mouse over the form to start.

Author BL Miller

202306010  0.10 POC
20230611   0.11 fix tiny mem leak, form to show cursor not BR, failed attempt set current layer.
20230611   0.20 eliminate use WorkSpace & Projects to allow ServDoc.Focus etc

tbd:
mirror visible layers       ; seems not to work
set same current layer      ; seems not to work with scope & is TV7_layer.
cross highlight CMP with same designator

SetState_CurrentLayer does not exist, & .CurrentLayer appears to fail to set other PcbDocs.
}
const
    LongTrue = -1;

function FocusedPCB(dummy : integer) : boolean;     forward;
function GetViewRect(dummy : integer) : TCoordRect; forward;

var
    CurrentPCB : IPCB_Board;

procedure PanPCBs;
begin
    If Client = Nil Then Exit;
    If PcbServer = nil then exit;

    FocusedPCB(1);

    PanPCBForm.Show;
end;

function FocusedPCB(dummy : integer) : boolean;
var
    SM      : IServerModule;
    ServDoc : IServerDocument;
    I       : integer;
begin
    Result := false;

    SM := Client.ServerModuleByName('PCB');
    for I := 0 to (SM.DocumentCount -1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind = cDocKind_Pcb) then
        if (ServDoc.IsShown = LongTrue) then
        begin
            CurrentPCB := PCBServer.GetCurrentPCBBoard;
            if CurrentPCB <> nil then
                Result := true;
        end;
    end;
end;

function AllPcbDocs(dummy : integer) : TStringList;
var
    SM      : IServerModule;
    Prj     : IProject;
    ServDoc : IServerDocument;
    Doc     : IDocument;
    I, J    : integer;
begin
    Result := TStringlist.Create;

    SM := Client.ServerModuleByName('PCB');
    for I := 0 to (SM.DocumentCount -1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind = cDocKind_Pcb) then
            Result.AddObject(ServDoc.FileName, ServDoc);
    end;
end;

function PanOtherPCBDocs(dummy : integer) : boolean;
var
    DocFPath : WideString;
    ServDoc  : IServerDocument;
    CIndex   : integer;
    OBrd     : IPCB_Board;
    OBO      : TCoordPoint;
    VR       : TcoordRect;
    BrdList  : TStringlist;
    I        : integer;
    CLayer   : TLayer;
    OLayer   : TLayer;

    BLSM     : IPCB_BoardLayerSetManager;
    LSet     : IPCB_LayerSet;
    CLSName  : WideString;
    CLSIndex : integer;
    CVM      : TPCBViewMode;
    CLO      : IPCB_LayerObject;
    CLName   : WideString;
begin
    Result := false;

    CLayer := CurrentPCB.GetState_CurrentLayer;
    CLName := CurrentPCB.LayerName(CLayer);
    CVM    := CurrentPCB.GetState_MainGraphicalView.GetState_ViewMode;
//    BLSM := CurrentPCB.BoardLayerSetManager;
//    CLSIndex := BLSM.CurrentLayersetName;       // does not exist!
//    BLSet := BLSM.BoardLayerSetByIndex(CLSIndex);
//    CLSName := BLSM.BoardLayerSetByName(CurrentLSName);
//    BLSM.MakeCurrent(CLSIndex);
//                CLO.IsDisplayed[OBrd] := true;

    VR := GetViewRect(1);
    BrdList := AllPcbDocs(1);
    CIndex := -1;
    for I := 0 to (BrdList.Count -1 ) do
    begin
        DocFPath := BrdList.Strings(I);
        ServDoc := BrdList.Objects(I);
        OBrd := PCBServer.GetPCBBoardByPath(DocFPath);
// check if not open in PcbServer & ignore.
// should be redundant when using ServerDocument.
        if OBrd = nil then continue;

        If (OBrd.BoardID <> CurrentPCB.BoardID) then
        begin
              ServDoc.Focus;

// this just does not work.
//            OBrd.ViewManager_UpdateLayerTabs;
//            OBrd.GetState_MainGraphicalView.SetState_ViewMode(CVM);

            OLayer := OBrd.Getstate_CurrentLayer;
            if (OLayer <> CLayer) then
            begin
// this section never executes!!
                if (not OBrd.VisibleLayers.Contains(CLayer)) then
                    LSet := OBrd.VisibleLayers.Include(CLayer);

                OBrd.LayerIsDisplayed(CLayer) := true;
                OBrd.CurrentLayerV6 := CurrentPCB.GetState_CurrentLayerV6;
                OBrd.CurrentLayer := CLayer;
//                Client.SendMessage('PCB:SetCurrentLayer', 'Layer=' + IntToStr(CLayer) , 255, Client.CurrentView);
                OBrd.ViewManager_UpdateLayerTabs;
            end;
            OBO := Point(OBrd.XOrigin, OBrd.YOrigin);
            OBrd.GraphicalView_ZoomOnRect(VR.X1+OBO.X, VR.Y1+OBO.Y, VR.X2+OBO.X, VR.Y2+OBO.Y);
            OBrd.GraphicalView_ZoomRedraw;
            Result := true;
        end
        else CIndex := I;
    end;
    PCBServer.GetPCBBoardByBoardID(CurrentPCB.BoardID);
    if CIndex > -1 then
    begin
        ServDoc := BrdList.Objects(CIndex);
        ServDoc.Focus;
    end;
    BrdList.Clear;
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

