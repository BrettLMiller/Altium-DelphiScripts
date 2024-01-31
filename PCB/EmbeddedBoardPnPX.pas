{ EmbeddedBoardPnPX.pas

  report Embedded Boards
  generate PnP (built-in report) for single Row & single column of all embedded board objects.
  add outlines & region shape from child brd shapes
  add keepouts to panel board from EMB child brds
  generate a full Placement file with EMB & row & column indexes.
  add panel board cutouts from EMB route path (make 3D step with cutouts.
  add EMB child board-cutout shape & region to panel board shape layer.
  support defined RouteToolPath layer per child board tho all should match, may change with layerkinds etc!

  Author BL Miller
20220503  0.10  POC adapted from EmbeddedObjects.pas.
20220505  0.11  add EMB bounding rect on mechlayer
20220506  0.12  draw column & row margins & spacing lines.
20220514  0.13  add region & polyline outline of each item in EMB.
20220520  0.14  add KOs from specified objects/layers, adds KO region from board shape.
20220421  0.15  add Placement file report with EMB & row & column indices
20220606  0.16  region location error if board shape was convex: use bounding box calc. move.
20220701  0.17  separate text from regionshape fn & layer.
20221028  0.18  use RouteToolpath & MechLayerKind
20221217  0.19  later AD 21-22 does not like to pass IPCB_ChildBoard object.
20230626  0.20  forgot to report mirrored
20230720  0.21  factor out more code with CalcEMB..()
20230722  0.22  above refactor caused error in DrawBox(), refactor combine most positioning code.
20240201  0.23  set board tag text (E ,R ,C) in RowCol order same as placement file.

Child board-outline bounding rect is used to align to EMB origin
AD17 Outjob placement file for any mirrored EMB is wrong!

Can not access/create board stack RegionSplitLines in AD17

}
const
   cBoardShapeLayer  = 1;     // default board shape layer
   cMLKBoardShape    = 30;    // const for AD19+ layerkind.

// mechanical layers
   cOutlineLayer     = 51;    // destination outlines
   cRegShapeLayer    = 53;    // destination region shapes
   cTextLayer        = 52;    // destination text labels
   cBrdRegionLayer   = 54;
   cBrdRegOLLayer    = 55;    // outlines of board regions.
   cBrdRegSplitLayer = 56;
   cBrdRegFoldLayer  = 57;

// make keepouts source layer
   cMLKRouteToolPath = 28;    // for old vers that do not have builtin const for layerkind 'Route Tool Path'
   cRouteNPLayer     = 11;    // fall-back source NTP routing profile if no Kind found

   cTextHeight   = 5;
   cTextWidth    = 0.5;
   cLineWidth    = 1;
   ArcResolution = 0.25;   // mils

 // tbd - parse these options instead of hard coded..
   cKeepouts    = 'M11=AT|M1=BO';  // create KO layer objs from layer=obj  [A,T,BO,R]
   cBrdCutouts  = 'M11=AT';
   cPolyCutouts = 'M11=AT';

// version
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32; 
    AD19MaxMechLayers = 1024;


var
    Board         : IPCB_Board;
    Borigin       : TPoint;
    BUnits        : TUnit;
    Report        : TStringList;
    FileName      : WideString;
    VerMajor      : integer;
    MaxMechLayers : integer;
    LegacyMLS     : boolean;

function DrawBox(EMB : IPCB_EmbeddedBoard, const Layer : TLayer, const UIndex : integer, const Tag : WideString) : boolean;     forward;
function DrawPolyRegOutlines(EMB : IPCB_EmbeddedBoard, POList : TObjectList, const Layer : TLayer, UIndex : integer, EIndex : integer) : TObjectList; forward;
function DrawBOLRegions(EMB : IPCB_EmbeddedBoard, Layer : TLayer, RegKind : TRegionKind, const UIndex : integer, var SBR : TCoordRect) : TObjectList; forward;
function ReportOnEmbeddedBoard (EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean;                forward;
function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;                     forward;
function AddPrims(EMB : IPCB_EmbeddedBoard, ObjList : TObjectList, const Layer : TLayer, NewKind : TRegionKind, UIndex : integer) : boolean;           forward;
function SetPrimsAsKeepouts(PL : TObjectList, const Layer : TLayer) : boolean;                                                  forward;
function MakeRegionFromPolySegList (PLBO : IPCB_BoardOutline, const Layer : TLayer, const RegObjID : integer, const RegKind : TRegionKind, Add : boolean) : IPCB_Region; forward;
function MakeRegion(GPC : IPCB_GeometricPolygon, Net : IPCB_Net, const Layer : TLayer, const UIndex : integer, const MainContour : boolean) : IPCB_Region; forward;
function MaxBR(SBR : TCoordRect, TBR : TCoordRect) : TCoordRect;                                              forward;
function GetBoardObjs(Board : IPCB_Board, ObjSet : TSet, LayerSet : IPCB_LayerSet ) : TObjectList;            forward;
function GetChildBoardObjs(EMB : IPCB_EmbeddedBoard, ObjSet : TSet, LayerSet : IPCB_LayerSet) : TObjectList;  forward;
function GetChildBoardObjsL(EMB : IPCB_EmbeddedBoard, ObjSet : TSet, Layer : TLayer) : TObjectList;           forward;
function CollapseEmbeddedBoard (EMB : IPCB_EmbeddedBoard) : boolean;                                          forward;
function RestoreEmbeddedBoard (EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean;       forward;
function GetEmbeddedBoards(ABoard : IPCB_Board) : TObjectList;                                 forward;
function GetEmbeddedBoardComps(EMBI : integer; EMB : IPCB_EmbeddedBoard) : boolean;            forward;
function TestVersion(const dummy : integer) : integer;                                         forward;
function GetMechLayerByKind(LS : IPCB_MasterLayerStack, MLK : TMechanicalLayerKind) : TLayer;  forward;
function FilterForMask(POList : TObjectlist, Layers : IPCB_LayerSet) : TObjectList;            forward;
function FilterForBoardCutOut(POList : TObjectlist, Layers : IPCB_LayerSet) : TObjectList;     forward;
procedure CalcEMBIndexes(EMB : IPCB_EmbeddedBoard, var RS, var CS, var RM, var CM : TCoord, var RowCnt, var ColCnt : integer);             forward;
function PositionPrim(var NewPrim : IPCB_Primitive, CBO : TCoordPoint, RefP : TCoordPoint, const Rotation : double, const Mirror : boolean) : boolean; forward;
function MakeShapeContours(MaskObjList : TObjectList, Operation : TSetOperation, Layer : TLayer, Expansion : TCoord) : TInterfaceList;     forward;
function GetMainContour(GPC : IPCB_GeometricPolygon) : Integer;    forward;

procedure ReportEmbeddedBoardObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    Layer             : ILayer;
    RowCnt            : Array [0..100];
    ColCnt            : Array [0..100];
    RC, CC            : Integer;
    I                 : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    GetCurrentDocumentUnitSystem;  // TUnitSystem
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    Report := TStringList.Create;

    EmbeddedBoardList := GetEmbeddedBoards(Board);
    ShowMessage('embedded board count : ' + IntTostr(EmbeddedBoardList.Count));
    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        RC := 1; CC := 1;
        ReportOnEmbeddedBoard(EMB, RC, CC);
        RowCnt[I] := RC; ColCnt[I] := CC;
        CollapseEmbeddedBoard(EMB);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    ShowMessage('single ');

// Output default placement (sadly reuses last report setup)
    Client.SendMessage('WorkspaceManager:GenerateReport', 'ObjectKind=Assembly|Index=2|DoEditProperties=False|DefaultCaption=True|DoGenerate=True', 512, Client.CurrentView);

// restore the original row & column counts.
    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        RC := RowCnt[I]; CC := ColCnt[I];
        RestoreEmbeddedBoard(EMB, RC, CC);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    Board.ViewManager_FullUpdate;

// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);
    ShowMessage('restored ');

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    Report.Add(' Panel pads      : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));
    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\EmbeddedBrdObj.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

procedure EmbBrdCompPlacementReport;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    BIterator         : IPCB_BoardIterator;
    BLayerSet         : TPCB_LayerSet;
    Comp              : IPCB_Component;
    Rotation          : float;
    RC, CC            : Integer;
    I                 : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    Report := TStringList.Create;

    BLayerSet := LayerSetUtils.EmptySet;
    BLayerSet.IncludeSignalLayers;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    Report.Add('EI |RI |CI |Designator|Footprint                               |   X   |   Y   |  Rot | Layer ');
    Comp := BIterator.FirstPCBObject;
    while (Comp <> Nil) do
    begin
        Rotation := Comp.Rotation;
        if Rotation = 360 then rotation := 0;

        Report.Add(Padright(IntToStr(0),3) + '|' + Padright(IntToStr(0),3) + '|' + PadRight(IntToStr(0),3) + '|' + PadRight(Comp.Name.Text,10) + '|' +
                   PadRight(Comp.Pattern,40) + '|' +
                   Padleft(FormatFloat('#0.000#', CoordToMMs_FullPrecision(Comp.X - BOrigin.X)),7) + '|' +  Padleft(FormatFloat('#0.000#', CoordToMMs_FullPrecision(Comp.Y - BOrigin.Y)),7) + '|' +
                   Padleft(FormatFloat('0.0#',Rotation),6) + '| ' + Layer2String(Comp.Layer) );

        Comp := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);

    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        GetEmbeddedBoardComps(I, EMB);
    end;

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    Report.Add(' Panel pads            : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));
    Report.Add(' Panel holes           : ' + IntToStr(Board.GetPrimitiveCounter.HoleCount(eRoundHole)));
    Report.Add(' Panel components      : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(eComponentObject)));
    Report.Add(' Panel embedded boards : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(eEmbeddedBoardObject)));
    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\EMBCompPlace.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

// needs work on using pad mask shape.
procedure AddPasteToEmbdBrdObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
//    CB                : IPCB_Board;
    POList            : TObjectList;
    Layer             : TLayer;
    OSet              : TObjectSet;
    Layers            : IPCB_LayerSet;
    I                 : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    VerMajor := TestVersion(0);

    Report := TStringList.Create;

    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        Layer := eTopPaste;

        Layers := LayerSetUtils.CreateLayerSet.Include(Layer);
        Layers.Include(eTopLayer);
        LayerUtils.FromString('Top Paste');

        OSet := MkSet(ePadObject, eRegionObject, eTrackObject, eArcObject);

// need to clone early so can set expansion?.
// cloning copper does NOT get the right paste size/shape !
        POList := GetChildBoardObjs(EMB, OSet, Layers);
        POList := FilterForMask(POList, Layers);

        Layer   := eTopPaste;
        AddPrims(EMB, POList, Layer, eRegionKind_Copper, 0);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\AddPasteEmbBrd.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

procedure AddBoardCutOutsToPanelShapeLayer;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    LS                : IPCB_MasterLayerStack;
    POList            : TObjectList;
    POList2           : TObjectList;
    Layer             : TLayer;
    PLayer            : TLayer;
    OSet              : TObjectSet;
    Layers            : IPCB_LayerSet;
    I                 : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    VerMajor := TestVersion(0);
    Report := TStringList.Create;

    LS := Board.MasterLayerStack;
    PLayer := GetMechLayerByKind(LS, cMLKBoardShape);
    if PLayer = 0 then
        PLayer := LayerUtils.MechanicalLayer(cBoardShapeLayer);

    Layer := eMultiLayer;
    Layers := LayerSetUtils.CreateLayerSet.Include(Layer);
    OSet   := MkSet(eRegionObject);

    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);

// need to clone early so can set expansion?.
        POList := GetChildBoardObjs(EMB, OSet, Layers);
        POList := FilterForBoardCutOut(POList, Layers);

// Count=0 means special BOL mode!
        if POList.Count > 0 then
            DrawPolyRegOutlines(EMB, POList, PLayer, 0, 0);

// adding board cutout regions inside EMBs destroys 3D view.
//        Layer   := eMultiLayer;
        if POList.Count > 0 then
            AddPrims(EMB, POList, PLayer, eRegionKind_Cutout, 0);

    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\AddCutOutsEmbBrd.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

procedure AddKeepOutsToEmbdBrdObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    LS                : IPCB_MasterLayerStack;
    CB                : IPCB_Board;
    KORegList         : TObjectList;
    NewKOList         : TObjectList;
    RegKind           : TRegionKind;
    KOList            : TObjectList;
    Layer             : TLayer;
    OSet              : TObjectSet;
    Layers            : IPCB_LayerSet;
    I                 : integer;
    SBR               : TCoordRect;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    VerMajor := TestVersion(0);

    Report := TStringList.Create;
    SBR := TCoordRect;
    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        CB  := EMB.ChildBoard;
        LS  := CB.MasterLayerStack;
        Layer := CB.RouteToolPathLayer;

        if Layer = 0 then
            Layer := GetMechLayerByKind(LS, cMLKRouteToolPath);
        if Layer = 0 then
            Layer := LayerUtils.MechanicalLayer(cRouteNPLayer);

        Layers := LayerSetUtils.CreateLayerSet.Include(Layer);
        OSet   := MkSet(eTrackObject, eArcObject);

        KOList := GetChildBoardObjs(EMB, OSet, Layers);

        Layer   := eKeepOutLayer;
        RegKind := eRegionKind_Copper;
        NewKOList := AddPrims(EMB, KOList, Layer, RegKind, 0);

        SetPrimsAsKeepouts(NewKOList, Layer);

        KORegList := DrawBOLRegions(EMB, Layer, RegKind, 0, SBR);
        SetPrimsAsKeepouts(KORegList, Layer);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

//    Report.Add(' KOs       : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\AddKOEmbBrd.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

/// make board cutouts from Routetool path
procedure AddRoutePathAsBoardCutOuts;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    CB                : IPCB_Board;
    LS                : IPCB_MasterLayerStack;
    NewRegion         : IPCB_Region;
    POList            : TObjectList;
    GPOL              : TInterfacetList;
    GMPC              : IPCB_GeometricPolygon;
    Layer             : TLayer;
    OSet              : TObjectSet;
    Layers            : IPCB_LayerSet;
    I, J              : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    VerMajor := TestVersion(0);

    Report := TStringList.Create;
    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        CB  := EMB.ChildBoard;
        LS  := CB.MasterLayerstack;
        Layer := CB.RouteToolPathLayer;

        if Layer = 0 then
            Layer := GetMechLayerByKind(LS, cMLKRouteToolPath);
        if Layer = 0 then
            Layer := LayerUtils.MechanicalLayer(cRouteNPLayer);

        Layers := LayerSetUtils.CreateLayerSet.Include(Layer);
        OSet   := MkSet(eTrackObject, eArcObject);

        Layer := LayerUtils.MechanicalLayer(cRouteNPLayer);
        POList := GetChildBoardObjs(EMB, OSet, Layers);

//        Contour & combine then make region
        GPOL := MakeShapeContours(POList, eSetOperation_Union, Layer, 0);

        Layer := eMultiLayer;
        POList.Clear;
        for J := 0 to (GPOL.Count - 1) do
        begin
            GMPC := GPOL.Items(J);                             //UnionIndex
            NewRegion := MakeRegion(GMPC, nil, Layer, 0, true);
            NewRegion.SetState_Kind(eRegionKind_BoardCutout);
            POList.Add(NewRegion);
        end;
        AddPrims(EMB, POList, Layer, -1, 0);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!
    if POList <> nil then POList.Destroy;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\AddRTPtoEmbBrd.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

procedure AddOutlinesToEmbdBrdObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    RegKind           : TRegionKind;
    POList            : TObjectList;
    Layer             : ILayer;
    Layer2            : ILayer;
    RC, CC            : Integer;
    I                 : integer;
    SBR               : TCoordRect;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    POList := TObjectList.Create;
    POList.OwnsObjects := false;
    Report := TStringList.Create;
    SBR := TCoordRect;

    Layer  := LayerUtils.MechanicalLayer(cOutlineLayer);
    Layer2 := LayerUtils.MechanicalLayer(cRegShapeLayer);
    EmbeddedBoardList := GetEmbeddedBoards(Board);

    RegKind := eRegionKind_Copper;

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);

        DrawBox(EMB, Layer, 0, 'array');

        POList.Clear;
        DrawPolyRegOutlines(EMB, POList, Layer, 0, (I+1) );
        DrawBOLRegions(EMB, Layer2, RegKind, 0, SBR);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);

    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!
    POList.Destroy;

//    Report.Add(' Panel pads      : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));
//    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
//    FileName := ExtractFilePath(FileName) + '\AddEmbeddedBrdObj.txt';
//    Report.SaveToFile(FileName);
    Report.Free;
end;

function GetEmbeddedBoardComps(EMBI : integer; EMB : IPCB_EmbeddedBoard) : boolean;
var
    CB        : IPCB_Board;
    PLBO      : IPCB_BoardOutline;
    CBBR      :  TCoordRect;    // child board bounding rect
    BIterator : IPCB_BoardIterator;
    BLayerSet : IPCB_LayerSet;
    Comp      : IPCB_Component;
    NewComp   : IPCB_Component;
    Rotation  : float;
    EMBO     : TCoordPoint;
    CBO      : TCoordPoint;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    X, Y     : TCoord;

begin
    Result := 0;
    CB   := EMB.ChildBoard;
    PLBO := CB.BoardOutline;
    CBBR := PLBO.BoundingRectangle;
    CBO  := Point(CBBR.X1, CBBR.Y1);

    CalcEMBIndexes(EMB, RS, CS, RM, CM, RowCnt, ColCnt);

    BLayerSet := LayerSetUtils.EmptySet;
    BLayerSet.IncludeSignalLayers;
    BIterator := CB.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin
// origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

            Comp := BIterator.FirstPCBObject;
            while (Comp <> Nil) do
            begin
                NewComp := Comp.Replicate;
                PositionPrim(NewComp, CBO, EMBO, (EMB.Rotation), (EMB.MirrorFlag));
                X := NewComp.x; Y := NewComp.y;
                Rotation := NewComp.Rotation;

                Report.Add(Padright(IntToStr(EMBI+1),3) + '|' + Padright(IntToStr(RI+1),3) + '|' + PadRight(IntToStr(CI+1),3) + '|' + PadRight(NewComp.SourceDesignator,10) + '|' +
                           PadRight(NewComp.Pattern, 40) + '|' +
                           Padleft(FormatFloat('#0.000#', CoordToMMs_FullPrecision(X - BOrigin.X)),7) + '|' + Padleft(FormatFloat('#0.000#', CoordToMMs_FullPrecision(Y - BOrigin.Y)),7) + '|' +
                           Padleft(FormatFloat('0.0#', Rotation),6) + '|' + Layer2String(NewComp.Layer) );
                Comp := BIterator.NextPCBObject;
            end;
        end;

    CB.BoardIterator_Destroy(BIterator);
    PCBServer.DestroyPCBObject(NewComp);
end;

function PositionPrim(var NewPrim : IPCB_Primitive, CBO : TCoordPoint, RefP : TCoordPoint, const Rotation : double, const Mirror : boolean) : boolean;
var
    Comp   : IPCB_Component;
    Region : IPCB_Region;
    Track  : IPCB_Track;
    Arc    : IPCB_Arc;
    X, Y     : TCoord;
begin
    Result := false;
//   move, mirror, rotate
    case NewPrim.ObjectID of
        eComponentObject :
        begin
            Comp := NewPrim;
            Comp.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);
            if (Mirror) then
        //     Comp.FlipComponent;             // wrong location
        //     Comp.Mirror(EMBO.X, eHMirror);  // wrong layer then wrong rotation
                Comp.FlipXY(RefP.X, eHMirror);

            Comp.RotateAroundXY(RefP.X, RefP.Y, Rotation);
            Rotation := Comp.Rotation;
            if Rotation = 360 then Comp.Rotation := 0;
        end;
        eRegionObject :
        begin
            Region := NewPrim;
       // Region.MoveToXY(EMBO.X, EMBO.Y);   // off target for boards with convex shapes!
            Region.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);
            if (Mirror) then
                Region.Mirror(RefP.X, eHMirror);    // EMB.X   

            Region.RotateAroundXY(RefP.X, RefP.Y, Rotation);
        end;
        eTrackObject :
        begin
            Track := NewPrim;
            Track.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);
            if (Mirror) then
                Track.Mirror(RefP.X, eHMirror);

            X := Track.x1; Y := Track.y1;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x1 := X; Track.y1 := Y;
            X := Track.x2; Y := Track.y2;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x2 := X; Track.y2 := Y;
        end;
        eArcObject :
        begin
            Arc := NewPrim;
            Arc.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);
            if (Mirror) then
                Arc.Mirror(RefP.X, eHMirror);

            X := Arc.XCenter; Y := Arc.YCenter;
            Arc.RotateAroundXY(RefP.X, RefP.Y, Rotation);
        end;
    end;
end;

function DrawPolyRegOutline(PolyRegion : IPCB_Region, CBO : TCoordPoint, RefP : TCoordPoint, Rotation : double, Mirror : boolean, Layer : TLayer, UIndex : integer, var MaxSBR : TCoordRect) : TCoordRect;
var
    PolySeg1 : TPolySegment;
    PolySeg2 : TPolySegment;
    BR       : TCoordRect;
    SegCount : integer;
    I        : Integer;
    X, Y     : TCoord;
    Track    : IPCB_Track;
    Arc      : IPCB_Arc;
    SBR      : TCoordRect;
    IsPoly   : boolean;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    BR := PolyRegion.BoundingRectangle;
    MaxSBR := RectToCoordRect( Rect(kMaxCoord, 0, 0 , kMaxCoord) );   //  Rect(L, T, R, B)
    PolySeg1 := TPolySegment;
    PolySeg2 := TPolySegment;

    IsPoly := false;
    if PolyRegion.ViewableObjectID = eViewableObject_BoardOutline then IsPoly := true;
    if PolyRegion.ViewableObjectID = eViewableObject_Poly         then IsPoly := true;
    if IsPoly  then
        SegCount := PolyRegion.PointCount
    else
        SegCount := PolyRegion.ShapeSegmentCount;

    for I := 0 to (SegCount) do
    begin
        if IsPoly then
        begin
            PolySeg1 := PolyRegion.Segments(I);
            if (I <> SegCount) then
                PolySeg2 := PolyRegion.Segments(I+1)
            else
                PolySeg2 := PolyRegion.Segments(0);
        end else
        begin
            PolySeg1 := PolyRegion.ShapeSegments(I);
            if (I <> SegCount) then
                PolySeg2 := PolyRegion.ShapeSegments(I+1)
            else
                PolySeg2 := PolyRegion.ShapeSegments(0);
        end;

        if PolySeg1.Kind = ePolySegmentLine then
        begin
            Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
            Track.Width := MilsToCoord(cLineWidth);
            Track.Layer := Layer;
            Track.UnionIndex := UIndex;
            Track.x1 := PolySeg1.vx;  // + RefP.X; // - BR.x1;
            Track.y1 := PolySeg1.vy;  // + RefP.Y; // - BR.y1;
            Track.x2 := PolySeg2.vx;  // + RefP.X; // - BR.x1;
            Track.y2 := PolySeg2.vy;
            PositionPrim(Track, CBO, RefP, Rotation, Mirror);

            Board.AddPCBObject(Track);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
            Result.Add(Track);
            SBR := Track.BoundingRectangle;
            MaxSBR := MaxBR(MaxSBR, SBR);
        end;

        if PolySeg1.Kind = ePolySegmentArc then
        begin
            Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
            Arc.Layer := Layer;
            Arc.LineWidth := MilsToCoord(cLineWidth);
            Arc.Radius     := PolySeg1.Radius;
            Arc.UnionIndex := UIndex;      // no point in PcbLib.

            Arc.XCenter    := PolySeg1.cx;   // + RefP.X;  // - BR.x1;
            Arc.YCenter    := PolySeg1.cy;   // + RefP.Y;  // - BR.y1;
            Arc.StartAngle := PolySeg1.Angle1;
            Arc.EndAngle   := PolySeg1.Angle2;
            PositionPrim(Arc, CBO, RefP, Rotation, Mirror);

            Board.AddPCBObject(Arc);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
            Result.Add(Arc);
            SBR := Arc.BoundingRectangle;
            MaxSBR := MaxBR(MaxSBR, SBR);
        end;
    end;
end;

function DrawPrims(KOL : TObjectList, CBO : TCoordPoint, RefP : TCoordPoint, Rotation : double, Mirror : boolean, const Layer : TLayer, NewKind: TRegionKind, UIndex : integer) : TObjectList;
var
    Prim     : IPCB_Primitive;
    I        : Integer;
    X, Y     : TCoord;
    Track    : IPCB_Track;
    Arc      : IPCB_Arc;
    Region   : IPCB_Region;
    Pad      : IPCB_Pad;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    for I := 0 to (KOL.Count - 1) do
    begin
        Prim := KOL.Items(I);

        if Prim.ObjectId = eTrackObject then
        begin
            Track := Prim.Replicate;
            Track.SetState_PasteMaskExpansionMode(eMaskExpansionMode_NoMask);
            Track.SetState_SolderMaskExpansionMode(eMaskExpansionMode_NoMask);
            Track.Layer := Layer;
            Track.UnionIndex := UIndex;
            PositionPrim(Track, CBO, RefP, Rotation, Mirror);
            Board.AddPCBObject(Track);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
            Result.Add(Track);
        end;

        if Prim.ObjectId = eArcObject then
        begin
            Arc := Prim.Replicate;
            Arc.SetState_PasteMaskExpansionMode(eMaskExpansionMode_NoMask);
            Arc.SetState_SolderMaskExpansionMode(eMaskExpansionMode_NoMask);
            Arc.Layer := Layer;
            Arc.UnionIndex := UIndex;      // no point in PcbLib.
            PositionPrim(Arc, CBO, RefP, Rotation, Mirror);
            Board.AddPCBObject(Arc);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
            Result.Add(Arc);
        end;
        if Prim.ObjectId = eRegionObject then
        begin
            Region := Prim.Replicate;
            Region.SetState_PasteMaskExpansionMode(eMaskExpansionMode_NoMask);
            Region.SetState_SolderMaskExpansionMode(eMaskExpansionMode_NoMask);
            Region.Layer := Layer;
// regions can damage board if kind not set before adding!
            if NewKind > -1 then
                Region.SetState_Kind := NewKind;
            Region.UnionIndex := UIndex;
            PositionPrim(Region, CBO, RefP, Rotation, Mirror);

            Board.AddPCBObject(Region);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Region.I_ObjectAddress);
            Result.Add(Region);
        end;
        if Prim.ObjectId = ePadObject then
        begin
            Pad := Prim.Replicate;
            Pad.Moveable := true;
            Pad.SetState_PasteMaskExpansionMode(eMaskExpansionMode_NoMask);
            Pad.SetState_SolderMaskExpansionMode(eMaskExpansionMode_NoMask);

            Pad.Layer := Layer;
            Pad.UnionIndex := UIndex;

            // Region.MoveToXY(EMBO.X, EMBO.Y);   // off target for boards with convex shapes!
            Pad.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);

            if (Mirror) then
                Pad.Mirror(RefP.X, eHMirror);    // EMB.X  

            Pad.RotateAroundXY(RefP.X, RefP.Y, Rotation);

            Board.AddPCBObject(Pad);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Pad.I_ObjectAddress);
            Result.Add(Pad);
        end;
    end;
end;

function AddPrims(EMB : IPCB_EmbeddedBoard, ObjList : TObjectList, const Layer : TLayer, const NewKind : TRegionKind, UIndex : integer) : TObjectList;
var
    CB         : IPCB_Board;
    PLBO       : IPCB_BoardOutline;
    CBBR       : TCoordRect;    // child board bounding rect
    NewObjList : TObjectList;
    EMBO      : TCoordPoint;
    CBO       : TCoordPoint;
    RowCnt    : integer;
    ColCnt    : integer;
    RI, CI    : integer;
    RS, CS    : TCoord;
    RM, CM    : TCoord;
    i         : integer;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    CB     := EMB.ChildBoard;
    PLBO   := CB.BoardOutline;
    CBBR   := PLBO.BoundingRectangle;
//    CBO    := Point(CB.XOrigin, CB.YOrigin);
    CBO    := Point(CBBR.X1, CBBR.Y1);
    CalcEMBIndexes(EMB, RS, CS, RM, CM, RowCnt, ColCnt);

    PCBServer.PreProcess;
    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin
//  origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

            NewObjList := DrawPrims(ObjList, CBO, EMBO, EMB.Rotation, EMB.MirrorFlag, Layer, NewKind, UIndex);
            for i := 0 to (NewObjList.Count - 1) do
                Result.Add( NewObjList.Items(i) );
        end;

    NewObjList.Destroy;
    PCBServer.PostProcess;
end;

function DrawPolyRegOutlines(EMB : IPCB_EmbeddedBoard, POList : TObjectList, Layer : TLayer, UIndex : integer, EIndex : integer) : TObjectList;
var
    CB       : IPCB_Board;
    EMBO     : TCoordPoint;
    CBOL     : IPCB_BoardOutline;
    CBBR     : TCoordRect;
    CBO      : TCoordPoint;
    PolyReg  : IPCBRegion;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    SBR      : TCoordRect;
    MaxSBR   : TCoordRect;
    Text     : IPCB_Text;
    Location : TLocation;
    Layer3   : TLayer;
    I        : integer;
begin
    Result := nil;
    CB   := EMB.ChildBoard;
    CBOL := CB.BoardOutline;
    CBBR := CBOL.BoundingRectangle;
    CBO  := Point(CBBR.X1, CBBR.Y1);

    if POList.Count = 0 then
    begin
        POList.Add(CBOL);
    end;
    CalcEMBIndexes(EMB, RS, CS, RM, CM, RowCnt, ColCnt);

    PCBServer.PreProcess;
    for RI := 0 to (RowCnt - 1) do
    for CI := 0 to (ColCnt - 1) do
    begin
//  origin of each individual piece.
        EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

        SBR  := TCoordRect;
        MaxSBR := RectToCoordRect( Rect(kMaxCoord, 0, 0 , kMaxCoord) );   //  Rect(L, T, R, B)

        for I := 0 to (POList.Count - 1) do
        begin
            PolyReg := POList.Items(I);
            Result := DrawPolyRegOutline(PolyReg, CBO, EMBO, EMB.Rotation, EMB.MirrorFlag, Layer, UIndex, SBR);
            MaxSBR := MaxBR(MaxSBR, SBR);
        end;
//  DrawText
        if EIndex > 0 then
        begin
            Location := Point(MaxSBR.X1 + 100000, MaxSBR.Y1 + 100000);
            Layer3 := LayerUtils.MechanicalLayer(cTextLayer);
            Text := AddText('(' +IntToStr(EIndex)+ ','+IntToStr(RI+1)+ ',' + IntToStr(CI+1) + ')', Location, Layer3, 0);
        end;
    end;
    PCBServer.PostProcess;
end;

function DrawBOLRegions(EMB : IPCB_EmbeddedBoard, Layer : TLayer, RegKind : TRegionKind, const UIndex : integer) : TObjectList;
var
    CB       : IPCB_Board;
    BSRegion : IPCB_Region;
    Region   : IPCB_Region;
    CBOL     : IPCB_BoardOutline;
    CBBR     : TCoordRect;
    EMBO     : TCoordPoint;
    CBO      : TCoordPoint;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    Rotation : Extended;
    Mirror   : boolean;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    CB   := EMB.ChildBoard;
    CBOL := CB.BoardOutline;
    CBBR := CBOL.BoundingRectangle;
    CBO  := Point(CBBR.X1, CBBR.Y1);
    Rotation := EMB.Rotation;
    Mirror   := EMB.MirrorFlag;

    CalcEMBIndexes(EMB, RS, CS, RM, CM, RowCnt, ColCnt);

    BSRegion := MakeRegionFromPolySegList (CBOL, Layer, eRegionObject, RegKind, false);

    PCBServer.PreProcess;
    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin

// origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

            Region := BSRegion.Replicate;
            Board.AddPCBObject(Region);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Region.I_ObjectAddress);
            Region.BeginModify;
//                                    RefP
            PositionPrim(Region, CBO, EMBO, Rotation, Mirror);

            Region.EndModify;
            Region.GraphicallyInvalidate;
            Result.Add(Region);
// text             Location := Point(Region.BoundingRectangle.X1+20000, Region.BoundingRectangle.Y1+20000);    //   - Text.Size;
        end;

    PCBServer.DestroyPCBObject(BSRegion);
    PCBServer.PostProcess;
end;
{..............................................................................}
function DrawBox(EMB : IPCB_EmbeddedBoard, const Layer : TLayer, const UIndex : integer, const Tag : WideString) : boolean;
var
    BR       : TCoordRect;
    Track    : IPCB_Track;
    Text     : IPCB_Text;
    VP1, VP2 : TCoordPoint;
    I        : integer;
    RowCnt   : integer;
    ColCnt   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    Location : TLocation;
    Toggle   : boolean;

begin
    BR := EMB.BoundingRectangle;

    CalcEMBIndexes(EMB, RS, CS, RM, CM, RowCnt, ColCnt);
// undo the rotation mirror stuff as this draws based on bounding rect.
    RS := abs(RS);
    CS := abs(CS);

// rows
    Toggle := false;
    VP1 := Point(BR.x1, BR.Y1);
    VP2 := Point(BR.x2, BR.Y1);
    for I := 0 to (2 * RowCnt - 1) do
    begin
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.Width := MilsToCoord(cLineWidth/4);
        Track.Layer := Layer;
        Track.x1 := VP1.x;
        Track.y1 := VP1.y;
        Track.x2 := VP2.x;
        Track.y2 := VP2.y;
        Track.UnionIndex := UIndex;
        Board.AddPCBObject(Track);

        if Toggle then
            VP1 := Point(BR.x1, VP1.y + RM)
        else
            VP1 := Point(BR.x1, VP1.y + RS - RM);

        VP2 := Point(BR.x2, VP1.y);
        Toggle := Not Toggle;
    end;
// cols
    Toggle := false;
    VP1 := Point(BR.x1, BR.Y1);
    VP2 := Point(BR.x1, BR.Y2);
    for I := 0 to (2 * ColCnt -1 ) do
    begin
//        VP1 := Point(BR.x1 + I * RectWidth(BR)/ColCnt, BR.Y1);
//        VP2 := Point(VP1.x, BR.Y2);
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.Width := MilsToCoord(cLineWidth/4);
        Track.Layer := Layer;
        Track.x1 := VP1.x;
        Track.y1 := VP1.y;
        Track.x2 := VP2.x;
        Track.y2 := VP2.y;
        Track.UnionIndex := UIndex;
        Board.AddPCBObject(Track);

        if Toggle then
            VP1 := Point(VP1.x + CM, BR.y1)
        else
            VP1 := Point(VP1.x + CS - CM, BR.y1);

        VP2 := Point(VP1.x, BR.y2);
        Toggle := Not Toggle;
    end;

    Location := Point(BR.x2, BR.y2);    //   - Text.Size;
    Text := AddText(Tag, Location, Layer, 0);

    Report.Add(PadRight(Tag, 10) + PadRight(CoordUnitToString(BR.X1-BOrigin.X, BUnits),10) + ' '
                                 + PadRight(CoordUnitToString(BR.Y1-Borigin.Y, BUnits),10) + ' '
                                 + PadRight(CoordUnitToString(BR.X2-BOrigin.X, BUnits),10) + ' '
                                 + PadRight(CoordUnitToString(BR.Y2-BOrigin.Y, BUnits),10) );
end;
{..............................................................................}
function MakeRegionFromPolySegList (PLBO : IPCB_BoardOutline, const Layer : TLayer, const RegObjID : integer, const RegKind : TRegionKind, Add : boolean) : IPCB_Region;
var
    PolySeg    : TPolySegment;
    Net        : IPCB_Net;
    I          : integer;
    GPG        : IPCB_GeometricPolygon;
begin
    Net    := nil;

    Result := PCBServer.PCBObjectFactory(RegObjID, eNoDimension, eCreate_Default);
//    GPG := PLBO.BoardOutline_GeometricPolygon;
//    Result.GeometricPolygon := GPG.Replicate;
    Result.ShapeSegmentCount := PLBO.PointCount;

    PolySeg := TPolySegment;
    for I := 0 to (PLBO.PointCount) do
    begin
        PolySeg := PLBO.Segments(I);
        Result.ShapeSegments[I] := PolySeg;
    end;
    Result.UpdateContourFromShape(true);

    Result.SetState_Kind(RegKind);    // eRegionKind_Copper);  eRegionKind_NamedRegion
    Result.Layer := Layer;
    if Net <> Nil then Result.Net := Net;
    if (Add) then
    begin
        Board.AddPCBObject(Result);
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
    end;
    Result.GraphicallyInvalidate;
end;
{..............................................................................}
function ContourToLines(GPCVL  : Pgpc_vertex_list, Layer : TLayer, UIndex : integer) : integer;
var
    I      : Integer;
    P1, P2 : TPoint;
    Track  : IPCB_Track;

begin
    Result := 0;
    PCBServer.PreProcess;
    for I := 0 to (GPCVL.Count - 1) do  // - 0 ???
    begin
        P1 := Point(GPCVL.x(I), GPCVL.y(I) );
        if I = GPCVL.Count then
            P2 := Point(GPCVL.x(0), GPCVL.y(0) )
        else
            P2 := Point(GPCVL.x(I + 1), GPCVL.y(I + 1) );

        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.BeginModify;
        Track.Width := MilsToCoord(cLineWidth);
        Track.Layer := Layer;
        Track.x1 := P1.x;
        Track.y1 := P1.y;
        Track.x2 := P2.x;
        Track.y2 := P2.y;
        Track.UnionIndex := UIndex;      // no point in PcbLib.
        Board.AddPCBObject(Track);
        Track.EndModify;
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
//        if bLock then Track.Moveable := false;
        inc(Result);
    end;
    PCBServer.PostProcess;
end;
{..............................................................................}
function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;
begin
    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);

    Result.XLocation  := Location.X;
    Result.YLocation  := Location.Y;
    Result.Layer      := Layer;
//    Result.IsHidden := false;
    Result.UseTTFonts := false;
    Result.UnderlyingString  := NewText;
    Result.Size       := MilsToCoord(cTextHeight);
    Result.Width      := MilsToCoord(cTextWidth);
    Result.UnionIndex := UIndex;

    Board.AddPCBObject(Result);           // each board is the FP in library
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);

    PCBServer.PostProcess;
end;
{..............................................................................}
function SetPrimsAsKeepouts(PL : TObjectList, Layer : TLayer) : boolean;
var
    Prim          : IPCB_Primitive;
    KORS          : TKeepoutRestrictionsSet;
    I             : integer;
begin
    Result := True;
    PCBServer.PreProcess;
    for I := 0 to (PL.Count - 1) do
    begin
        Prim := PL.Items(I);

        Prim.BeginModify;
        Prim.SetState_IsKeepout(True);
        if Prim.ObjectId = eRegionObject then
            Prim.Kind := eRegionKind_Copper;

        KORS := MkSet(eKeepout_Copper);
        Prim.SetState_KeepoutRestrictions(KORS);
        Prim.Layer := Layer;
        Prim.EndModify;
    end;
    PCBServer.PostProcess;
end;

procedure CalcEMBIndexes(EMB : IPCB_EmbeddedBoard, var RS, var CS, var RM, var CM : TCoord, var RowCnt, var ColCnt : integer);
begin
    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS     := EMB.RowSpacing;
    CS     := EMB.ColSpacing;
    RM := EMB.GetState_RowMargin;
    CM := EMB.GetState_ColMargin;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
        RM := CM;
        CM := EMB.GetState_RowMargin;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;
end;
{..............................................................................}
function ReportOnEmbeddedBoard (EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean;
var
    BR : TCoordRect;
    EB : IPCB_Board;

begin
    BR := EMB.BoundingRectangle;
//    EMB.Index always =0
//    EMD.UniqueId = ''

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    Report.Add('Panel '   + EMB.Board.FileName + '  child: ' + ExtractFileName(EMB.ChildBoard.FileName) + '  BId: ' + IntToStr(EMB.ChildBoard.BoardID));
    Report.Add('Origin (X,Y) : (' + CoordUnitToString(EMB.XLocation - BOrigin.X ,eMM) + ',' + CoordUnitToString(EMB.YLocation - BOrigin.Y ,eMM) + ')' );
    Report.Add('X1    : ' + CoordUnitToString(BR.X1 - BOrigin.X ,eMM) + ' Y1: '  + CoordUnitToString(BR.Y1 - BOrigin.Y, eMM) +
              ' X2    : ' + CoordUnitToString(BR.X2 - BOrigin.X ,eMM) + ' Y2: '  + CoordUnitToString(BR.Y2 - BOrigin.Y, eMM) );
    Report.Add('Layer : ' + IntToStr(EMB.Layer) + '   Rotation: '   + FloatToStr(EMB.Rotation) + '  Mirrored: ' + BoolToStr(EMB.MirrorFlag, true) );
    Report.Add('RowCnt: ' + IntToStr(RowCnt)    + '   ColCnt: '     + IntToStr(ColCnt));
    Report.Add('RowSpc: ' + CoordUnitToString(EMB.RowSpacing, eMM)         + '   ColSpc: ' + CoordUnitToString(EMB.ColSpacing, eMM)+
            '   RowMar: ' + CoordUnitToString(EMB.GetState_RowMargin, eMM) + '   ColMar: ' + CoordUnitToString(EMB.GetState_ColMargin, eMM) );
    EB := EMB.ChildBoard;
    Report.Add(' child comp cnt    : ' + IntToStr(EB.GetPrimitiveCounter.GetObjectCount(eComponentObject)) );
    Report.Add(' child rnd hole cnt: ' + IntToStr(EB.GetPrimitiveCounter.HoleCount(eRoundHole)) );

    Report.Add('');
end;
{..............................................................................}
function AddEmbeddedBoardObj(ABoard : IPCB_Board) : IPCB_Embedded;
begin
    Result := PCBServer.PCBObjectFactory(eEmbeddedBoardObject, eNoDimension, eCreate_Default);
//    Result.Name := 'script added';
    Result.RowCount := 3;
    Result.ColCount := 2;
    Result.ChildBoard.FileName := '';
    ABoard.AddPCBObject(Result);
end;
{..............................................................................}
procedure AddEmbeddedBoard;
var
    ABoard : IPCB_Board;
    EmbeddedBoardList : TObjectList;
begin
    ABoard := PCBServer.GetCurrentPCBBoard;
    If ABoard = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;

    EmbeddedBoardList := GetEmbeddedBoards(ABoard);
    if EmbeddedBoardList.Count < 1 then
    begin
        AddEmbeddedBoardObj(ABoard);
    end
    else
        ShowWarning('document already has embedded boards !  ' + IntToStr(EmbeddedBoardList.Count) );
end;
{...................................................................................................}
function FilterForBoardCutOut(POList : TObjectlist, Layers : IPCB_LayerSet) : TObjectList;
var
    Prim        : IPCB_Primitive;
    I           : integer;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    I := 0;
    if POList = nil then exit;

    for I := 0  to (POList.Count - 1) do
    begin
        Prim := POList.Items(I);
        if Prim.ObjectID = eRegionObject then
        if Prim.ViewableObjectID = eViewableObject_Region then    // avoid board regions!
        if Prim.Kind = eRegionKind_BoardCutout then
            Result.Add(Prim);
    end;
end;
{................................................................................................}
function FilterForMask(POList : TObjectlist, Layers : IPCB_LayerSet) : TObjectList;
var
    Prim        : IPCB_Primitive;
    MaskEnabled : boolean;
    I           : integer;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    I := 0;
    if POList = nil then exit;

    for I := 0  to (POList.Count - 1) do
    begin
        Prim := POList.Items(I);
        MaskEnabled := Prim.GetState_PasteMaskExpansionMode;
        if Prim.Layer = eTopLayer then
        if MaskEnabled <> eMaskExpansionMode_NoMask then
            Result.Add(Prim);
        if Prim.Layer = eTopPaste then
            Result.Add(Prim);
    end;
end;
{..............................................................................}
function MaxBR(SBR, TBR : TCoordRect) : TCoordRect;
begin
    Result := TCoordRect;
    Result.X1 := Min(TBR.X1, SBR.X1);
    Result.X2 := Max(TBR.X2, SBR.X2);
    Result.Y1 := Min(TBR.Y1, SBR.Y1);
    Result.Y2 := Max(TBR.Y2, SBR.Y2);
end;

function GetBoardObjs(Board : IPCB_Board, ObjSet : TSet, LayerSet : IPCB_LayerSet ) : TObjectList;
var
    BIterator : IPCB_BoardIterator;
    Prim      : IPCB_Primitive;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(ObjSet);
    BIterator.AddFilter_IPCB_LayerSet(LayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    Prim := BIterator.FirstPCBObject;
    while (Prim <> Nil) do
    begin
        Result.Add(Prim);
        Prim := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);
end;

function GetChildBoardObjs(EMB : IPCB_EmbeddedBoard, ObjSet : TSet, LayerSet : IPCB_LayerSet ) : TObjectList;
var
    CBoard    : IPCB_Board;
    BIterator : IPCB_BoardIterator;
    Prim      : IPCB_Primitive;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    CBoard := EMB.ChildBoard;

    BIterator := CBoard.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(ObjSet);
    BIterator.AddFilter_IPCB_LayerSet(LayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    Prim := BIterator.FirstPCBObject;
    while (Prim <> Nil) do
    begin
        Result.Add(Prim);
        Prim := BIterator.NextPCBObject;
    end;
    CBoard.BoardIterator_Destroy(BIterator);
end;

function GetChildBoardObjMasks(EMB : IPCB_EmbeddedBoard, ObjSet : TSet, Layer : TLayer) : TObjectList;
var
    CBoard    : IPCB_Board;
    BIterator : IPCB_BoardIterator;
    Prim      : IPCB_Primitive;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    CBoard := EMB.ChildBoard;

    BIterator := CBoard.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(ObjSet);
    BIterator.AddFilter_LayerSet(MkSet(Layer));
    BIterator.AddFilter_Method(eProcessAll);

    Prim := BIterator.FirstPCBObject;
    while (Prim <> Nil) do
    begin
        MaskEnabled := false;
        MaskMode := Prim.GetState_PasteMaskExpansionMode;
        if (MaskMode <> eMaskExpansionMode_NoMask) then MaskEnabled := true;

        if MaskEnabled and ((Prim.Layer = eTopLayer) or (Prim.Layer = eBottomLayer)) then
        begin
            if Prim.ObjectId = eRegionObject then
            begin
                if (Prim.Kind = eRegionKind_Copper) then
                    Result.Add(Prim);
            end
            else Result.Add(Prim);
        end;
        if ((Prim.Layer = eTopPaste) or (Prim.Layer = eBottomPaste)) then
            Result.Add(Prim);

        Prim := BIterator.NextPCBObject;
    end;
    CBoard.BoardIterator_Destroy(BIterator);
end;

function CollapseEmbeddedBoard (EMB : IPCB_EmbeddedBoard) : boolean;
begin
    EMB.Setstate_RowCount(1);
    EMB.Setstate_ColCount(1);
    EMB.GraphicallyInvalidate;
end;

function RestoreEmbeddedBoard (EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean;
begin
    EMB.Setstate_RowCount(RowCnt);
    EMB.Setstate_ColCount(ColCnt);
    EMB.GraphicallyInvalidate;
end;

function GetEmbeddedBoards(ABoard : IPCB_Board) : TObjectList;
Var
    EmbedObj   : IPCB_EmbeddedBoard;
    BIterator  : IPCB_BoardIterator;
    BLayerSet  : IPCB_LayerSet;
    Primitive  : IPCB_Primitive;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;      // critical!

    BLayerSet := LayerSetUtils.CreateLayerSet.IncludeAllLayers;
    BIterator := ABoard.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eEmbeddedBoardObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    EmbedObj := BIterator.FirstPCBObject;
    while (EmbedObj <> Nil) do
    begin
        Result.Add(EmbedObj);
        EmbedObj := BIterator.NextPCBObject;
    end;
    ABoard.BoardIterator_Destroy(BIterator);
end;

function TestVersion(const dummy : integer) : Integer;
begin
    Result := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if (Result >= AD19VersionMajor) then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;
end;

                                                        // cardinal      V7 LayerID
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) : IPCB_MechanicalLayer;
begin
    if LegacyMLS then
    begin
        MLID := LayerUtils.MechanicalLayer(i);
        Result := LS.LayerObject_V7(MLID)
    end else
    begin
        Result := LS.GetMechanicalLayer(i);
        MLID := Result.V7_LayerID.ID;       // .LayerID returns zero for dielectric
    end;
end;

function GetMechLayerByKind(LS : IPCB_MasterLayerStack, MLK : TMechanicalLayerKind) : TLayer;
var
    CB            : IPCB_Board;
    LayerStack    : IPCB_MasterLayerStack;
    MechLayer     : IPCB_MechanicalLayer;
    i, ML1        : integer;

begin
    Result := 0;
//    CB  := EMB.ChildBoard;
//    LayerStack := CB.MasterLayerStack;

    if not LegacyMLS then
    for i := 1 To MaxMechLayers do
    begin
        MechLayer := GetMechLayerObject(LS, i, ML1);
        if MechLayer.Kind = MLK then
            Result := ML1;
        if Result <> 0 then break;
    end;
end;

function MakeRegion(GPC : IPCB_GeometricPolygon, Net : IPCB_Net, const Layer : TLayer, const UIndex : integer, const MainContour : boolean) : IPCB_Region;
var
    GPCVL  : Pgpc_vertex_list;
    MC : integer;
    J  : integer;
begin
    Result := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    Result.BeginModify;

    MC := GetMainContour(GPC);
    GPC.IsHole(0);
    Result.SetOutlineContour( GPC.Contour(MC) );   // GPC.Contour(0))

    if not MainContour then
    begin
        for J := 0 To (GPC.Count - 1) Do
            if J <> MC then
                Result.GeometricPolygon.AddContourIsHole(GPC.Contour[J], True);
    end;

//    Result.SetState_Kind(eRegionKind_Copper);
    Result.Layer := Layer;
    Result.Net   := Net;
    Result.UnionIndex := UIndex;

    Result.EndModify;

//    Result.Selected := true;
//    Report.Add('Added New Region on Layer ' + Layer2String(Result.Layer) + ' kind : ' + IntToStr(Result.Kind) + '  area ' + SqrCoordToUnitString(Result.Area , eMM, 6) ); // + '  net : ' + Result.Net.Name);
end;

function GetMainContour(GPC : IPCB_GeometricPolygon) : Integer;
var
    CArea, MArea : double;
    I            : integer;
begin
    Result := 0;
    MArea := 0;
    for I := 0 to (GPC.Count - 1) do
    begin
        CArea := GPC.Contour(I).Area;
        if CArea > MArea then
        begin
            MArea := CArea;
            Result := I;
        end;
    end;
end;

function MakeShapeContours(MaskObjList : TObjectList, Operation : TSetOperation, Layer : TLayer, Expansion : TCoord) : TInterfaceList;
var
    GMPC1         : IPCB_GeometricPolygon;
    GMPC2         : IPCB_GeometricPolygon;
    CPOL          : TInterfaceList;
    RegionVL      : Pgpc_vertex_list;
    GIterator     : IPCB_GroupIterator;
    Primitive     : IPCB_Primitive;
    PHPrim        : IPCB_Primitive;
    Region        : IPCB_Region;
    Fill          : IPCB_Fill;
    CompBody      : IPCB_ComponentBody;
    Polygon       : IPCB_Polygon;
//    Net           : IPCB_Net;
    Track         : IPCB_Track;
    Pad           : IPCB_Pad;
    Via           : IPCB_Via;
    Text          : IPCB_Text3;
    I, J, K       : integer;
    SPLoopRemoval : boolean;
    TextLinesList  : TObjectList;
    bTouch : boolean;

begin
    Result := CreateInterfaceList;
// InterfaceList needed for batch contour fn
    CPOL := CreateInterfaceList;
    GMPC1 := PcbServer.PCBGeometricPolygonFactory;
    GMPC2 := PcbServer.PCBGeometricPolygonFactory;

    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcResolution));
    PCBServer.PCBContourMaker.ArcResolution;

    for I := 0 to (MaskObjList.Count - 1) Do
    begin
        Primitive := MaskObjList.Items(I);
        if Primitive <> Nil then
        begin
            case Primitive.ObjectID of
                eComponentBodyObject :
                begin
                    CompBody := Primitive;
                    if Expansion <> 0 then
                        GMPC1 := PcbServer.PCBContourMaker.MakeContour(CompBody, Expansion, Layer)  //GPG
                    else
                        GMPC1 := CompBody.GeometricPolygon;
                    Result.Add(GMPC1);
                end;
                eTrackObject, eArcObject :
                begin
                    Track := Primitive;
                    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Track, Expansion, Layer);  //GPG
                    Result.Add(GMPC1);
                end;
                ePadObject :
                begin
                    Pad := Primitive;
                    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Pad, Expansion, Layer);
                    Result.Add(GMPC1);
                end;
                eViaObject :
                begin
                    Via := Primitive;
                    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Via, Expansion, Layer);
                    Result.Add(GMPC1);
                end;
                eRegionObject :
                begin
                    Region := Primitive;
//                    if (Region.Kind = eRegionKind_Copper) and not (Region.InPolygon or Region.IsKeepout ) then  //  and Region.InComponent
                    if not (Region.InPolygon or Region.IsKeepout ) then  //  and Region.InComponent
                    begin
                        GMPC1 := PcbServer.PCBContourMaker.MakeContour(Region, Expansion, Layer);
                        Result.Add(GMPC1);
                    end;
                end;
                ePolyObject :
                begin
                    Polygon := Primitive;
                    GIterator := Polygon.GroupIterator_Create;
                    if (Polygon.PolyHatchStyle = ePolySolid) and (Polygon.InBoard ) then  //  and Region.InComponent
                    begin
                        Region    := GIterator.FirstPCBObject;
                        while Region <> nil do
                        begin
                            GMPC1 := PcbServer.PCBContourMaker.MakeContour(Region, Expansion, Layer);
                            Result.Add(GMPC1);
                            Region := GIterator.NextPCBObject;
                        end;
                    end;
                    if (Polygon.PolyHatchStyle <> ePolyNoHatch) and (Polygon.PolyHatchStyle <> ePolySolid) and (Polygon.InBoard ) then  //  and Region.InComponent
                    begin
                        PHPrim     := GIterator.FirstPCBObject;
                        while PHPrim <> nil do    // track or arc
                        begin
                            if (PHPrim.ObjectId = eTrackObject) or (PHPrim.ObjectId = eArcObject) then
                            begin
                                GMPC1 := PcbServer.PCBContourMaker.MakeContour(PHPrim, Expansion, Polygon.Layer);  //GPG
                                Result.Add(GMPC1);
                                // SplitAddConnectedGeoPoly(GMPC1, Result);
//                                CPOL.Add(GMPC1);                                  // works 1
                            end;
                            PHPrim := GIterator.NextPCBObject;
                        end;
//                works & makes one GEOPoly with multi contours.
//                        PCBServer.PCBContourUtilities.UnionBatchSet(CPOL, GMPC2);  // works 1
//                        Result.Add(GMPC2);                                         // works 1
                    end;
                    Polygon.GroupIterator_Destroy(GIterator);
                end;
                eFillObject :
                begin
                    Fill := Primitive;
                    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Fill, Expansion, Layer);
                    Result.Add(GMPC1);
                end;
                eTextObject :
                begin
                    Text := Primitive;
                    Text.PolygonOutline;

                    if Text.TextKind = eText_TrueTypeFont then
                    begin
                        GMPC1 := Text.TTTextOutlineGeometricPolygon;
                        Region := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
                        Region.GeometricPolygon := GMPC1;
//        Region.SetOutlineContour(GPC.Contour(0));      // only the outside shape.
                        Region.SetState_Kind(eRegionKind_Copper);
                        Region.Layer := Layer;
                        GMPC1 := PcbServer.PCBContourMaker.MakeContour(Region, Expansion, Layer);

//   need separate each char into a separate GeoPoly.
                        PCBserver.PCBContourUtilities.SplitIntoConnectedPolygons(GMPC1, CPOL);
                        for J := 0 to (CPOL.Count - 1) do
                            Result.Add( CPOL.Items[J] );
                        CPOL.Clear;
                    end;{ else
                    begin
                        SPLoopRemoval := PCBServer.SystemOptions.LoopRemoval;
                        PCBServer.SystemOptions.LoopRemoval := false;
                        TextLinesList := ReplaceTextWithLines(Text);
                        for J := 0 to (TextLinesList.Count - 1) do
                        begin
                            Primitive := TextLinesList.Items(J);
                            GMPC1 := PcbServer.PCBContourMaker.MakeContour(Primitive, Expansion, Layer);
                            Result.Add(GMPC1);
                        end;
                        PCBServer.SystemOptions.LoopRemoval := SPLoopRemoval;
                    end; }


                end;
            end; // case

            Report.Add(PadRight(IntToStr(I), 3) + Primitive.ObjectIDString + ' ' + Primitive.Detail);
        end;
    end;  // for I

//  unless contours touch .. the batch set/contour returns zero!
//  test, combine & replace or insert at beginning of list (delete merged) , rinse-repeat.

    Report.Add(' Shape GeoPoly Union ');
    if (Result.Count > 0) then
    begin
        If Operation = eSetOperation_Union then
        begin
            repeat
                bTouch := false;
            I := 0;
            while I < (Result.Count - 1) do
            begin
                GMPC1 := Result.Items(I);
                CPOL.Clear;
                CPOL.Add(GMPC1);

                J := I + 1;
                while J < (Result.Count) do
                begin
                    GMPC2 := Result.Items(J);
                    if PcbServer.PCBContourUtilities.GeometricPolygonsTouch(GMPC1, GMPC2) then
                    begin
//                        PCBserver.PCBContourUtilities.SplitIntoConnectedPolygons(GMPC2, CPOL);
                        CPOL.Add(GMPC2);
                        Result.Delete(J);
                        bTouch := true;
                    end else
                        inc(J);
                end;

                if CPOL.Count > 1 then
                begin
                    PCBServer.PCBContourUtilities.UnionBatchSet(CPOL, GMPC1);
                    Result.Items(I) := GMPC1;
                end else
// if [I] has not changed then increment
                    inc(I);
            end;
            until (I + 1 = Result.Count) and (J = Result.Count) and not bTouch;
        end else
        begin
 //           UnionGP := GPOL.Items(0);
            I := 0; J := 1;
            while I < (Result.Count - 1) and (I < J) do // (J < Result.Count) do
            begin
                GMPC1 := Result.Items(I);
                GMPC2 := Result.Items(J);

                if GMPC1.IsHole(0) then
                begin
                    Inc(I);
                    continue;
                end;

                if PcbServer.PCBContourUtilities.GeometricPolygonsTouch(GMPC1, GMPC2) then
                begin
                    PcbServer.PCBContourUtilities.ClipSetSet (Operation, GMPC1, GMPC2, GMPC1);

                    Report.Add('    touch : ' + IntToStr(I) + '.' + IntToStr(J) + ' ' + IntTostr(GMPC1.Count) + ' ' + IntTostr(GMPC1.Contour(0).Count) + '  ' + IntToStr(GMPC1.IsHole(0)) );
                    Result.Items(I) := GMPC1;
                    Result.Delete(J);          // inserting & deleting changes index of all object above
                    I := 0;                   // start again from beginning
                    J := 1;
                end else
                begin
                    Report.Add(' no touch : ' + IntToStr(I) + '.' + IntToStr(J) );
                    Inc(J);
                    if J >= (Result.Count) then
                    begin
                        inc(I);
                        J := I + 1;
                    end;
                end;

            end;
        end;
    end;
    CPOL.Clear;
end;


