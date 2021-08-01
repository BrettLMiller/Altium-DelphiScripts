{..............................................................................
 RefPlaneRegion-fn-MakeRegionFromPoly.pas

Summary:

Make Region(s) from the solid copper of a Polygon 

A solid polygon is described by poly outline segments but rendered solid as region with arc approx etc.
Hatched polygon support needs to contour lines & arcs & merge (ClipContourContour).

B. Miller   Ver  Comment
12/12/2019  0.10 Function copied from RefPlaneRegion 0.25
07/08/2020  0.11 Updated fn to handle all possible "pieces" & contours (inc. holes) or just outline.
08/02/2021  0.12 Separate unconnected region contours, set masks, example. invert idea.
15/04/2021  0.13 Added Polygon function.

 ..............................................................................}

Var
   Board         : IPCB_Board;


function MakeRegionsFromPoly (Poly : IPCB_Polygon, const Expansion : TCoord, const Layer : TLayer, const RegKind : TRegionKind, const MainContour : boolean) : TObjectList;
var
    GIterator   : IPCB_GroupIterator;
    Region      : IPCB_Region;
    NewRegion   : IPCB_Region;
    GMPC, GMPC2 : IPCB_GeometricPolygon;
    CPOL        : TInterfaceList;
    Net         : IPCB_Net;
begin
   // PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(ArcResolution));    // control contour arc approx.
    Result := TObjectList.Create;
    CPOL   := CreateInterfaceList;
    Net    := Poly.Net;

    PCBServer.PreProcess;
//  poly can be composed of multiple regions
//  holes are extra contours in GeoPG
    GIterator  := Poly.GroupIterator_Create;
    Region := GIterator.FirstPCBObject;
    while Region <> nil do
    begin
     //   GMPC := Region.GeometricPolygon;
        GMPC2 := PcbServer.PCBContourMaker.MakeContour(Region, Expansion, Layer);
{
        if Invert then
        begin
            for I := 1 to (GMPC.Count - 1) do
                GMPC2.Addcontour(GMPC.Contour(I));
        end else
            GMPC2 := GMPC;
}
// split any unconnected contours (now not holes etc)
        PCBserver.PCBContourUtilities.SplitIntoConnectedPolygons(GMPC2, CPOL);
        for I := 0 to (CPOL.Count - 1) do
        begin
            GMPC := CPOL.Items[I];
            if GMPC.Count > 0 then
            begin
                NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
                PCBServer.SendMessageToRobots(NewRegion.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);

                if MainContour then
                    NewRegion.SetOutlineContour( GMPC.Contour(0) )
                else
                    NewRegion.GeometricPolygon := GMPC;

                NewRegion.SetState_Kind(RegKind);
                NewRegion.Layer := Layer;
                if Net <> Nil then NewRegion.Net := Net;
                NewRegion.SetState_SolderMaskExpansionMode (eMaskExpansionMode_NoMask);
                NewRegion.SetState_PasteMaskExpansionMode  (eMaskExpansionMode_NoMask);

                Board.AddPCBObject(NewRegion);
                PCBServer.SendMessageToRobots(NewRegion.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
                PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, NewRegion.I_ObjectAddress);
                Result.Add(NewRegion);
            end;
        end;
        CPOL.Clear;

        Region := GIterator.NextPCBObject;
    end;
    Poly.GroupIterator_Destroy(GIterator);
    PCBServer.PostProcess;
end;

Function AddPolygonToBoard(GPC : IPCB_GeometricPolygon; const PolygonName : WideString; PNet : IPCB_Net; Layer : TLayer) : IPCB_Polygon;
Var
    I       : Integer;
    GPCVL   : Pgpc_vertex_list;
    PolySeg : TPolySegment;

Begin
    ReportLog.Add('NewPolygon: ''' + PolygonName + ''' on Layer ''' + cLayerStrings[Layer] + '''');
    //Update so that Polygons always repour - avoids polygon repour yes/no dialog box popping up.
    PCBServer.SystemOptions.PolygonRepour := eAlwaysRepour;
    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(ePolyObject, eNoDimension, eCreate_Default);
//    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
    Result.Name                := PolygonName;
    Result.Layer               := Layer;
    Result.PolyHatchStyle      := ePolySolid;
    Result.RemoveIslandsByArea := False;
    Result.RemoveNarrowNecks   := True;
    Result.ArcApproximation    := MilsToCoord(0.5);
    Result.RemoveDead          := False;
    Result.PourOver            := ePolygonPourOver_SameNet;  //  ePolygonPourOver_SameNetPolygon;
    Result.AvoidObsticles      := True;
    Result.Net                 := PNet;

//  DNW
//    Result.Polygon := GPC.Replicate.Polygon;

    GPCVL := GPC.Contour(0);                   // refed to absolute
    Result.PointCount := GPCVL.Count;

    PolySeg := TPolySegment;
    for I := 0 to (GPCVL.Count) do       // loop to count
    begin
       PolySeg.Kind := ePolySegmentLine;
       PolySeg.vx   := GPCVL.x(I);
       PolySeg.vy   := GPCVL.y(I);
       Result.Segments[I] := PolySeg;
       ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
    end;

    Board.AddPCBObject(Result);
    Result.SetState_CopperPourInvalid;
    Result.Rebuild;
    Result.CopperPourValidate;

//    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
//    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
    PCBServer.PostProcess;
end;

{..............................................................................}


{

 eSetOperation_Union
 eSetOperation_Intersect  ??
 eSetOperation_Except ??

    PCBServer.PCBContourUtilities.ClipContourContour(eSetOperation_Union, incont1, inContour2, outgpc);
    PCBServer.PCBContourUtilities.ClipSetContour(eSetOperation_Union, ingpc, inContour, outgpc);
    PcbServer.PCBContourUtilities.ClipSetSet(eSetOperation_Union, ingpc, outgpc, outgpc);
    PointInRegion := PcbServer.PCBContourUtilities.PointInContour(RegContour.Contour(0), TargetX, TargetY);

IPCB_ContourMaker interface
Function MakeContour(APrim   : IPCB_Primitive; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(ATrack  : IPCB_Track    ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(APad    : IPCB_Pad      ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(AFill   : IPCB_Fill     ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(AVia    : IPCB_Via      ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(AArc    : IPCB_Arc      ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(ARegion : IPCB_Region   ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(AText   : IPCB_Text     ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;
Function MakeContour(APoly   : IPCB_Polygon  ; AExpansion : TCoord; ALayer : TLayer) : Pgpc_Polygon;



TPolyRegionKind = ( ePolyRegionKind_Copper,
                    ePolyRegionKind_Cutout,
                    ePolyRegionKind_NamedRegion);

TPolygonType = ( eSignalLayerPolygon,
                 eSplitPlanePolygon);

The segments property denotes the array of segments used to construct a polygon.
Each segment consists of a record consisting of one group of points in X, Y coordinates as a line (ePolySegmentline type)
 or an arc, a radius and two angles ( ePolySegmentArc type).
Each segment record has a Kind field which denotes the type of segment it is.

A segment of a polygon either as an arc or a track is encapsulated as a TPolySegment record as shown below;
TPolySegment = Record
      Kind      : TPolySegmentType;
//  Vertex
      vx,vy      : TCoord;
//  Arc
      cx,cy      : TCoord;
      Radius     : TCoord;
      Angle1     : TAngle;
      Angle2     : TAngle;
End;

{..............................................................................}
