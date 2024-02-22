{ PolygonReFitBO.pas
   from SolderMaskCopper02.pas

   Grow/Shrink polygons:
      buggy with arc corners
      open & close modal properties helps.
      works on Board Outline.

   Modify selected polygon's outline to Board Outline by:-
  -  copying the full board outline (preserves polyline arcs)
  -  clipping existing shape to board outline (line segment approximation).

  Or copy selected polygon outline to be the new board outline

B. Miller
12/05/2020  v0.10  POC
13/05/2020  v0.11  Allow pre-selection of poly obj. Select object.
12/07/2020  v0.12  Make board outline from selected polygon Outline.
04/11/2020  v0.13  Clip Polygon to board outline shape.
06/11/2020  v0.14  refactor 2 func into one fn.
16/01/2021  v0.15  Over iterating Vertex lists. All zero refed.
09/02/2021  v0.16  mapping vertexlist into Polygon segment must loop 0 to count
21/09/2021  v0.17  copied over ExportBoardOutline from CompModelHeight.
2023-06-07  v0.18  grow or shrink (shift key) polygon
2023-06-22  v0.19  attempt to repair polyoutline
2024-02-23  v0.20  add InputBox for grow/shrink

tbd:
Poly Outline heal. think all problems stem from original outline errors (microgaps)

The region in new poly outline is not resetting vertice list / not refreshing completely.
Opening properties vertex list is enough to fix.. grab handles in odd place or missing.
    -- seems fixed..
 ..............................................................................}

const
    bDisplay = false;
    OutlineExpansion     = 0.0;  // 30 mils from edge.
    ArcResolution        = 0.02; // mils : impacts number of edges etc..
    GrowthFactor         = 50;   // mils
    bHealShape           = false;
    bHealNewShape        = true;

function PolyIsCCW(OP : IPCB_Polygon) : boolean; forward;
function RepairPolyOutline(Poly : IPCB_Polygon, GMPC1 : IPCB_GeometricPolygon, GMPC2 : IPCB_GeometricPolygon) : boolean; forward;
function RepairPolyOutline2(OP, var NP : IPCB_polygon, GD : extended) : boolean; forward;
function HealPolyOutline(OP : IPCB_Polygon) : boolean;        forward;

Var
   Board        : IPCB_Board;
   BUnit        : TUnit;
   BOL          : IPCB_BoardOutline;
   BOrigin      : TPoint;
   ReportLog    : TStringList;
   RepourMode   : TPolygonRepourMode;
   VerMajor     : integer;

{..............................................................................}

Procedure PolygonGrow();
var
    Poly      : IPCB_Polygon;
    OldPoly   : IPCB_Polygon;
    GMPC1     : IPCB_GeometricPolygon;
    GMPC2     : IPCB_GeometricPolygon;
    Prim          : IPCB_Primitive;
    ModifierKey   : integer;
    Distance      : TCoord;
    ObjSet        : TSet;
    bWasFixed     : boolean;
    sInput        : Widestring;
    sDefault      : WideString;
    InUnits       : TMeasureUnit;
    Value         : extended;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BUnit     := Board.DisplayUnit;
    VerMajor  := GetBuildNumberPart(Client.GetProductVersion,0);
    ReportLog := TStringList.Create;

    //Save the current Polygon repour setting
    RepourMode := PCBServer.SystemOptions.PolygonRepour;
// Update so that Polygons always repour - avoids polygon repour yes/no dialog box popping up.
    PCBServer.SystemOptions.PolygonRepour := eAlwaysRepour;

    Poly := nil;
    ObjSet := MkSet(ePolyObject, eBoardOutlineObject);
    if Board.SelectecObjectCount > 0 then
    begin
        Prim := Board.SelectecObject(0);
        if InSet(Prim.ObjectId, ObjSet) then
            Poly := Prim;
    end;

    if Poly = nil then
        Poly := Board.GetObjectAtCursor(MkSet(ePolyObject, eBoardOutlineObject), AllLayers, 'Select polygon to Change size');


    if Poly <> nil then
    begin
        if (BUnit <> eMM) then    // backwards in AD17
            sDefault := '1mm'
        else
            sDefault := '5mil';

        sInput := InputBox('Polygon Grow','Enter Offset (+/-):',sDefault);
        ModifierKey := ShiftKeyDown;

        InUnits := 0;
        StringToRealUnit(sInput, Value, InUnits);
        Distance := RoundSaturate(Value);

//        Distance := MilsToCoord(GrowthFactor);
        if ModifierKey  then
            Distance := Distance * -1;

        PCBServer.PreProcess;

        if bHealShape then
            HealPolyOutline(Poly);

        OldPoly := Poly.ReplicateWithChildren;

// 1st attempt detection setup
//        PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(1));
//        GMPC1 := PCBServer.PCBContourMaker.MakeContour(Poly, Distance*0.99, Poly.Layer);
//        GMPC2 := PCBServer.PCBContourMaker.MakeContour(Poly, Distance*1.01, Poly.Layer);
        ReportLog.Add('Original Poly defined area : ' + SqrCoordToUnitString(Poly.AreaSize, 0, 7));

        Poly.BeginModify;
//        Poly.SetState_ArcApproximation(MilsToCoord(0.1));
        Poly.GrowPolyshape(Distance);

// 1st attempt
//        RepairPolyOutline(Poly, GMPC1, GMPC2);

        if bHealNewShape then
            bWasfixed := RepairPolyOutline2(OldPoly, Poly, Distance);

        PCBserver.DestroyPCBObject(OldPoly);

        Poly.SetState_CopperPourInvalid;
        Poly.Rebuild;
        Poly.EndModify;
        Poly.GraphicallyInvalidate;
        Poly.Selected := true;

        ReportLog.Add('Resized Poly defined area : ' + SqrCoordToUnitString(Poly.AreaSize, 0, 7));
        PCBServer.PostProcess;

        if bWasfixed then
            ShowMessage('poly outline fixed, check for small vertices');
    end;

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
    //Revert back to previous user polygon repour option.
    PCBServer.SystemOptions.PolygonRepour := RepourMode;

    ReportLog.Free;
end;

// only angles are floating point. need to solve for integer x,y & radius.
function HealPolyOutline(var OP : IPCB_Polygon) : boolean;
var
    I, J     : integer;
    OSegment    : TPolySegment;
    NSegment    : TPolySegment;
    Angle, X, Y : extended;
    Radius      : extended;
    bCCW        : boolean;
begin
    Result := false;

    bCCW := PolyIsCCW(OP);

    for I := 0 to OP.PointCount do
    begin
//        J := I +1;
//        if J > OP.PointCount then J := 0;

        OSegment := OP.Segments[I];
//        NSegment := OP.Segments[J];
        if OSegment.Kind = ePolySegmentArc then
        begin
            X := OSegment.vx; Y := OSegment.vy;

            Radius := SQRT( Power(X - OSegment.cx, 2) + Power(Y - OSegment.cy, 2) );
            Radius := RoundSaturate(Radius);
            OSegment.Radius := Radius;
            Angle := arccos((X - OSegment.cx) / Radius) / cPIdiv180;
            if Y < OSegment.cy then
               Angle := (360 - Angle);
// CW or CCW ??
//            if bCCW then
            if  Abs(OSegment.Angle1 - Angle) < 1 then
                OSegment.Angle1 := Angle;
            if  Abs(OSegment.Angle2 - Angle) < 1 then
                OSegment.Angle2 := Angle;

//            X := NSegment.vx;
//            Angle := arccos((X - OSegment.cx) / Radius) / cPIdiv180;
//            if bCCW then
//                OSegment.Angle2 := Angle
//            else
//                OSegment.Angle1 := Angle;

            OP.Segments[I] := OSegment;
        end;
    end;
end;

// arc polysegments:   Grow                    Shrink
// convex:      Arc always exists,             Arc can be eliminated if Dist >= radius
// concave:     Arc can be eliminated          Arc always exists, lines can be eliminated
// if Arc cx, cy is PointInPoly does not guarantee CC or CX !!
// the error is angle is (360 - theta)
// search for matching AR cx &cy the angle must have the same "sign"
// root cause is polyoutline is real space, but sytem is discrete TCoord.
function RepairPolyOutline2(OP, var NP : IPCB_polygon, GD : extended) : boolean;
var
    I, J     : integer;
    OSegment  : TPolySegment;
    NSegment  : TPolySegment;
    OSegment2 : TPolySegment;
    Angle     : extended;
    Radius : extended;
    bConvex   : boolean;
    bCCW      : boolean;
    X,Y       : TCoord;
begin
    Result := false;


    bCCW := PolyIsCCW(OP);

    for I := 0 to OP.PointCount do
    begin
        OSegment := OP.Segments[I];
        J := I +1;
        if J > OP.PointCount  then J:= 0;
        OSegment2 := OP.Segments[J];

        if OSegment.Kind <> ePolySegmentArc then continue;

        for J := 0 to NP.PointCount do
        begin
            NSegment := NP.Segments[J];
            if NSegment.Kind <> ePolySegmentArc then continue;

            if (NSegment.cx <> OSegment.cx) or (NSegment.cy <> OSegment.cy) then continue;

            bConvex := false;
            Angle := OSegment.Angle2 - OSegment.Angle1;
            X := OSegment.vx; Y := OSegment.vy;
            RotateCoordsAroundXY(X, Y, OSegment.cx, OSegment.cy, Angle);

            X := (OSegment.vx + X) / 2;
            Y := (OSegment.vy + Y) / 2;
            if OP.PointInPolygon(X, Y) then bConvex := true;

// convex + GD, concave -GD
            if bConvex then
                Radius := OSegment.Radius + GD
            else
                Radius := OSegment.Radius - GD;
            if (Radius < 0) then Radius := 0;

            if (NSegment.Radius <> Radius) then
            begin
                NSegment.Radius := Radius;

                if bCCW then
                    Angle := OSegment.Angle2
                else
                    Angle := OSegment.Angle1;

//                X := OSegment.cx + NSegment.Radius * cos(Angle * cPIdiv180);
//                Y := OSegment.cy + NSegment.Radius * sin(Angle * cPIdiv180);
//                NSegment.vx := RoundSaturate(X); NSegment.vy := RoundSaturate(Y);
                NP.Segments[J] := NSegment;
                Result := true;
            end;

            if Sign(NSegment.Angle2 - NSegment.Angle1) <> Sign(OSegment.Angle2 - OSegment.Angle1) then
            begin
                Angle := NSegment.Angle1;
                NSegment.Angle1 := NSegment.Angle2;
                NSegment.Angle2 := Angle;
                NP.Segments[J] := NSegment;
                Result := true;
            end;
        end;
    end;
end;

function PolyIsCCW(OP : IPCB_Polygon) : boolean;
var
    Seg1  : TPolySegment;
    Seg2  : TPolySegment;
    PSum  : extended;
    I, J  : integer;
begin
    Result := false;
    PSum := 0;
    for I := 0 to OP.PointCount do
    begin
        Seg1 := OP.Segments[I];
        J := I +1;
        if J > OP.PointCount  then J:= 0;
        Seg2 := OP.Segments[J];

// Sum over the edges, (x2 - x1)(y2 + y1). If the result is positive the curve is clockwise
        PSum := PSum + ((Seg2.vx - Seg1.vx) * (Seg2.vy + Seg1.vy));
    end;
    if PSum < 0 then Result := true;
end;

function RepairPolyOutline(Poly : IPCB_Polygon, GMPC1 : IPCB_GeometricPolygon, GMPC2 : IPCB_GeometricPolygon) : boolean;
var
    I        : integer;
    Segment  : TPolySegment;
    Contour  : IPCB_Contour;
    APoint   : TCoordPoint;
    bInside  : boolean;
    bOutside : boolean;
begin
    Result := false;
    Contour := GMPC1.Contour(0);
    PCBServer.PCBContourUtilities.ContourIsCW(Contour);
    bInside := true;
    for I := 0 to Contour.Count do
    begin
        APoint := Point(Contour.x(I), Contour.y(I));
        if not Poly.PointInPolygon(APoint.x, APoint.Y) then
            bInside := false;
        if not bInside then break;
    end;

    if bInside then
    begin
        Contour := GMPC2.Contour(0);
        bOutside := true;
        for I := 0 to Contour.Count do
        begin
            APoint := Point(Contour.x(I), Contour.y(I));
            if not Poly.PointInPolygon(APoint.x, APoint.Y) then
                bOutside := false;
            if not bOutside then break;
        end;
    end;
// problem with new poly
    if not (bOutside and bInside) then
    begin
        if (not bInside) and bOutside then
        begin
            Contour := GMPC1.Contour(0);
            APoint := Point(Contour.x(I), Contour.y(I));
            ShowMessage('inside ' + IntToStr(I));
        end;
        if not bOutside then
        begin
            Contour := GMPC2.Contour(0);
            APoint := Point(Contour.x(I), Contour.y(I));
            ShowMessage('outside ' + IntToStr(I));
        end;
// find polysegment.

    end;
end;

procedure RefreshBoardOutLine;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    BOL := Board.BoardOutline;
    PCBServer.PreProcess;
    Board.BeginModify;

    BOL.BeginModify;
    BOL.SetState_CopperPourInvalid;

    BOL.Rebuild;
    BOL.Invalidate;
    BOL.EndModify;

    BOL.SetState_XSizeYSize;
    BOL.GraphicallyInvalidate;

//  required to get outline area to update ?

    Board.UpdateBoardOutline;
    Board.RebuildSplitBoardRegions(true);

    Board.EndModify;
    Board.GraphicallyInvalidate;
    PCBServer.PostProcess;
end;

Procedure ExportBoardOutline;
Var
    PolySeg1  : TPolySegment;
    PolySeg2  : TPolySegment;
    Track     : IPCB_Track;
    Arc       : IPCB_Arc;
    I,J       : Integer;
    Data      : TStringList;
    FilePath  : WideString;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BeginHourGlass(crHourGlass);
    ReportLog := TStringList.Create;
    Data    := TStringList.Create;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    BOL     := Board.BoardOutline;

    Data.Add('BOLPointCount=' + IntToStr(BOL.PointCount) );
  // BO is region but polygon outline defined.
    For I := 0 To (BOL.PointCount) Do
    Begin
        J := I + 1;
        If I = (BOL.PointCount - 1) Then J := 0;
        PolySeg1 := BOL.Segments[I];
//        PolySeg2 := BOL.Segments[J];

        If PolySeg1.Kind = ePolySegmentLine Then
        Begin
            Data.Add('BOLSeg=' + IntToStr(I) + '|Kind=Track|VX1=' + IntToStr(PolySeg1.vx - BOrigin.X) + '|VY1=' + IntToStr(PolySeg1.vy - BOrigin.Y) );
//                            + '|VX2=' + IntToStr(PolySeg2.vx) + '|VY2=' + IntToStr(PolySeg2.vy));
        End
        Else
        Begin
            // Current segment is Arc
//            Arc.XCenter    := PolySeg1.cx;        Arc.YCenter    := PolySeg1.cy;
//            Arc.Radius     := PolySeg1.Radius;
//            Arc.StartAngle := PolySeg1.Angle1;    Arc.EndAngle   := PolySeg1.Angle2;
            Data.Add('BOLSeg=' + IntToStr(I) + '|Kind=Arc|CX=' + IntToStr(PolySeg1.cx - BOrigin.X) + '|CY=' + IntToStr(PolySeg1.cy - BOrigin.Y) +
                     '|Radius=' + IntToStr(PolySeg1.Radius) + '|Angle1=' + IntToStr(PolySeg1.Angle1) + '|Angle2=' + IntToStr(PolySeg1.Angle2));
        End;
    End;

    FilePath := ChangeFileExt(Board.FileName, '_BO-data.txt');
    Data.SaveToFile(FilePath);
    Data.Free;
End;


Function ClipPolygonToBoardOutline(var Polygon : IPCB_Polygon) : boolean;
Var
    Layer     : TLayer;
    PNet      : IPCB_Net;
    I         : Integer;
    GMPC1     : IPCB_GeometricPolygon;
    GMPC2     : IPCB_GeometricPolygon;
    GPCVL     : Pgpc_vertex_list;
    ArcRes    : float;
    Expansion : TCoord;
    Operation : TSetOperation;
    PolySeg   : TPolySegment;

Begin
    Layer := Polygon.Layer;
    ReportLog.Add('Modify Polygon: ''' + Polygon.Name + ''' on Layer ''' + cLayerStrings[Layer] + '''');

    BOL       := Board.BoardOutline;
    Expansion := 0; //  MilsToCoord(OutlineExpansion);
    ArcRes    := ArcResolution;
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcRes));

    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Polygon, Expansion, Polygon.Layer);
    GMPC2 := BOL.BoardOutline_GeometricPolygon;

    Operation := eSetOperation_Intersection;
    PcbServer.PCBContourUtilities.ClipSetSet (Operation, GMPC1, GMPC2, GMPC1);
    GPCVL := GMPC1.Contour(0);

    PCBServer.PreProcess;
    Polygon.BeginModify;

    PolySeg := TPolySegment;
    PolySeg.Kind := ePolySegmentLine;
    Polygon.PointCount := GPCVL.Count;
    For I := 0 To (GPCVL.Count) Do
    Begin
        PolySeg.vx   := GPCVL.x(I);
        PolySeg.vy   := GPCVL.y(I);
        Polygon.Segments[I] := PolySeg;
        ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
    End;

//    Polygon.SetState_CopperPourInvalid;
    Polygon.Rebuild;
//    Polygon.CopperPourValidate;
    Polygon.EndModify;

//  required to get outline area to update!
    Polygon.GraphicallyInvalidate;
    Polygon.SetState_XSizeYSize;
    PCBServer.PostProcess;
End;

Function ModifyPolygonToBoardOutline(var Polygon : IPCB_Polygon) : boolean;
Var
    BOL     : IPCB_BoardOutline;
    PolySeg : TPolySegment;
    Layer   : TLayer;
    PNet    : IPCB_Net;
    I       : Integer;

Begin
    Layer := Polygon.Layer;
    ReportLog.Add('Modify Polygon: ''' + Polygon.Name + ''' on Layer ''' + Layer2String(Layer) + '''');

    BOL := Board.BoardOutline;
    PCBServer.PreProcess;
    Polygon.BeginModify;

    PolySeg := TPolySegment;
    Polygon.PointCount := BOL.PointCount;
    for I := 0 To (BOL.PointCount) Do
    begin
       PolySeg := BOL.Segments(I);
       Polygon.Segments(I) := PolySeg;
    end;

//    Polygon.SetState_CopperPourInvalid;
    Polygon.Rebuild;
//    Polygon.CopperPourValidate;
    Polygon.EndModify;

//    Polygon.FastSetState_XSizeYSize;
    Polygon.SetState_XSizeYSize;
    Polygon.BoundingRectangle;
//  required to get outline area to update!
    Polygon.GraphicallyInvalidate;
    PCBServer.PostProcess;
    Result := true;
End;

Function ModifyBoardOutlineFromPolygonOutline(const Polygon : IPCB_Polygon, var Board : IPCB_Board) : boolean;
Var
    PolySeg : TPolySegment;
    Layer   : TLayer;
    PNet    : IPCB_Net;
    I       : Integer;

Begin
    Layer := Polygon.Layer;
    ReportLog.Add('Modify Board outline : ' + Board.FileName);

    BOL := Board.BoardOutline;
    PCBServer.PreProcess;
    Board.BeginModify;
    BOL.BeginModify;

    PolySeg := TPolySegment;
    BOL.PointCount := Polygon.PointCount;
    For I := 0 To (Polygon.PointCount) Do
    Begin
// if .Segments[I].Kind = ePolySegmentLine then segment is a straight line.
       PolySeg := Polygon.Segments(I);
       BOL.Segments(I) := PolySeg;
    End;

    BOL.SetState_CopperPourInvalid;
    BOL.Rebuild;
    BOL.InValidate;
    BOL.EndModify;

    BOL.SetState_XSizeYSize;
//  required to get outline area to update ?
    BOL.GraphicallyInvalidate;

    Board.UpdateBoardOutline;
    Board.RebuildSplitBoardRegions(true);
    Board.EndModify;
    Board.GraphicallyInvalidate;
    PCBServer.PostProcess;
End;

{..............................................................................}
Procedure ModifyPolyOutline(const Clip : boolean);
Var
    PolyRegionKind  : TPolyRegionKind;
    Poly            : IPCB_Polygon;
    Prim            : IPCB_Primitive;

    FileName     : TPCBString;
    Document     : IServerDocument;

    PolyLayer    : TLayer;
//    MAString     : String;
    sMessage     : WideString;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

    BeginHourGlass(crHourGlass);
    ReportLog    := TStringList.Create;

    //Save the current Polygon repour setting
    RepourMode := PCBServer.SystemOptions.PolygonRepour;
// Update so that Polygons always repour - avoids polygon repour yes/no dialog box popping up.
    PCBServer.SystemOptions.PolygonRepour := eAlwaysRepour;

    Poly := nil;

    if Board.SelectecObjectCount > 0 then
    begin
        Prim := Board.SelectecObject(0);
        if Prim.ObjectId = ePolyObject then
            Poly := Prim;
    end;

    sMessage := 'Select polygon to refit to Board Outline';
    if Clip then sMessage := 'Select polygon to refit to Board Outline';

    if Poly = nil then
        Poly := Board.GetObjectAtCursor(MkSet(ePolyObject),SignalLayers, sMessage);

    if Poly <> nil then
    begin
        Poly.Selected := true;
        ReportLog.Add('Original Outline area : ' + SqrCoordToUnitString(Poly.AreaSize, 0, 7));

        if (not Clip)  then
            ModifyPolygonToBoardOutline(Poly)
        else
            ClipPolygonToBoardOutline(Poly);

        ReportLog.Add('Refitted Outline area : ' + SqrCoordToUnitString(Poly.AreaSize, 0, 7));
    end;

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);

    //Revert back to previous user polygon repour option.
    PCBServer.SystemOptions.PolygonRepour := RepourMode;

// test if PCB boardfile not saved.
    Filename := ExtractFilePath(Board.Filename);
    if Filename = '' then
        Filename := SpecialFolder_Temporary;

    FileName := Filename + ChangeFileExt(ExtractFileName(Board.FileName), '.txt');

    ReportLog.SaveToFile(Filename);
    ReportLog.Free;

    EndHourGlass;

    Document  := Client.OpenDocument('Text', FileName);
    If (bDisplay) and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

Procedure ModifyPolygonOutline;
begin
    ModifyPolyOutline(false);
end;

Procedure ClipPolygonOutline;
begin
    ModifyPolyOutline(true);
end;

{..............................................................................}
Procedure ModifyBoardOutline;
Var
    PolyRegionKind  : TPolyRegionKind;
    Poly            : IPCB_Polygon;
    Prim            : IPCB_Primitive;

    FileName     : TPCBString;
    Document     : IServerDocument;

    PolyLayer    : TLayer;
//    MAString     : String;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BeginHourGlass(crHourGlass);
    ReportLog    := TStringList.Create;

    //Save the current Polygon repour setting
    RepourMode := PCBServer.SystemOptions.PolygonRepour;
// Update so that Polygons always repour - avoids polygon repour yes/no dialog box popping up.
    PCBServer.SystemOptions.PolygonRepour := eAlwaysRepour;

    Poly := nil;

    if Board.SelectecObjectCount > 0 then
    begin
        Prim := Board.SelectecObject(0);
        if Prim.ObjectId = ePolyObject then
            Poly := Prim;
    end;

    if Poly = nil then
        Poly := Board.GetObjectAtCursor(MkSet(ePolyObject),AllLayers,'Select polygon to Change Board Outline');

    if Poly <> nil then
    begin
        Poly.Selected := true;
        ReportLog.Add('Original Board Outline area : ' + SqrCoordToUnitString(Board.BoardOutline.AreaSize, 0, 7));

        ModifyBoardOutlineFromPolygonOutline(Poly, Board);
        ReportLog.Add('Resized Board Outline area : ' + SqrCoordToUnitString(Board.BoardOutline.AreaSize, 0, 7));
    end;

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);

    //Revert back to previous user polygon repour option.
    PCBServer.SystemOptions.PolygonRepour := RepourMode;

// test if PCB boardfile not saved.
    Filename := ExtractFilePath(Board.Filename);
    if Filename = '' then
        Filename := SpecialFolder_Temporary;

    FileName := Filename + ChangeFileExt(ExtractFileName(Board.FileName), '.txt');

    ReportLog.SaveToFile(Filename);
    ReportLog.Free;

    EndHourGlass;

    Document  := Client.OpenDocument('Text', FileName);
    If (bDisplay) and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;


