{ PolygonAreas2.pas
  Reports polygon area & perimeters for outline & poured copper of all polygons in board.

from webpage
 https://techdocs.altium.com/display/SCRT/PCB+API+Design+Objects+Interfaces

 InternalUnits:
     InternalUnits = 10000;
 k1Inch:
     k1Inch = 1000 * InternalUnits;
Notes
1 mil = 10000 internal units
1 inch = 1000 mils
1 inch = 2.54 cm
1 inch = 25.4 mm and 1 cm = 10 mm

Default Contour ArcApprox = 5000 Coord = 0.5mil AD17

Author B.L. Miller
22/10/2019  v1.1 Added copper area & sub region & hole info
31/01/2020  v1.2 Bugfix: totalarea was not zeroed before reuse. Use board units.
17/01/2021  v1.3 iterating past vertexlist count.
17/01/2021  v1.4 Perimeter is FULL edge outline distance, tidy units mess.
29/09/2022  v1.5 fix perimeter as mils & fix bad sector length calc.
22/10/2022  v1.6 just report both mils & mm for all things.
23/10/2022  v1.7 use UnionBatchSet for combining contours.
}

Const
    bDebug = false;
    mmInch = 25.4;
    ArcResolution   = 0.02;  // min about 0.01 mils : impacts number of edges etc..

Var
    Rpt     : TStringList;
    Board   : IPCB_Board;
    BOrigin : TPoint;
    BUnits  : TUnit;
    LayerStack        : IPCB_LayerStack_V7;
    LayerObj_V7       : IPCB_LayerObject_V7;

function PolyHatchStyleToStr(HS : TPolyHatchStyle) : WideString; forward;
function RegionArea(Region : IPCB_Region) : Double; forward;
function GMPCArea(GMPC : IPCB_GeometricPolygon) : Double; forward;
function PolyHatchStyleToStr(HS : TPolyHatchStyle) : WideString; forward;
function ActualBUnits (const Invert : boolean) : TUnit; forward;
function PerimeterOutline (GP : IPCB_GeometricPolygon, const Full : boolean) : extended; forward;

Procedure PolygonsAreas;
Var
    Iterator   : IPCB_BoardIterator;
    GIter      : IPCB_GroupIterator;
    Prim       : IPCB_Primitive;
    ObjectID   : TObjectId;
    Polygon    : IPCB_Polygon;
    Region     : IPCB_Region;
//    Fill       : IPCB_Fill;
    PObjList   : TInterfaceList;
    PObjList2  : TInterfaceList;
    GMPC1      : IPCB_GeometricPolygon;
    GMPC2      : IPCB_GeometricPolygon;
    RegionVL   : Pgpc_vertex_list;

    PrimCount     : integer;
    TrackCount    : integer;
    ArcCount      : integer;
    CopperArea    : extended;
    TotalArea     : extended;
    CPerimeter    : extended;  // copper
    TotCPerimeter : extended;
    Length        : extended;
    Perimeter     : extended;
    TotPerimeter  : extended;
    LongLName     : WideString;

    FileName    : TPCBString;
    Document    : IServerDocument;
    PolyNo      : Integer;
    I,J,K,L     : Integer;
    X1,Y1,X2,Y2 : extended;
    A1, A2, A3  : extended;
    Radius      : TCoord;
    AnyTouch    : boolean;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BUnits  :=  ActualBUnits(true);

    BOrigin := Point(Board.XOrigin, Board.YOrigin);

    // Search for Polygons and for each polygon found
    // get its attributes and put them in a TStringList object
    // to be saved as a text file.
    PObjList := TInterfaceList.Create;

    PolyNo     := 0;
    Rpt := TStringList.Create;

    Rpt.Add(' Board Area size : ' + SqrCoordToUnitString(Board.BoardOutline.AreaSize, eMil, 1) ); // FloatToStr(Board.BoardOutline.AreaSize / SQR(k1Inch) + ' sq in'));
    Rpt.Add(' Board Area size : ' + SqrCoordToUnitString(Board.BoardOutline.AreaSize, eMM, 3) );  // FloatToStr(Board.BoardOutline.AreaSize / SQR(k1Inch) + ' sq in'));
    Rpt.Add('');

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePolyObject));
    Iterator.AddFilter_IPCB_LayerSet(LayerSet.AllLayers);       // alt. SignalLayers    ??
    Iterator.AddFilter_Method(eProcessAll);
    Polygon := Iterator.FirstPCBObject;

    While (Polygon <> Nil) Do
    Begin
        PObjList.Clear;

//  this makes NO difference to the ContourFactory result.
//        Polygon.ArcApproximation := MilsToCoord(ArcResolution);

        LayerStack  := Board.LayerStack_V7;
        LayerObj_V7 := LayerStack.LayerObject_V7[Polygon.Layer];
        LongLName   := LayerObj_V7.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

        Inc(PolyNo);
        Rpt.Add('Polygon No : '     + IntToStr(PolyNo));
        Rpt.Add(' Name : '          + Polygon.Name);
        Rpt.Add(' Detail : '        + Polygon.Detail);
        Rpt.Add(' Layer name  : '   + Board.LayerName(Polygon.Layer)  + ' | ID : ' + IntToStr(Polygon.Layer) );
        Rpt.Add(' Hatch Style : '   + PolyHatchStyleToStr(Polygon.PolyHatchStyle) );

        If Polygon.Net <> Nil Then
            Rpt.Add(' Net : '     + Polygon.Net.Name);

        If Polygon.PolygonType = eSignalLayerPolygon Then
            Rpt.Add(' Type : '     + 'Polygon on Signal Layer')
        Else
            Rpt.Add(' Type : '     + 'Split plane polygon');

        Rpt.Add(' BorderWidth : '  + CoordUnitToString(Polygon.BorderWidth ,BUnits) );

        Perimeter := 0.0;
        // Segments of a polygon
        For I := 0 To (Polygon.PointCount - 1) Do
        Begin
            J := I + 1;
            if (J = Polygon.PointCount) then J := 0;

            if Polygon.Segments[I].Kind = ePolySegmentLine then
            begin
                X1 := Polygon.Segments[I].vx;
                Y1 := Polygon.Segments[I].vy;
                Rpt.Add(' Segment Line X :  ' + PadLeft(CoordUnitToString(X1 - BOrigin.X, BUnits), 15) + '  Y : ' + PadLeft(CoordUnitToString(Y1 - BOrigin.Y, BUnits), 15) );

                X1 := Polygon.Segments[I].vx / k1Mil;   // hack to get float
                Y1 := Polygon.Segments[I].vy / k1Mil;
                X2 := Polygon.Segments[J].vx / k1Mil;
                Y2 := Polygon.Segments[J].vy / k1Mil;

                Length := (X2 - X1) * (X2 - X1);
                Length := Length + ( (Y2 - Y1) * (Y2 - Y1) );
                Length := SQRT( Length );
            end
            else begin
                X1 := Polygon.Segments[I].cx / k1Mil;  // hack to get float
                Y1 := Polygon.Segments[I].cy / k1Mil;
                A1 := Polygon.Segments[I].Angle1;
                A2 := Polygon.Segments[I].Angle2;
                if A1 = 360 then A1 :=0;
                if A2 = 360 then A2 :=0;
                A3 := A2 - A1;
                if A3 < 0 then A3 := - A3;
                Radius := Polygon.Segments[I].Radius;
                Length := Radius / k1Mil;
                Length := Length * c2PI * A3 / 360;

                Rpt.Add(' Segment Arc 1  : ' + FloatToStr(A1) );
                Rpt.Add(' Segment Arc 2  : ' + FloatToStr(A2) );
                Rpt.Add(' Segment Radius : ' + CoordUnitToString(Radius, BUnits) );
            End;

            Perimeter := Perimeter + Length;
        End;

        Rpt.Add(' Border Perimeter : ' +  CoordUnitToString(Perimeter * k1Mil, BUnits) );

        Rpt.Add('');
        PrimCount := Polygon.GetPrimitiveCount(AllObjects);
        Rpt.Add(' Prim (All types) Count : '  + IntToStr(PrimCount));

        TrackCount := 0;
        ArcCount   := 0;
        CopperArea := 0;
        TotalArea := 0;
        TotCPerimeter := 0;
        I := 0; J := 0;

        GIter := Polygon.GroupIterator_Create;
        if (Polygon.PolyHatchStyle = ePolySolid) then
        begin
            Prim     := GIter.FirstPCBObject;
            while Prim <> nil do
            begin
                Inc(I);
                Rpt.Add('    Prim ' + PadRight(IntToStr(I),3) +  '  type ' + Prim.ObjectIDString  );

                if Prim.ObjectId = eRegionObject then
                begin
                    Inc(J);
                    Region := Prim;
                    GMPC1 := Region.GeometricPolygon;
                    CopperArea := RegionArea(Region);
                    TotalArea := TotalArea + CopperArea;
                    TotCPerimeter := TotCPerimeter + PerimeterOutline(GMPC1, true);   //mils
                    Rpt.Add('  Region ' + IntToStr(J) + ' area ' + SqrCoordToUnitString(CopperArea, eMil) );
                    Rpt.Add('  Region ' + IntToStr(J) + ' area ' + SqrCoordToUnitString(CopperArea, eMM) );
                end;
                Prim := GIter.NextPCBObject;
            end;

        end
        else if (Polygon.PolyHatchStyle <> ePolyNoHatch) then
        begin
            Prim     := GIter.FirstPCBObject;
            while Prim <> nil do    // track or arc
            begin
                Inc(I);
                if bDebug then Rpt.Add('    Prim ' + PadRight(IntToStr(I),3) +  '  type ' + Prim.ObjectIDString  );
                if Prim.ObjectId = eTrackObject then inc(TrackCount);
                if Prim.ObjectId = eArcObject   then inc(ArcCount);
                if (Prim.ObjectId = eTrackObject) or (Prim.ObjectId = eArcObject) then
                begin
                    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcResolution));
                    GMPC1 := PcbServer.PCBContourMaker.MakeContour(Prim, 0, Polygon.Layer);  //GPG
                    PObjList.Add(GMPC1);
//                    Region := Prim;
                    Inc(J);
                end;
                Prim := GIter.NextPCBObject;
            end;

            if bDebug then Rpt.Add(' Shape GeoPoly Union ');

            if (PObjList.Count > 1) then  // was 0
            begin
                GMPC2 := PcbServer.PCBGeometricPolygonFactory;

// Alt. Method 2: use UnionBatchSet works in AD17 & AD22

                K := 0;
                while K < (PObjList.Count - 1) do
                begin

                    GMPC1 := PObjList.Items[K];
                    PObjList2 := TInterfaceList.Create;
                    PObjList2.Clear;
                    PObjList2.Add(GMPC1);

                    if bDebug then Rpt.Add(' GMPC1 : ' + IntToStr(K) + ' ' + IntTostr(GMPC1.Count) + ' ' + IntTostr(GMPC1.Contour(0).Count) );

                    L := 1;
                    while L < (PObjList.Count) do
                    begin
                        GMPC2 := PObjList.Items[L];

                        if (L <> K) and PcbServer.PCBContourUtilities.GeometricPolygonsTouch(GMPC1, GMPC2) then
                        begin
                            if bDebug then Rpt.Add('   touch : ' + IntToStr(K) + '.' + IntToStr(L) + ' ' + IntTostr(GMPC2.Count) + ' ' + IntTostr(GMPC2.Contour(0).Count) );
                            PObjList2.Add(GMPC2);
                            PObjList.Delete(L);

//                            if L >= (PObjList.Count) then
//                                L := K + 1;
                        end else
                            inc(L);
                    end;

                    if PObjList2.Count > 1 then
                    begin
                        PCBServer.PCBContourUtilities.UnionBatchSet(PObjList2, GMPC1);
                        PObjList.Items[K] := GMPC1;
                    end else
// if [K] has not changed then increment
                        inc(K);
               end;


// Alt. Method 1: original pair by pair union method.
{
                K := 0; L := 1;
                while K < (PObjList.Count - 1) and (K < L) do
                begin
                    GMPC1 := PObjList.Items[K];
                    GMPC2 := PObjList.Items[L];

                    if PcbServer.PCBContourUtilities.GeometricPolygonsTouch(GMPC1, GMPC2) then
                    begin                                         // Operation
                        PcbServer.PCBContourUtilities.ClipSetSet (eSetOperation_Union, GMPC1, GMPC2, GMPC1);

                        if bDebug then Rpt.Add('    touch : ' + IntToStr(K) + '.' + IntToStr(L) + ' ' + IntTostr(GMPC1.Count) + ' ' + IntTostr(GMPC1.Contour(0).Count) );
                        PObjList.Items(K) := GMPC1;
                        PObjList.Delete(L);          // inserting & deleting changes index of all object above
                        K := 0;                      // start again from beginning
                        L := 1;
                    end else
                    begin
                        if bDebug then Rpt.Add(' no touch : ' + IntToStr(K) + '.' + IntToStr(L) );
                        Inc(L);
                        if L >= (PObjList.Count) then
                        begin
                            inc(K);
                            L := K + 1;
                        end;
                    end;
                end;
                if bDebug then Rpt.Add('');
}
            end;

            Rpt.Add(' tracks ' + IntToStr(TrackCount) + ' ,   arcs ' + IntToStr(ArcCount) );

            for K := 0 to (PObjList.Count - 1) do
            begin
                GMPC1 := PObjList.Items[K];
                CopperArea := GMPC1.Area;    // copper region area.
//                CopperArea  := GMPCArea(GMPC1);
                TotalArea := TotalArea + CopperArea;
                TotCPerimeter := TotCPerimeter + PerimeterOutline(GMPC1, true);   //mils
                Rpt.Add('  Region ' + IntToStr(K+1) + ' area ' + SqrCoordToUnitString(CopperArea, eMil) );
                Rpt.Add('  Region ' + IntToStr(K+1) + ' area ' + SqrCoordToUnitString(CopperArea, eMM) );
            end;

        end
        else if Polygon.PolyHatchStyle = ePolyNoHatch then
        begin
 //           Area  := Polygon.GetState_AreaSize;
            CopperArea := 0;
        end;

        Polygon.GroupIterator_Destroy(GIter);

        Rpt.Add('');
        Rpt.Add(' Poly Area    : '    + SqrCoordToUnitString(Polygon.AreaSize, eMil) );      // FloatToStr(Polygon.AreaSize / SQR(k1Inch / mmInch) ));
        Rpt.Add(' Poly Area    : '    + SqrCoordToUnitString(Polygon.AreaSize, eMM) );       // FloatToStr(Polygon.AreaSize / SQR(k1Inch / mmInch) ));
        Rpt.Add(' Cu   Area    : '    + SqrCoordToUnitString(TotalArea, eMil) );             // FloatToStr(TotalArea / SQR(k1Inch / mmInch) ));
        Rpt.Add(' Cu   Area    : '    + SqrCoordToUnitString(TotalArea, eMM) );              // FloatToStr(TotalArea / SQR(k1Inch / mmInch) ));
        Rpt.Add(' Cu Perimeter : '    + CoordUnitToString(TotCPerimeter * k1Mil, BUnits) );  // FloatToStr(TotalArea / SQR(k1Inch / mmInch) ));

        Rpt.Add('');
        Rpt.Add('');
        Polygon := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);

    Rpt.Insert(0, 'Polygon Information for ' + ExtractFileName(Board.FileName) + ' document.');

    FileName := ChangeFileExt(Board.FileName,'.pol');
    Rpt.SaveToFile(Filename);
    Rpt.Free;

    // Display the Polygons report
    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

{----------------------------------------------------------------------------------------------------------------}
function RegionArea(Region : IPCB_Region) : Double;
var
   Area : Double;
   i    : Integer;
begin
  Area := Region.MainContour.Area;
 // Area := Region.Contour(0).Area;
  Rpt.Add('  HoleCount ' + IntToStr(Region.HoleCount) );
  for i := 0 to (Region.HoleCount - 1) do
     Area := Area - Region.Holes[i].Area;
  Result := Area;
end;

// returns same as GMPC.Area
function GMPCArea(GMPC : IPCB_GeometricPolygon) : Double;
var
    i    : Integer;
begin
    Result := 0;
    for i := 0 to (GMPC.Count - 1) do
    begin
        if GMPC.IsHole(i) then
            Result := Result - GMPC.Contour(i).Area
        else
            Result := Result + GMPC.Contour(i).Area;
    end;
end;

function PolyHatchStyleToStr(HS : TPolyHatchStyle) : WideString;
begin
    case HS of
    ePolyHatch90, ePolyHatch45, ePolyVHatch, ePolyHHatch :
                   Result := 'Hatched';
    ePolyNoHatch : Result := 'No Hatch';
    ePolySolid   : Result := 'Solid';
    else
        Result := '';
    end;
end;

function ActualBUnits (const Invert : boolean) : TUnit;
begin
    Result := Board.DisplayUnit;
// something very flaky around this property SqrCoordToUnit is wrong ??..
    if (Invert) then
    begin
        if (Result = eImperial) then Result := eMetric
        else Result := eImperial;
    end;
end;

// mils
function PerimeterOutline (GP : IPCB_GeometricPolygon, const Full : boolean) : extended;
var
    GPVL        : Pgpc_vertex_list;
    X1,Y1,X2,Y2 : extended;
    I, J, K     : integer;
    L           : extended;
begin
    Result := 0;
    GPVL := PcbServer.PCBContourFactory;
    I := GP.Count;
    while (I > 0) do
    begin
        dec(I);
        if ((GP.IsHole(I) = false) or Full) then
        begin
            GPVL := GP.Contour(I);
            for J:= 0 to (GPVL.Count - 1) do
            begin
                K := J + 1;
                if K = GPVL.Count then K := 0;
                X1 :=  GPVL.x(J) / k1Mil;
                Y1 :=  GPVL.y(J) / k1Mil;
                X2 :=  GPVL.x(K) / k1Mil;
                Y2 :=  GPVL.y(K) / k1Mil;
                L := Power(X2 -  X1, 2) + Power(Y2 -  Y1, 2);
                L := SQRT(L);     // / k1Mil;
                Result := Result + (L);
            end;
        end;
    end;
end;

