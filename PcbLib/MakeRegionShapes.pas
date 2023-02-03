{ MakeRegionShapes.pas
  Create Region shapes with polyline regionshape interface.

  PcbLib (PcbDoc partially)

MakeRegionDonuts()
   annular rings for unplated pads (use for copper pullback from hole).
   Operates on Selected pad or via or selected PcbDoc component's pin 1

MakeArcDonuts()

ExtrudeRegion()
  supports regionshape and most likely contoured regions.

BL Miller
20221013  0.10 POC tricky to get arc segments to behave.
20221015  0.11 add extruded body fn.
20221016  0.12 support creating Donut shapes in PcbDoc components
20221020  0.13 check Outer R > Inner R;  Add Arc(track) donut method
20221102  0.14 syntax err in region size limits test.

TBD:
  enable soldermask & keepout


   RotateCoordsAroundXY (X, Y, Centre.X, Centre.Y, theta);
   Region.RotateAroundXY(X, Y, EMB.Rotation);
   Region.MoveToXY(Centre.X, Centre.Y);
}

const
    Sectors      = 4;     // 1 to eSections for a full circle
    eSections    = 4;     // divided sections of full circle 4 == 90deg
    eOuterRadius = 15.5;   // mils
    eInnerRadius = 14.5;   // mils

    iMechLayer           = 13;   // Mechanical Layer 13 == 13  used for Comp Body if current layer <> type mech-layer
//    OutlineExpansion     = 0.0;  // 0 mils from edge.
    ArcResolution        = 0.02; // mils : impacts number of edges for contouring etc..

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;
    IsLib     : boolean;

function AddExtrudedBody2(Region : IPCB_Region, const GMPC : IPCB_GeometricPolygon, const Layer : TLayer, const UIndex : integer, const MainContour : boolean) : IPCB_ComponentBody; forward;
function MakeDonutRegion(Centre : TCoordPoint, OutR, InR : extended, Layer : TLayer, const RegKind : TRegionKind) : TPCB_Region; forward;
function MakeDonutArc(Centre : TCoordPoint, OutR, InR : extended, Layer : TLayer) : TObjectList; forward;

// called from Wrap-FPFix-Donuts.PrjScr
procedure MakeRegionDonutEX(Board : IPCB_Board, APad : IPCB_Pad);
var
    Iterator   : IPCB_GroupIterator;
    NewRegion  : IPCB_Region;
    Centre     : TCoordPoint;
    BWOrigin   : TCoordPoint;
    Layer      : TLayer;
    OutR, InR  : extended;
    CompFP     : IPCB_LibComponent;
    FPName     : WideString;
    APrim      : IPCB_Primitive;
    I          : integer;
    PrimList   : TObjectList;

begin
   IsLib := true;

    Layer  := Board.CurrentLayer;
    OutR   := eOuterRadius;
    InR    := eInnerRadius;

    if APad <> nil then
    begin

        Centre := Point(APad.X, APad.Y);

        InR  := CoordToMils(APad.HoleSize/2) + 2;
        OutR := CoordToMils(APad.TopXSize/2);
        if APad.BotXSize > APad.TopXSize then
            OutR := CoordToMils(APad.BotXSize/2);

        PCBServer.PreProcess;
        NewRegion := nil;
        if OutR > InR then
            NewRegion := MakeDonutRegion(Centre, OutR, InR, Layer, eRegionKind_Copper);    //  eRegionKind_NamedRegion

        if NewRegion <> nil then
            Board.AddPCBObject(NewRegion);

        PCBServer.PostProcess;
    end;
end;

procedure MakeRegionDonut;
var
    SourceLib  : IPCB_Library;
    Board      : IPCB_Board;
    Iterator   : IPCB_GroupIterator;
    NewRegion  : IPCB_Region;
    Centre     : TCoordPoint;
    BWOrigin   : TCoordPoint;
    Layer      : TLayer;
    OutR, InR  : extended;
    CompFP     : IPCB_LibComponent;
    FPName     : WideString;
    APad       : IPCB_Pad;
    APrim      : IPCB_Primitive;
    I          : integer;
    PrimList   : TObjectList;

begin
    Document := GetWorkSpace.DM_FocusedDocument;
    if not ((Document.DM_DocumentKind = cDocKind_PcbLib) or (Document.DM_DocumentKind = cDocKind_Pcb)) Then
//    if not (Document.DM_DocumentKind = cDocKind_PcbLib) Then
    begin
         ShowMessage('No PcbLib selected. ');
         Exit;
    end;
    IsLib  := false;
    if (Document.DM_DocumentKind = cDocKind_PcbLib) then
    begin
        SourceLib := PCBServer.GetCurrentPCBLibrary;
        Board := SourceLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (SourceLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    PrimList := TObjectList.Create;
    PrimList.OwnsObjects := false;

    Layer  := Board.CurrentLayer;
    OutR   := eOuterRadius;
    InR    := eInnerRadius;
    APad   := nil;
    CompFP := nil;

    for I := 0 to (Board.SelectedObjectsCount - 1) do
    begin
// find the PCB Component
        APrim := Board.SelectecObject(I);

        if (APrim.ObjectId = ePadObject) or (APrim.ObjectId = eViaObject) then
        begin
            APad := APrim;
            break;
        end;

        if IsLib then
            CompFP := SourceLib.CurrentComponent
        else
        begin
            if APrim.ObjectId = eComponentObject then
                CompFP := APrim;
            if APrim.InComponent then
                CompFP := APrim.Component;
        end;

        if CompFP = nil then continue;

// alt. to iterator methods.
// for I := 1 to CompFP.GetPrimitiveCount(MkSet(ePadObject)) do
// APad := CompFP.GetPrimitiveAt(I, ePadObject)

//         if APrim.ObjectId = eRegionObject then
//             Showmessage(IntToStr(APrim.ShapeSegmentCount));

        Iterator := CompFP.GroupIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(ePadObject));

        APrim := Iterator.FirstPCBObject;
        While (APrim <> Nil) Do
        Begin

// auto pick pin 1 for libcomp
            if (IsLib) then
            if APrim.Name = '1' then
            begin
                APad := APrim;
                break;
            end;

            APrim := Iterator.NextPCBObject;
        end;
        CompFP.GroupIterator_Destroy(Iterator);
    end;

    if APad <> nil then
    begin
        Centre := Point(APad.X, APad.Y);

// get pad & holesize for pad if pin 1
        if (not IsLib) or (APad.Name = 1) then
        if APad.ShapeOnLayer(eTopLayer)= eRounded then
        begin
            InR  := CoordToMils(APad.HoleSize/2) + 2;
            OutR := CoordToMils(APad.TopXSize/2);
            if APad.BotXSize > APad.TopXSize then
                OutR := CoordToMils(APad.BotXSize/2);
        end;
        if (OutR <= InR) then
            OutR := eOuterRadius;
        if (OutR <= InR) then
            InR := eInnerRadius;

        PCBServer.PreProcess;
        NewRegion := MakeDonutRegion(Centre, OutR, InR, Layer, eRegionKind_Copper);    //  eRegionKind_NamedRegion

        if NewRegion <> nil then
            Board.AddPCBObject(NewRegion);

        if (not IsLib) then
        if CompFP <> nil then
            CompFP.AddPCBObject(NewRegion);

        PCBServer.PostProcess;
    end;
end;

procedure MakeArcDonut;
var
    SourceLib  : IPCB_Library;
    Board      : IPCB_Board;
    Iterator   : IPCB_GroupIterator;
    NewArc     : IPCB_Arc;
    Centre     : TCoordPoint;
    Layer      : TLayer;
    OutR, InR  : extended;
    CompFP     : IPCB_LibComponent;
    FPName     : WideString;
    APad       : IPCB_Pad;
    APrim      : IPCB_Primitive;
    I          : integer;
    PrimList   : TObjectList;

begin
    Document := GetWorkSpace.DM_FocusedDocument;
    if not ((Document.DM_DocumentKind = cDocKind_PcbLib) or (Document.DM_DocumentKind = cDocKind_Pcb)) Then
//    if not (Document.DM_DocumentKind = cDocKind_PcbLib) Then
    begin
         ShowMessage('No PcbLib selected. ');
         Exit;
    end;
    IsLib  := false;
    if (Document.DM_DocumentKind = cDocKind_PcbLib) then
    begin
        SourceLib := PCBServer.GetCurrentPCBLibrary;
        Board := SourceLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (SourceLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    PrimList := TObjectList.Create;
    PrimList.OwnsObjects := false;

    Layer  := Board.CurrentLayer;
    OutR   := eOuterRadius;
    InR    := eInnerRadius;
    APad   := nil;
    CompFP := nil;

    for I := 0 to (Board.SelectedObjectsCount - 1) do
    begin
// find the PCB Component
        APrim := Board.SelectecObject(I);
        
        if (APrim.ObjectId = ePadObject) or (APrim.ObjectId = eViaObject) then
        begin
            APad := APrim;
            break;
        end;

        if IsLib then
            CompFP := SourceLib.CurrentComponent
        else
        begin
            if APrim.ObjectId = eComponentObject then
                CompFP := APrim;
            if APrim.InComponent then
                CompFP := APrim.Component;
        end;

        if CompFP = nil then continue;

        Iterator := CompFP.GroupIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(ePadObject));

        APrim := Iterator.FirstPCBObject;
        While (APrim <> Nil) Do
        Begin

// auto pick pin 1 for libcomp
            if (IsLib) then
            if APrim.Name = '1' then
            begin
                APad := APrim;
                break;
            end;

            APrim := Iterator.NextPCBObject;
        end;
        CompFP.GroupIterator_Destroy(Iterator);
    end;

    if APad <> nil then
    begin
        Centre := Point(APad.X, APad.Y);

        if (not IsLib) or (APad.Name = 1) then
        if APad.ShapeOnLayer(eTopLayer)= eRounded then
        begin
            InR  := CoordToMils(APad.HoleSize/2) + 2;
            OutR := CoordToMils(APad.TopXSize/2);
            if APad.BotXSize > APad.TopXSize then
                OutR := CoordToMils(APad.BotXSize/2);
        end;
        if OutR <= InR then
            OutR := eOuterRadius;
        if OutR <= InR then
            InR := eInnerRadius;

        PCBServer.PreProcess;
        PrimList := MakeDonutArc(Centre, OutR, InR, Layer);

        for I := 0 to (PrimList.Count - 1) do
        begin
            NewArc := PrimList.Items(I);

            Board.AddPCBObject(NewArc);

            if (not IsLib) then
            if CompFP <> nil then
                CompFP.AddPCBObject(NewArc);

        end;
        PCBServer.PostProcess;
    end;
    PrimList.Clear;
    PrimList.Destroy;
end;

procedure ExtrudeRegion;
var
    SourceLib  : IPCB_Library;
    Board      : IPCB_Board;
    Iterator   : IPCB_GroupIterator;
    APrim      : IPCB_Primitive;
    CompFP     : IPCB_LibComponent;
    ARegion    : IPCB_Region;
    NewBody    : IPCB_ComponentBody;
    Layer      : TLayer;
    ML         : TLayer;
    I          : integer;

begin
    Document := GetWorkSpace.DM_FocusedDocument;
//    if not ((Document.DM_DocumentKind = cDocKind_PcbLib) or (Document.DM_DocumentKind = cDocKind_Pcb)) Then
    if not (Document.DM_DocumentKind = cDocKind_PcbLib) Then
    begin
         ShowMessage('No PcbLib selected. ');
         Exit;
    end;
    IsLib  := false;
    if (Document.DM_DocumentKind = cDocKind_PcbLib) then
    begin
        SourceLib := PCBServer.GetCurrentPCBLibrary;
        Board := SourceLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (SourceLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

// if iterating all FP in PcbLib..
//    if IsLib then
//    begin
//        SourceLib.SetState_CurrentComponent(CompFP);    //must use else Origin & BR all wrong.
//        SourceLib.RefreshView;
//        Board := SourceLib.Board;
//    end;

    CompFP  := SourceLib.CurrentComponent;
    Layer   := Board.CurrentLayer;
    ARegion := nil;

    for I := 0 to (Board.SelectedObjectsCount - 1) do
    begin

// alt. to iterator methods.
// CompFP.GetPrimitiveCount(MkSet(eRegionObject))
// APad := CompFP.GetPrimitiveAt(I, eRegionObject)

        Iterator := CompFP.GroupIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eRegionObject));

        APrim := Iterator.FirstPCBObject;
        While (APrim <> Nil) Do
        Begin
//         if APrim.ObjectId = eRegionObject then
//             Showmessage(IntToStr(APrim.ShapeSegmentCount));

            if APrim.Selected then
            begin
                ARegion := APrim;
                break;
            end;
            APrim := Iterator.NextPCBObject;
        end;
        CompFP.GroupIterator_Destroy(Iterator);
    end;

//  only allow ComponentBody on Mechanical layer
    ML := LayerUtils.MechanicalLayer(iMechLayer);
    if not LayerUtils.IsMechanicalLayer((Layer)) then
        Layer := ML;

    if ARegion <> nil then
    begin
        PCBServer.PreProcess;

        NewBody := AddExtrudedBody2(ARegion, nil, Layer, 0, false);

        if NewBody <> nil then
        begin
            Board.AddPCBObject(NewBody);

            if (not IsLib) then
            if CompFP <> nil then
                CompFP.AddPCBObject(NewBody);

            NewBody.GraphicallyInvalidate;
        end;
        PCBServer.PostProcess;
    end;
end;

// ArcShape method
function MakeDonutArc(Centre : TCoordPoint, OutR, InR : extended, Layer : TLayer) : TObjectList;
var
    Arc        : IPCB_Arc;
    TrkPrim    : IPCB_Primitive;
    Net        : IPCB_Net;
    I          : integer;
    theta      : extended;
    ASector    : extended;
    X, Y       : extended;
    SegCount   : integer;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    Net    := nil;

    ASector := 360 / eSections;

// start conditions
    SegCount := 0;
    theta := 0;

// ring shape
    for I := 0 to (Sectors - 1) do
    begin

        Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
        Arc.Layer     := Layer;
        Arc.Radius    := (MilsToRealCoord(OutR) + MilsToRealCoord(InR)) / 2;
        Arc.LineWidth := MilsToCoord(OutR) - MilsToCoord(InR);

        Arc.XCenter    := Centre.X;
        Arc.YCenter    := Centre.Y;
        Arc.StartAngle := theta;
        theta          := theta + ASector;
        Arc.EndAngle   := theta;

        if Net <> Nil then Arc.Net := Net;

//        X := Centre.X + MilsToCoord(OutR);
//        Y := Centre.Y + MilsToCoord(0);
//        RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);
        Result.Add(Arc);
    end;
end;



// RegionShape method
function MakeDonutRegion(Centre : TCoordPoint, OutR, InR : extended, Layer : TLayer, const RegKind : TRegionKind) : TPCB_Region;
var
    GMPC1      : IPCB_GeometricPolygon;
    Region     : IPCB_Region;
    TrkPrim    : IPCB_Primitive;
    PolySeg    : TPolySegment;
    Net        : IPCB_Net;
    I          : integer;
    theta      : extended;
    ASector    : extended;
    X, Y       : extended;
    SegCount   : integer;

begin

    Region := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    Region.SetState_Kind(RegKind);
    Region.Layer := Layer;
// not supported
//    Region.SetState_ArcApproximation( MilsToCoord(0.15));   // for the contour GMPC

    Net    := nil;
    if Net <> Nil then Region.Net := Net;

    ASector := 360 / eSections;

// start conditions
    X := Centre.X + MilsToCoord(OutR);
    Y := Centre.Y + MilsToCoord(0);
    SegCount := 0;
    theta := 0;

// outer shape
    for I := 0 to (Sectors - 1) do
    begin
        PolySeg := TPolySegment;
        PolySeg.Kind := ePolySegmentArc;

        X := Centre.X + MilsToCoord(OutR);
        Y := Centre.Y + MilsToCoord(0);
        RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);

        PolySeg.vx := X;
        PolySeg.vy := Y;

        PolySeg.Radius := MilsToCoord(OutR);
        PolySeg.cx     := Centre.X;
        PolySeg.cy     := Centre.Y;
        PolySeg.Angle1 := theta;
        theta          := theta + ASector;
        PolySeg.Angle2 := theta;

        inc(SegCount);
        Region.ShapeSegmentCount := SegCount;
        Region.ShapeSegments[SegCount - 1] := PolySeg;
    end;

// end (X,Y)
    X := Centre.X + MilsToCoord(OutR);
    Y := Centre.Y + MilsToCoord(0);
    RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);
    PolySeg := TPolySegment;
    PolySeg.Kind := ePolySegmentLine;
    PolySeg.vx := X;
    PolySeg.vy := Y;
    inc(SegCount);
    Region.ShapeSegmentCount := SegCount;
    Region.ShapeSegments[Segcount - 1] := PolySeg;

// join outer to inner
    X := Centre.X + MilsToCoord(InR);
    Y := Centre.Y + MilsToCoord(0);
    RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);

    PolySeg := TPolySegment;
    PolySeg.Kind := ePolySegmentLine;
    PolySeg.vx   := X;
    PolySeg.vy   := Y;
    inc(SegCount);
    Region.ShapeSegmentCount := SegCount;
    Region.ShapeSegments[Segcount - 1] := PolySeg;

// inner shape
    for I := 0 to (Sectors -1) do
    begin
        PolySeg := TPolySegment;
        PolySeg.Kind := ePolySegmentArc;

// start (X, Y)
        X := Centre.X + MilsToCoord(InR);
        Y := Centre.Y + MilsToCoord(0);
        RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);

        PolySeg.vx := X;
        PolySeg.vy := Y;

        PolySeg.Radius := MilsToCoord(InR);
        PolySeg.cx     := Centre.X;
        PolySeg.cy     := Centre.Y;
        PolySeg.Angle2 := theta;
        theta          := theta - ASector;
        PolySeg.Angle1 := theta;

        inc(SegCount);
        Region.ShapeSegmentCount := SegCount;
        Region.ShapeSegments[Segcount - 1] := PolySeg;
    end;

// end (X,Y)
    X := Centre.X + MilsToCoord(InR);
    Y := Centre.Y + MilsToCoord(0);
    RotateCoordsAroundXY(X, Y, Centre.X, Centre.Y, theta);
    PolySeg := TPolySegment;
    PolySeg.Kind := ePolySegmentLine;
    PolySeg.cx := 0;
    Polyseg.cy := 0;
    PolySeg.vx := X;
    PolySeg.vy := Y;
    inc(SegCount);
    Region.ShapeSegmentCount := SegCount;
    Region.ShapeSegments[Segcount - 1] := PolySeg;

// join inner to outer (end to start)
    PolySeg := TPolySegment;
    PolySeg.Kind := ePolySegmentLine;
    PolySeg.vx := Centre.X + MilsToCoord(OutR);
    PolySeg.vy := Centre.Y + MilsToCoord(0);
    inc(SegCount);
    Region.ShapeSegmentCount := SegCount;
    Region.ShapeSegments[Segcount - 1] := PolySeg;

    Region.UpdateContourFromShape(true);
    Result := Region;
end;

// can pass Region or Polygon
// GMPC are all holes.
function AddExtrudedBody2(Region : IPCB_Region, const GMPC : IPCB_GeometricPolygon, const Layer : TLayer, const UIndex : integer, const MainContour : boolean) : IPCB_ComponentBody;
var
    CompModel      : IPCB_Model;
    GMPC1          : IPCB_GeometricPolygon;
    StandoffHeight : Integer;
    OVAHeight      : integer;
    Colour         : TColor;
    PolySeg        : TPolySegment;
    SegmentCount   : integer;
    Hole           : TContour;
    I              : integer;

begin
    Result := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);

    StandoffHeight := 0;
    Colour := clBlue;
    StringToRealUnit('5mm', OVAHeight, eMM);

    Result.SetState_Identifier('Donuts');
    Result.BodyProjection := eBoardSide_Top;
    Result.Layer := Layer;
    Result.BodyOpacity3D := 1;
    Result.BodyColor3D := Colour;
    Result.StandoffHeight := StandoffHeight;
    Result.OverallHeight  := OVAHeight;
    Result.Kind           := eRegionKind_Copper;        // necessary ??

//    RegionShape interface
    PolySeg      := TPolySegment;
    SegmentCount := 0;

    if Region.ObjectId = ePolyObject then
        SegmentCount := Region.PointCount;
    if Region.ObjectId = eRegionObject then
        SegmentCount := Region.ShapeSegmentCount;

    if (SegmentCount > 0) then
    begin
        Result.ShapeSegmentCount := SegmentCount;
        for I := 0 to (SegmentCount - 0) do
        begin
            if Region.ObjectId = eRegionObject then
                PolySeg := Region.ShapeSegments(I)
            else
                PolySeg := Region.Segments(I);

            Result.ShapeSegments(I) := PolySeg;
        end;
        Result.UpdateContourFromShape(true);
    end else

// code path not tested.
    begin
        PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcResolution));
        GMPC1 := PcbServer.PCBContourMaker.MakeContour(Region, Expansion, Layer);
        if MainContour then
            Result.SetOutlineContour( GMPC1.Contour(0) )
        else
            Result.GeometricPolygon := GMPC1;
    end;

    if (not MainContour) then
    if GMPC <> nil then
    for I := 0 to GMPC.Count - 1 do
    begin
        Hole := GMPC.Contour(I);
        if GMPC.IsHole(I) then
            Result.GeometricPolygon.AddContourIsHole(Hole, true);
    end;

    if Assigned(Result.Model) Then
    begin
        CompModel := Result.ModelFactory_CreateExtruded(StandoffHeight, OVAheight, Colour);
        if Assigned(CompModel) then
        begin
            // SOHeight := MMsToCoord(StandoffHeight);
            CompModel.SetState(0,0,0,0);          // (RotX, RotY, RotZ, SOHeight);
            Result.SetModel( CompModel );
// convert to step
//            NewCModel := CompModel.I_ReplicateToGeneric;
//            Result.SetModel( NewCModel );
        end;
    end;
end;
