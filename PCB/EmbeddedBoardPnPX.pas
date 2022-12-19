{ EmbeddedBoardPnPX.pas

  report Embedded Boards
  generate PnP (built-in report) for single Row & single column of all embedded board objects.
  add outlines & region shape from child brd shapes
  add keepouts to EMB board from child brds
  generate a full Placement file with EMB & row & column indexes.
  support defined RouteToolPath layer per child board tho all should match, may change with layerkinds etc!

  Author BL Miller
20220503  0.1  POC adapted from EmbeddedObjects.pas.
20220505  0.11 add EMB bounding rect on mechlayer
20220506  0.12 draw column & row margins & spacing lines.
20220514  0.13 add region & polyline outline of each item in EMB.
20220520  0.14 add KOs from specified objects/layers, adds KO region from board shape.
20220421  0.15 add Placement file report with EMB & row & column indices
20220606  0.16 region location error if board shape was convex: use bounding box calc. move.
20220701  0.17 separate text from regionshape fn & layer.
20221028  0.18 use RouteToolpath & MechLayerKind
20221217  0.19 later AD 21-22 does not like to pass EMB.ChildBoard object.


Child board-outline bounding rect is used to align to EMB origin
AD17 Outjob placement file for any mirrored EMB is wrong!

}
const
// mechanical layers
   cOutlineLayer  = 21;    // destination outlines
   cRegShapeLayer = 23;    // destination region shapes
   cTextLayer     = 22;    // destination text labels
// make keepouts source layer
   cMLKRouteToolPath = 28;    // for old vers that do not have builtin const for layerkind 'Route Tool Path'
   cRouteNPLayer     = 11;    // fall-back source NTP routing profile if no Kind found

   cTextHeight = 5;
   cTextWidth  = 0.5;
   cLineWidth  = 1;

 // tbd - parse these options instead of hard coded..
   cKeepouts    = 'M11=AT|M1=BO';  // create KO layer objs from layer=obj  [A,T,BO,R]
   cBrdCutouts  = 'M11=AT';
   cPolyCutouts = 'M11=AT';

// version
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;       // scripting API has broken consts from TV6_Layer; 256 layers possible?
    AD19MaxMechLayers = 1024;


var
    Board         : IPCB_Board;
    Borigin       : TPoint;
    BUnits        : TUnit;
    Report        : TStringList;
    FileName      : WideString;
    VerMajor      : WideString;
    MaxMechLayers : integer;
    LegacyMLS     : boolean;

function DrawBox(EMB : IPCB_EmbeddedBoard, const Layer : TLayer, const UIndex : integer, const Tag : WideString) : boolean;    forward;
function DrawOutlines(EMB : IPCB_EmbeddedBoard, const Layer : TLayer, UIndex : integer, EIndex : integer) : TCoordRect;        forward;
function DrawBORegions(EMB : IPCB_EmbeddedBoard, Layer : TLayer, RegKind : TRegionKind, const UIndex : integer) : TObjectList; forward;
function ReportOnEmbeddedBoard (EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean;               forward;
function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;                    forward;
function AddKeepouts(EMB : IPCB_EmbeddedBoard, KOList : TObjectList, const Layer : TLayer, UIndex : integer) : boolean;        forward;
function SetPrimsAsKeepouts(PL : TObjectList, const Layer : TLayer) : boolean;                                                 forward;
function MakeRegionFromPolySegList (PLBO : IPCB_BoardOutline, const Layer : TLayer, const RegKind : TRegionKind, Add : boolean) : IPCB_Region; forward;
function MaxBR(SBR : TCoordRect, TBR : TCoordRect) : TCoordRect;                      forward;
function GetChildBoardObjs(EMB : IPCB_EmbeddedBoard, ObjSet : TSet, LayerSet : IPCB_LayerSet ) : TObjectList; forward;
function CollapseEmbeddedBoard (EMB : IPCB_EmbeddedBoard) : boolean;                  forward;
function RestoreEmbeddedBoard (EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean;       forward;
function GetEmbeddedBoards(ABoard : IPCB_Board) : TObjectList;                        forward;
function Version(const dummy : boolean) : TStringList;                                forward;
function GetMechLayer(EMB : IPCB_EmbeddedBoard, MLK : TMechanicalLayerKind) : TLayer; forward;


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

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS := EMB.RowSpacing;
    CS := EMB.ColSpacing;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;

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

                NewComp.MoveByXY(EMBO.X - CBO.X, EMBO.Y - CBO.Y);

                if (EMB.MirrorFlag) then
                begin
             //     NewComp.FlipComponent;             // wrong location
             //     NewComp.Mirror(EMBO.X, eHMirror);  // wrong layer then wrong rotation
                    NewComp.FlipXY(EMBO.X, eHMirror);
                end;

                NewComp.RotateAroundXY(EMBO.X, EMBO.Y, EMB.Rotation);

                X := NewComp.x; Y := Newcomp.y;
                Rotation := NewComp.Rotation;
                if Rotation = 360 then rotation := 0;

                Report.Add(Padright(IntToStr(EMBI+1),3) + '|' + Padright(IntToStr(RI+1),3) + '|' + PadRight(IntToStr(CI+1),3) + '|' + PadRight(NewComp.SourceDesignator,10) + '|' +
                           PadRight(NewComp.Pattern,40) + '|' +
                           Padleft(FormatFloat('#0.000#', CoordToMMs(X - BOrigin.X)),7) + '|' + Padleft(FormatFloat('#0.000#', CoordToMMs(Y - BOrigin.Y)),7) + '|' +
                           Padleft(FormatFloat('0.0#',Rotation),6) + '|' + Layer2String(NewComp.Layer) );
                Comp := BIterator.NextPCBObject;
            end;
        end;

    CB.BoardIterator_Destroy(BIterator);
    PCBServer.DestroyPCBObject(NewComp);
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
                            Padleft(FormatFloat('#0.000#', CoordToMMs(Comp.X - BOrigin.X)),7) + '|' +  Padleft(FormatFloat('#0.000#', CoordToMMs(Comp.Y - BOrigin.Y)),7) + '|' +
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

procedure AddKeepOutsToEmbdBrdObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    CB                : IPCB_Board;
    KORegList         : TObjectList;
    RegKind           : TRegionKind;
    KOText            : TStringList;
    KOList            : TObjectList;
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

    VerMajor := Version(true).Strings(0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if (StrToInt(VerMajor) >= AD19VersionMajor) then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    Report := TStringList.Create;

    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        CB  := EMB.ChildBoard;
        Layer := CB.RouteToolPathLayer;

        if Layer = 0 then
            Layer := GetMechLayer(EMB, cMLKRouteToolPath);
        if Layer = 0 then
            Layer := LayerUtils.MechanicalLayer(cRouteNPLayer);

        Layers := LayerSetUtils.EmptySet;
        Layers.Include(Layer);
        OSet   := MkSet(eTrackObject, eArcObject);

        KOList := GetChildBoardObjs(EMB, OSet, Layers);

        Layer   := eKeepOutLayer;
        RegKind := eRegionKind_Copper;
        AddKeepOuts(EMB, KOList, Layer, 0);
        KORegList := DrawBORegions(EMB, Layer, RegKind, 0);
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

procedure AddOutlinesToEmbdBrdObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    RegKind           : TRegionKind;
    Layer             : ILayer;
    Layer2            : ILayer;
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

    Layer  := LayerUtils.MechanicalLayer(cOutlineLayer);
    Layer2 := LayerUtils.MechanicalLayer(cRegShapeLayer);
    EmbeddedBoardList := GetEmbeddedBoards(Board);

    RegKind := eRegionKind_Copper;

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);

        DrawBox(EMB, Layer, 0, 'array');
        DrawOutlines(EMB, Layer, 0, (I+1) );
        DrawBORegions(EMB, Layer2, RegKind, 0);

        ReportOnEmbeddedBoard(EMB, RC, CC);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);

    Board.ViewManager_FullUpdate;
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    Report.Add(' Panel pads      : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\AddEmbeddedBrdObj.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

function DrawOutline(PLBO : IPCB_BoardOutline, RefP : TCoordPoint, Rotation : double, Mirror : boolean, Layer : TLayer, UIndex : integer) : TCoordRect;
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

begin
    Result := RectToCoordRect( Rect(kMaxCoord, 0, 0 , kMaxCoord) );   //  Rect(L, T, R, B)

    BR := PLBO.BoundingRectangle;
    PolySeg1 := TPolySegment;
    PolySeg2 := TPolySegment;

    SegCount := PLBO.PointCount;

    for I := 0 to (SegCount) do
    begin
        PolySeg1 := PLBO.Segments(I);
        if (I <> SegCount) then
            PolySeg2 := PLBO.Segments(I+1)
        else
            PolySeg2 := PLBO.Segments(0);

        if PolySeg1.Kind = ePolySegmentLine then
        begin
            Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
            Track.Width := MilsToCoord(cLineWidth);
            Track.Layer := Layer;
            Track.x1 := PolySeg1.vx + RefP.X - BR.x1;
            Track.y1 := PolySeg1.vy + RefP.Y - BR.y1;
            Track.x2 := PolySeg2.vx + RefP.X - BR.x1;
            Track.y2 := PolySeg2.vy + RefP.Y - BR.y1;
//            Track.MoveByXY(PolySeg1.vx - BR.x1, PolySeg1.vy - BR.y1);
            Track.UnionIndex := UIndex;

        // move, mirror, rotate
            if (Mirror) then
                Track.Mirror(RefP.X, eHMirror);

            X := Track.x1; Y := Track.y1;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x1 := X; Track.y1 := Y;
            X := Track.x2; Y := Track.y2;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x2 := X; Track.y2 := Y;
            Board.AddPCBObject(Track);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
            SBR := Track.BoundingRectangle;
            Result := MaxBR(Result, SBR);
        end;

        if PolySeg1.Kind = ePolySegmentArc then
        begin
            Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
            Arc.Layer := Layer;
            Arc.LineWidth := MilsToCoord(cLineWidth);
            Arc.Radius     := PolySeg1.Radius;

            Arc.XCenter    := PolySeg1.cx + RefP.X - BR.x1;
            Arc.YCenter    := PolySeg1.cy + RefP.Y - BR.y1;
            Arc.StartAngle := PolySeg1.Angle1;
            Arc.EndAngle   := PolySeg1.Angle2;
            Arc.UnionIndex := UIndex;      // no point in PcbLib.

            if (Mirror) then
                Arc.Mirror(RefP.X, eHMirror);

            X := Arc.XCenter; Y := Arc.YCenter;
            Arc.RotateAroundXY(RefP.X, RefP.Y, Rotation);

            Board.AddPCBObject(Arc);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
            SBR := Arc.BoundingRectangle;
            Result := MaxBR(Result, SBR);
        end;
    end;
end;

function DrawKeepout(KOL : TObjectList, CBO : TCoordPoint, RefP : TCoordPoint, Rotation : double, Mirror : boolean, const Layer : TLayer, UIndex : integer) : TObjectList;
var
    Prim     : IPCB_Primitive;
    I        : Integer;
    X, Y     : TCoord;
    Track    : IPCB_Track;
    Arc      : IPCB_Arc;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    for I := 0 to (KOL.Count - 1) do
    begin
        Prim := KOL.Items(I);

        if Prim.ObjectId = eTrackObject then
        begin
            Track := Prim.Replicate;
            Track.Layer := Layer;
    //   move, mirror, rotate
            Track.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);
            Track.UnionIndex := UIndex;

            if (Mirror) then
                Track.Mirror(RefP.X, eHMirror);

            X := Track.x1; Y := Track.y1;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x1 := X; Track.y1 := Y;
            X := Track.x2; Y := Track.y2;
            RotateCoordsAroundXY(X, Y, RefP.X, RefP.Y, Rotation);
            Track.x2 := X; Track.y2 := Y;
            Board.AddPCBObject(Track);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
            Result.Add(Track);
        end;

        if Prim.ObjectId = eArcObject then
        begin
            Arc := Prim.Replicate;
            Arc.Layer := Layer;

            Arc.MoveByXY(RefP.X - CBO.X, RefP.Y - CBO.Y);

            Arc.UnionIndex := UIndex;      // no point in PcbLib.

            if (Mirror) then
                Arc.Mirror(RefP.X, eHMirror);

            X := Arc.XCenter; Y := Arc.YCenter;
            Arc.RotateAroundXY(RefP.X, RefP.Y, Rotation);

            Board.AddPCBObject(Arc);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
            Result.Add(Arc);
        end;
    end;
end;

function AddKeepouts(EMB : IPCB_EmbeddedBoard, KOList : TObjectList, const Layer : TLayer, UIndex : integer) : boolean;
var
    CB        : IPCB_Board;
    PLBO      : IPCB_BoardOutline;
    CBBR      :  TCoordRect;    // child board bounding rect
    NewKOList : TObjectList;
    EMBO      : TCoordPoint;
    CBO       : TCoordPoint;
    RowCnt    : integer;
    ColCnt    : integer;
    RI, CI    : integer;
    RS, CS    : TCoord;
    RM, CM    : TCoord;

begin
    CB   := EMB.ChildBoard;
    PLBO := CB.BoardOutline;
    CBBR := PLBO.BoundingRectangle;
//    CBO  := Point(CB.XOrigin, CB.YOrigin);
    CBO  := Point(CBBR.X1, CBBR.Y1);
    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS     := EMB.RowSpacing;
    CS     := EMB.ColSpacing;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;

    PCBServer.PreProcess;
    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin
//  origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

            NewKOList := DrawKeepout(KOList, CBO, EMBO, EMB.Rotation, EMB.MirrorFlag, Layer, UIndex);
            SetPrimsAsKeepouts(NewKOList, Layer);
        end;

    PCBServer.PostProcess;
end;

function DrawOutlines(EMB : IPCB_EmbeddedBoard, Layer : TLayer, UIndex : integer, EIndex : integer) : boolean;
var
    CB       : IPCB_Board;
    PLBO     : IPCB_BoardOutline;
    BOBR     : TCoordRect;
    EMBO     : TCoordPoint;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    SBR      : TCoordRect;
    Text     : IPCB_Text;
    Location : TLocation;
    Layer3   : TLayer;

begin
    CB   := EMB.ChildBoard;
    PLBO := CB.BoardOutline;
    BOBR := PLBO.BoundingRectangle;

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS := EMB.RowSpacing;
    CS := EMB.ColSpacing;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;

    PCBServer.PreProcess;
    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin

// origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);
            SBR  := DrawOutline(PLBO, EMBO, EMB.Rotation, EMB.MirrorFlag, Layer, UIndex);

//          DrawText
            if EIndex > 0 then
            begin
                Location := Point(SBR.X1 + 100000, SBR.Y1 + 100000);
                Layer3 := LayerUtils.MechanicalLayer(cTextLayer);
                Text := AddText('(' +IntToStr(EIndex)+ ','+IntToStr(CI+1)+ ',' + IntToStr(RI+1) + ')', Location, Layer3, 0);
            end;

        end;

    PCBServer.PostProcess;
end;

function DrawBORegions(EMB : IPCB_EmbeddedBoard, Layer : TLayer, RegKind : TRegionKind, const UIndex : integer) : TObjectList;
var
    CB       : IPCB_Board;
    BSRegion : IPCB_Region;
    Region   : IPCB_Region;
    PLBO     : IPCB_BoardOutline;
    BOBR     : TCoordRect;
    EMBO     : TCoordPoint;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    CB   := EMB.ChildBoard;
    PLBO := CB.BoardOutline;
    BOBR := PLBO.BoundingRectangle;

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS := EMB.RowSpacing;
    CS := EMB.ColSpacing;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;

    BSRegion := MakeRegionFromPolySegList (PLBO, Layer, RegKind, false);

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

            // Region.MoveToXY(EMBO.X, EMBO.Y);   // off target for boards with convex shapes!
            Region.MoveByXY(EMBO.X - BOBR.X1, EMBO.Y - BOBR.Y1);

            if (EMB.MirrorFlag) then
                Region.Mirror(EMBO.X, eHMirror);    // EMB.X   BOBR.X1

            Region.RotateAroundXY(EMBO.X, EMBO.Y, EMB.Rotation);
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
    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS := EMB.RowSpacing;
    CS := EMB.ColSpacing;
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
function MakeRegionFromPolySegList (PLBO : IPCB_BoardOutline, const Layer : TLayer, const RegKind : TRegionKind, Add : boolean) : IPCB_Region;
var
    PolySeg    : TPolySegment;
    Net        : IPCB_Net;
    I          : integer;
    GPG        : IPCB_GeometricPolygon;
begin
    Net    := nil;

    Result := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
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
        PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
        Track.Width := MilsToCoord(cLineWidth);
        Track.Layer := Layer;
        Track.x1 := P1.x;
        Track.y1 := P1.y;
        Track.x2 := P2.x;
        Track.y2 := P2.y;
        Track.UnionIndex := UIndex;      // no point in PcbLib.
        Board.AddPCBObject(Track);
        PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
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
    Report.Add('Layer : ' + IntToStr(EMB.Layer) + '   Rotation: '   + FloatToStr(EMB.Rotation));
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
{..............................................................................}
function MaxBR(SBR, TBR : TCoordRect) : TCoordRect;
begin
    Result := TCoordRect;
    Result.X1 := Min(TBR.X1, SBR.X1);
    Result.X2 := Max(TBR.X2, SBR.X2);
    Result.Y1 := Min(TBR.Y1, SBR.Y1);
    Result.Y2 := Max(TBR.Y2, SBR.Y2);
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

function Version(const dummy : boolean) : TStringList;
begin
    Result               := TStringList.Create;
    Result.Delimiter     := '.';
    Result.DelimitedText := Client.GetProductVersion;
end;

function GetMechLayer(EMB : IPCB_EmbeddedBoard, MLK : TMechanicalLayerKind) : TLayer;
var
    CB            : IPCB_Board;
    LayerStack    : IPCB_LayerStack_V7;
    MechLayer     : IPCB_MechanicalLayer;
    i, ML1        : integer;

begin
    Result := 0;
    CB  := EMB.ChildBoard;
    LayerStack := CB.LayerStack_V7;

    if not LegacyMLS then
    for i := 1 To MaxMechLayers do
    begin
        ML1 := LayerUtils.MechanicalLayer(i);
        MechLayer := LayerStack.LayerObject_V7[ML1];
        if MechLayer.Kind = MLK then
            Result := ML1;
    end;
end;
