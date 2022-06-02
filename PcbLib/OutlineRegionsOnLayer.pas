{  OutlineRegionsOnLayer.pas

  make Lines around the shapes of Regions & ComponentBodies of all footprints in PcbLib
  Need to specify the Layers for: Source / Target (Region) & Destination (lines) for Region & CompBody outlines

  Make polyline shape ON boundary centerline of regions & polygons.
  Works on board outline!

  Disabled polyline shape expansion.
  Contour expansion always worked.

Author BLM.
26/06/2021  v0.10  POC
10/09/2021  v0.11  Added ArcResolution()
16/03/2022  v0.20  added regionshape polyline "outliner"
21/04/2022  v0.21  (was 0.12) uses RegionShapes allow copper or mech input layers
03/06/2022  v0.22  add boolean const to control renaming of comp bodies with blank names.

   Poly.GrowPolyshape() expansion does not always return a valid closed shape (internal bug).
   Generic/step models are named by from/by the filename.
   Extruded can be blank or repeated default.


    IPCB_PolyRegShapesClipResult;   //IShapes
    IPCB_ShapeEdge;
    IPCB_ShapeEdge_Parabola;

...................................................................................}

const
    cTargetLayer   = 13;    // 0= no layer; mech layer of Target primitives.
    cTargetCuLayer = 0;     // copper
    cDestinLayer   = 31;    // for Region OutLine
    cDestinLayer2  = 32;    // for CompBody OutLine
    cLineWidth     = 0.5;     // mils

//    OutlineExpansion     = 0.0;    // 30 mils from edge.
    ArcResolution        = 0.1;    // mils : impacts number of edges etc..

    bDisplay = true;
    ReportFileSuffix = '_FP-RegLinesRpt';
    ReportFileExtension = '.txt';
    ReportFolder = 'Reports';
    bLock   = false;                // lock the unlocked
    bUnLock = false;                // unlock the locked
    
    bRenameExtrudedBody = true;     //   extruded bodies have a terrible repeated name and/or <blank> name.

Var
    CurrentLib  : IPCB_Library;
    Board       : IPCB_Board;
    BOrigin     : TCoordPoint;
    CompBody    : IPCB_ComponentBody;
    Rpt         : TStringList;

function GenerateReport(Rpt : TStringList) : boolean; forward;
function ContourToLines(GPCVL  : Pgpc_vertex_list, Layer : TLayer, UIndex : integer) : integer;           forward;
function ShapeToPolyLines(Prim : IPCB_Primitive, const Layer : TLayer, const UIndex : integer) : integer; forward;

Procedure OutLineRegions;
Var
    FootprintIterator : IPCB_LibraryIterator;
    Iterator          : IPCB_GroupIterator;
    Handle            : IPCB_Primitive;
    Region            : IPCB_Region;
    Contour           : IPCB_Contour;
//    Expansion         : TCoord;
    MechLayer         : IPCB_MechanicalLayer;
    Layer             : TLayer;
    NoOfPrims         : Integer;
    NumOfBody         : integer;
    Footprint         : IPCB_Object;
    PLSet             : IPCB_LayerSet;

Begin
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
        Board := PCBServer.GetCurrentPCBBoard
    else
        Board := CurrentLib.Board;

    if Board = nil then
    Begin
        ShowMessage('not a PCB Doc or Lib');
        Exit;
    End;

    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));

    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcResolution));
//    Expansion := MilsToCoord(OutlineExpansion);

    Layer := LayerUtils.MechanicalLayer(cDestinLayer);
    MechLayer := Board.LayerStack_V7.LayerObject_V7(Layer);
    If Not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        MechLayer.Name := 'Reg Line Out';
        MechLayer.IsDisplayed[Board] := true;
        Board.ViewManager_UpdateLayerTabs;
    end;

    Layer := LayerUtils.MechanicalLayer(cDestinLayer2);
    MechLayer := Board.LayerStack_V7.LayerObject_V7(Layer);
    If Not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        MechLayer.Name := 'CBody Line Out';
        MechLayer.IsDisplayed[Board] := true;
        Board.ViewManager_UpdateLayerTabs;
    end;

//  Each page of library is a footprint
    FootprintIterator := CurrentLib.LibraryIterator_Create;
    FootprintIterator.AddFilter_LayerSet(AllLayers);
    FootprintIterator.SetState_FilterAll;

    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(CurrentLib.Board.FileName));
    Rpt.Add('TargetLayer        : ' + Board.LayerName(LayerUtils.MechanicalLayer(cTargetLayer)) );
    Rpt.Add('Output Region Lines Layer : ' + Board.LayerName(LayerUtils.MechanicalLayer(cDestinLayer)) );
    Rpt.Add('Output CBody  Lines Layer : ' + Board.LayerName(LayerUtils.MechanicalLayer(cDestinLayer2)) );
    Rpt.Add('');

    PLSet := LayerSet.EmptySet;
    if cTargetLayer <> 0 then
        PLSet.Include(LayerUtils.MechanicalLayer(cTargetLayer));
    if cTargetCuLayer <> 0 then
        PLSet.Include(cTargetCuLayer);

    Footprint := FootprintIterator.FirstPCBObject;
    While Footprint <> Nil Do
    Begin
        CurrentLib.SetState_CurrentComponent (Footprint);      // to make origin correct.
        Board := CurrentLib.Board;

        Rpt.Add('Footprint : ' + Footprint.Name);

        Iterator := Footprint.GroupIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eRegionObject, eComponentBodyObject));
        Iterator.AddFilter_IPCB_LayerSet(PLSet);    // DNW in PcbLib.
        Handle := Iterator.FirstPCBObject;

        While (Handle <> Nil) Do
        Begin
//                if bUnLock then Handle.Moveable := true;

                Rpt.Add('Prim : ' + Handle.ObjectIdString);

                if Handle.GetState_ObjectId = eRegionObject then
                begin
                    Region := Handle;

                    if (not Region.IsKeepout) then
                    if (not Region.InPolygon) then
                    if (Region.Layer = LayerUtils.MechanicalLayer(cTargetLayer)) or (Region.Layer = cTargetCuLayer) then
                    begin
                    //  Contour method:
                    //    GMPG := Region.GeometricPolygon;
                    //    Contour := Region.GetMainContour;
                    //    NoOfPrims := ContourToLines(Contour, LayerUtils.MechanicalLayer(cDestinLayer), 0);
                    //  RegionShape method:
                        NoOfPrims := ShapeToPolyLines(Region, LayerUtils.MechanicalLayer(cDestinLayer), 0);
                        Rpt.Add('Region vertices: ' + IntToStr(NoOfPrims));
                    end;
                end;

                if (Handle.ObjectId = eComponentBodyObject) then
                begin
                    CompBody := Handle;

                    if (CompBody.Layer = LayerUtils.MechanicalLayer(cTargetLayer)) then
                    begin
//                        Contour   := CompBody.MainContour;
//                        NoOfPrims := ContourToLines(Contour, LayerUtils.MechanicalLayer(cDestinLayer2), 0);
                        NoOfPrims := ShapeToPolyLines(CompBody, LayerUtils.MechanicalLayer(cDestinLayer2), 0);
                        Rpt.Add('CompBody vertices: ' + IntToStr(NoOfPrims));
                    end;

//   make blank identifier (not generic model) something useful
                    if (bRenameExtrudedBody) then
                    if CompBody.Identifier = '' then  CompBody.SetState_Identifier(Footprint.Name);

                end;

//                if (not bLock) and bUnLock then Handle.Moveable := true;
//                if bLock then Handle.Moveable := false;

                Handle := Iterator.NextPCBObject;
        End;

        Rpt.Add('');

        Footprint.GroupIterator_Destroy(Iterator);
        // PcbServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
        Footprint := FootprintIterator.NextPCBObject;
    End;

    CurrentLib.LibraryIterator_Destroy(FootprintIterator);
    CurrentLib.Navigate_FirstComponent;
    CurrentLib.RefreshView;  // .GraphicallyInvalidate;

    GenerateReport(Rpt);
    Rpt.Free;
end;

// for polygons & regions.
function ShapeToPolyLines(Prim : IPCB_Primitive, const Layer : TLayer, const UIndex : integer) : integer;
var
    PrimKind  : TObjectID;
    Region    : IPCB_Region;
    Poly      : IPCB_Polygon;
    PolySeg1  : TPolySegment;
    PolySeg2  : TPolySegment;
    SegCount  : integer;
    HoleCount : integer;
    Hole      : TContour;
    I        : Integer;
    P1, P2   : TPoint;
    Track    : IPCB_Track;
    Arc      : IPCB_Arc;

begin
    Result := 0;
    PCBServer.PreProcess;

    PolySeg1 := TPolySegment;
    PolySeg2 := TPolySegment;
    Segcount := 0;

    PrimKind := Prim.ObjectId;

    if (PrimKind = eRegionObject) or (PrimKind = eComponentBodyObject) then
    begin
        Region := Prim;
        Region.UpdateContourFromShape(True);
        SegCount := Region.ShapeSegmentCount;
    end;

    if (PrimKind = ePolyObject) or (PrimKind = eBoardOutlineObject) then
    begin
        Poly := Prim;  // Prim.Replicate;
   //     Poly.GrowPolyshape(MilsToCoord(20));
   //     Poly.SetState_ExpandOutline(true);
   //     Poly.SetState_XSizeYSize;

        SegCount := Poly.PointCount;
    end;

    for I := 0 to (SegCount) do
    begin
        if (PrimKind = eRegionObject) or (PrimKind = eComponentBodyObject) then
        begin
            PolySeg1 := Region.ShapeSegments(I);
            if (I <> SegCount) then
                PolySeg2 := Region.ShapeSegments(I+1)
            else
                PolySeg2 := Region.ShapeSegments(0);
        end;

        if (PrimKind = ePolyObject) or (PrimKind = eBoardOutlineObject) then
        begin
            PolySeg1 := Poly.Segments(I);
            if (I <> SegCount) then
                PolySeg2 := Poly.Segments(I+1)
            else
                PolySeg2 := Poly.Segments(0);
        end;

        if PolySeg1.Kind = ePolySegmentLine then
        begin
            Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
//            PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
            Track.BeginModify;
            Track.Width := MilsToCoord(cLineWidth);
            Track.Layer := Layer;
            Track.x1 := PolySeg1.vx;
            Track.y1 := PolySeg1.vy;
            Track.x2 := PolySeg2.vx;
            Track.y2 := PolySeg2.vy;
            Track.UnionIndex := UIndex;      // no point in PcbLib.
            Board.AddPCBObject(Track);
            Track.EndModify;
//            PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
        end;

        if PolySeg1.Kind = ePolySegmentArc then
        begin
               Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
 //              PCBServer.SendMessageToRobots(Arc.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
               Arc.BeginModify;
               Arc.Layer := Layer;
               Arc.LineWidth := MilsToCoord(cLineWidth);
               Arc.Radius     := PolySeg1.Radius;

               Arc.XCenter    := PolySeg1.cx;
               Arc.YCenter    := PolySeg1.cy;
               Arc.StartAngle := PolySeg1.Angle1;
               Arc.EndAngle   := PolySeg1.Angle2;

//               Arc.StartX     := PolySeg1.vx;
//               Arc.StartY     := PolySeg1.vy;
//               Arc.EndX := PolySeg2.vx;
//               Arc.EndY := PolySeg2.vy;

               Arc.UnionIndex := UIndex;      // no point in PcbLib.
               Board.AddPCBObject(Arc);
               Arc.EndModify;
   //            PCBServer.SendMessageToRobots(Arc.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
               PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
        end;
        inc(Result);
        Rpt.Add('PrimKind ' + IntTostr(PrimKind) + '  segkind ' + IntToStr(PolySeg1.Kind) + '  x ' + CoordUnitToString(PolySeg1.vx - BOrigin.X ,eMils) + '  y ' + CoordUnitToString(PolySeg1.vy - BOrigin.Y, eMils) +
                 '  r ' + CoordUnitToString(PolySeg1.Radius ,eMils) + '  a1 ' + FloatValueToString(PolySeg1.Angle1 ,eMils) + '  a2 ' + FloatValueToString(PolySeg1.Angle2 ,eMils) );
    end;

    if (PrimKind = eRegionObject) or (PrimKind = eComponentBodyObject) then
    begin
        HoleCount := Region.HoleCount;
        for I := 0 to (HoleCount - 1) do
        begin
            Hole := Region.Holes(I);
            SegCount := ContourToLines(Hole, Layer, UIndex);
        end;
        inc(Result);
        Rpt.Add('PrimKind ' + IntTostr(PrimKind) + '  holecount ' + IntToStr(HoleCount) + '  segcount ' + IntToStr(SegCount));
    end;

//    if Region <> nil then PCBServer.DestroyPCBObject(Region);
//    if Poly <> nil then PCBServer.DestroyPCBObject(Poly);

    PCBServer.PostProcess;
end;

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
    //  PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
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
    //  PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
        if bLock then Track.Moveable := false;
        inc(Result);
    end;
    PCBServer.PostProcess;
end;

function GenerateReport(Rpt : TStringList) : boolean;
var
    FilePath          : WideString;
    FileName          : TPCBString;
    FileNumber        : integer;
    FileNumStr        : WideString;
    Document          : IServerDocument;

begin
    FilePath := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFileName(FilePath) + '_' + ReportFileSuffix;
    FilePath := ExtractFilePath(FilePath) + ReportFolder;
    if not DirectoryExists(FilePath, false) then
        DirectoryCreate(FilePath);

    FileNumber := 1;
    FileNumStr := IntToStr(FileNumber);
    FilePath := FilePath + '\' + FileName;
    While FileExists(FilePath + FileNumStr + ReportFileExtension) do
    begin
        inc(FileNumber);
        FileNumStr := IntToStr(FileNumber)
    end;
    FilePath := FilePath + FileNumStr + ReportFileExtension;
    Rpt.SaveToFile(FilePath);

    Document  := Client.OpenDocument('Text', FilePath);
    If bDisplay and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then  // no LongBool const
            Document.DoFileLoad;
    end;
end;

{..............................................................................}
End.
