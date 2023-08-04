{ PlanePolyTools.pas
   Deletes/replaces all plane outline primitives in Pcb.
       Editing can cause plane split & outline lines to end up on another layer!
       If run with selected object then only remove that & no auto-redraw

   CreateSignalLayerPolyCopy():
       For each InternalPlaneLayer
       Inserts new SignalLayer above BottomLayer with Polgyon & Poly-cutouts from SplitPlane

   CreateMechLayerCopy:
       outlines & net labels plane shapes. makes polys from splitplanes.

   CreatePlaneAntiRegion
       makes a region to fill the pullback & splitline space.

   CopyPlanePolyPlane
       copy Polygon or Region to make a Splitplane or SplitPlane to polygon
       Select polyregion primitive & then set current layer to target InternalPlane or Signal Layer
       Region (copper) copy will create anti-regions for any holes.
       To preserve the SplitPlane it must make an outline border,
       so create SplitPlane border with width of plane pull-back.

 Author: BL Miller
 23/11/2022  v0.1  POC delete selected object.
 12/04/2023  v0.2  copy plane to mech layer (+ve)
 29/05/2023  v0.21 report SplitPlane nets
 2023-07-10  v0.30 make mech copies & make SignalLayer poly from SplitPlanes.
 2023-07-13  v0.31 make "anti-region"s on plane layers
 2023-07-14  v0.32 copy selected poly & Splitplanes to Plane & Signal layers.
 2023-08-04  v0.33 allow region (copper) copy to Plane

Anti-Regions allows removal of split lines in AD17.
The built-in Poly grow function is NOT very robust, better with simple shape geometry.

//      eSplitPlanePolygon  returns childen ?.
//      eSplitPlaneObject   TSplitPlaneAdaptor child one Region

tbd: sub-stacks
     add polycuts on plane layers around via/pad to fix net clearances.
.............................................................................}
const
   AutoRedrawOutlines = true;          // redraw all plane outlines.
   StripAllOutlines   = true;          // remove outlines from all layers not just non-plane layers.
   cLineWidth         = 2;
   cTextHeight        = 16;
   cTextWidth         = 4;

   cPlaneMechLayer    = 51;       // + 15 layer target mechlayer for all internal plane copy
   cTempMechLayer1    = 102;       // temp scratchpad. creating region on plane layers is destructive.

function GetSplitPlaneObjs(Layer : TLayer, const ObjSet : TObjectSet) : TObjectList; forward;
function DrawPolyRegOutline(PolyRegion : IPCB_Region, Layer : TLayer, const LWidth : TCoord, const LText : WideString, const UIndex : integer) : TObjectList; forward;
function AddPolygonToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Polygon;      forward;
function AddRegionToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Region;        forward;
function AddSplitPlaneToBoard(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_SplitPlane; forward;
function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;                   forward;
function MaxBR(SBR, TBR : TCoordRect) : TCoordRect; forward;

var
    Board       : IPCB_Board;
    MLayerStack : IPCB_MasterLayerStack;
    LayerObj    : IPCB_LayerObject;
    PLayerSet   : IPCB_LayerSet;
    V7_Layer    : TPCB_V7_Layer;
    ReportLog   : TStringList;
    BOrigin     : TCoordPoint;

procedure CopyPlanePolyPlane;
var
    Prim       : IPCB_Primitive;
    NewPoly    : IPCB_Polygon;
    NewSPlane  : IPCB_SplitPlane;
    CLayer     : TLayer;
    LayerName  : WideString;
    PLayer     : TLayer;
    PLayerName : WideString;
    PPullDis   : TCoord;
    ANet       : IPCB_Net;
    NetName    : WideString;
    bIsPlane   : boolean;
    bIsSignal  : boolean;
    bWarning   : boolean;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;

    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    MLayerStack := Board.MasterLayerStack;

    if Board.SelectecObjectCount = 0 then exit;
    Prim := Board.SelectecObject(0);
    PLayer := Prim.Layer;
    LayerObj    := MLayerStack.LayerObject(PLayer);
    PLayerName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);

    CLayer      := Board.CurrentLayer;
    bIsPlane    := LayerUtils.IsInternalPlaneLayer(CLayer);
    bIsSignal   := LayerUtils.IsSignalLayer(CLayer);
    LayerObj    := MLayerStack.LayerObject(CLayer);
    LayerName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);

    bWarning := false;
    if bIsSignal and (Prim.ObjectId <> eSplitPlaneObject) then bWarning := true;
    if bIsPlane  and not ((Prim.ObjectId = ePolyObject) or (Prim.ObjectId = eRegionObject)) then bWarning := true;
    if bWarning then
        ShowMessage('select polyreg primitive & then set target layer as "current" ');

    ReportLog := TstringList.Create;
    Board.BeginModify;

    if bIsSignal then
    if Prim.ObjectID = eSplitPlaneObject then
    begin
        NewPoly := AddPolygonToBoard2(Prim, CLayer, true);
        NewPoly.BeginModify;
        NetName := 'no-net';
        ANet := Prim.Net;       // .InNet DNW
        if ANet <> nil then
        begin
            NewPoly.Net := ANet;
            NetName := ANet.Name;
        end;
        NewPoly.SetState_Name('Poly' + '_' + PLayerName + '_' + NetName);
        NewPoly.EndModify;
    end;

    if bIsPlane then
    if (Prim.ObjectID = ePolyObject) then
    begin
        PPullDis := LayerObj.PullBackDistance;
        NewPoly := Prim.Replicate;
        NewPoly.GrowPolyshape(PPullDis/2);
        DrawPolyRegOutline(NewPoly, CLayer, PPullDis, '', 0);

        NewSPlane := AddSplitPlaneToBoard(Prim, CLayer, true);
        NewSPlane.BeginModify;
        if Prim.Net <> nil then
            NewSPlane.Net := Prim.Net;
        NewSPlane.EndModify;
    end;

    if bIsPlane then
    if (Prim.ObjectID = eRegionObject) then
    begin
        PPullDis := LayerObj.PullBackDistance;
        NewPoly := AddPolygonToBoard2(Prim, CLayer, true);
        NewPoly.GrowPolyshape(PPullDis/2);
        DrawPolyRegOutline(NewPoly, CLayer, PPullDis, '', 0);
        Board.RemovePCBObject(NewPoly);
        PCBServer.DestroyPCBObject(NewPoly);

        NewSPlane := AddSplitPlaneToBoard(Prim, CLayer, false);
        NewSPlane.BeginModify;
        if Prim.Net <> nil then
            NewSPlane.Net := Prim.Net;
        NewSPlane.EndModify;
    end;

    Board.EndModify;
    Board.GraphicallyInvalidate;
end;

procedure CopyPlaneToNewPolySignalLayer;
var
    SignalLayer    : IPCB_LayerObject;
    LastELayer     : IPCB_LayerObject;
    SplitPrim      : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    Region         : IPCB_Region;
    NewRegion      : IPCB_Region;
    NewPoly        : IPCB_Polygon;
    PLayer         : TLayer;
    SLayer         : TLayer;
    PLayerName     : WideString;
    PNet           : IPCB_Net;
    NetName        : WideString;
    SPIndex        : integer;
    PObjSet        : TObjectSet;
    SplitPList     : TObjectList;
    I              : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

    MLayerStack := Board.MasterLayerStack;
    MLayerStack.SetState_LayerStackStyle(eLayerStackCustom);
    MLayerStack.SignalLayerCount;
    MLayerStack.LayersInStackCount;

    ReportLog := TstringList.Create;

    Board.BeginModify;

    LayerObj := MLayerStack.First(eLayerClass_InternalPlane);
    while LayerObj <> nil do                       //TInternalPlaneAdapter()
    begin
        V7_Layer   := LayerObj.V7_LayerID;
        PLayer     := V7_Layer.ID;

        SignalLayer := MLayerStack.FirstAvailableSignalLayer;
        LastELayer  := MLayerStack.Last(eLayerClass_Electrical);
        MLayerStack.InsertInStackAbove(LastELayer, SignalLayer);

        SLayer := SignalLayer.V7_LayerID.ID;
        Board.VisibleLayers.Include(SLayer);

// medium & short names are corrupted by layer shuffling
        PLayerName       := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);
        SignalLayer.Name := 'Signal-' + PLayerName;
        SignalLayer.IsDisplayed[Board] := true;

        PObjSet := MkSet(eSplitPlaneObject, eRegionObject, ePolyObject);
        SplitPList := GetSplitPlaneObjs(PLayer, PObjSet);

        SPIndex := 1;
        for I := 0 to (SplitPList.Count) -1 do
        begin
            SplitPrim := SplitPList.Items(I);

            if SplitPrim.ObjectID = eSplitPlaneObject then
            begin
                    SplitPlane := SplitPrim;

                    NewPoly := AddPolygonToBoard2(SplitPlane, SLayer, true);
                    NewPoly.BeginModify;
                    NetName := 'no-net';
                    PNet := SplitPlane.Net;     // .InNet DNW
                    if PNet <> nil then
                    begin
                        NewPoly.Net := PNet;
                        NetName := PNet.Name;
                    end;
                    NewPoly.SetState_Name('Poly-P'+ IntToStr(SPIndex) + '_' + PlayerName + '_SL'+ IntToStr(SLayer) + '_' + NetName);
                    NewPoly.EndModify;
            end;

// hand drawn region in plane.
            if SplitPrim.ObjectID = eRegionObject then
            begin
                Region := SplitPrim;
                if not Region.InPolygon then
                if Region.Kind = eRegionKind_Copper then
                begin
                    NewRegion:= Region.Replicate;
                    NewRegion.Polygon := nil;
                    Newregion.InPolygon := false;
                    NewRegion.Enabled_vPolygon := false;

                    NewRegion.SetState_Kind(eRegionKind_Cutout);
                    NewRegion.Layer := SLayer;
                    Board.AddPCBObject(NewRegion);
                end;
            end;
            inc(SPIndex);

        end;
        LayerObj := MLayerStack.Next(eLayerClass_InternalPlane, LayerObj);
    end;

    Board.EndModify;
    ReportLog.Free;
    Board.ViewManager_UpdateLayerTabs;
end;

procedure CreatePlaneAntiRegion;
var
    BOLine         : IPCB_BoardOutline;
    SplitPrim      : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    NewRegion      : IPCB_Region;
    PLayer         : TLayer;
    MLayer         : TLayer;
    PNet           : IPCB_Net;
    GMPC           : IPCB_GeometricPolygon;
    GMPC2          : IPCB_GeometricPolygon;
    WHole          : IPCB_Contour;
    PlaneIndex     : integer;
    SPIndex        : integer;
    I, J, K        : integer;
    UnionIndex     : integer;
    PObjSet        : TObjectSet;
    SplitPList     : TObjectList;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;

    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    BOLine := Board.BoardOutline;
    MLayerStack := Board.MasterLayerStack;

    MLayer := LayerUtils.MechanicalLayer(cTempMechLayer1);
    PObjSet := MkSet(eSplitPlaneObject);

    ReportLog := TstringList.Create;
    PlaneIndex := 0;

    LayerObj := MLayerStack.First(eLayerClass_InternalPlane);
    while LayerObj <> nil do                       //TInternalPlaneAdapter()
    begin
        inc(PlaneIndex);
        V7_Layer   := LayerObj.V7_LayerID;
        PLayer     := V7_Layer.ID;
//        UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);

// make Region from BOL
// if made on the Plane layer it destroys the SplitRegions.
        NewRegion := AddRegionToBoard2(BOLine, MLayer, true);
        NewRegion.BeginModify;

        SplitPList := GetSplitPlaneObjs(PLayer, PObjSet);

        for I := 0 to (SplitPList.Count - 1) do
        begin
            SplitPrim := SplitPList.Items(I);
            if SplitPrim.ObjectID <> eSplitPlaneObject then continue;
            SplitPlane := SplitPrim;

            SPIndex := 1;
// net property belongs to splitplane (polgon)
            PNet :=SplitPlane.Net;

            for J := 1 to SplitPlane.GetPrimitiveCount(MkSet(eRegionObject)) do
            begin
                SplitPlaneReg := SplitPlane.GetPrimitiveAt(J, eRegionObject);

                if SplitPlaneReg.Layer <> PLayer then continue;
                if SplitPlaneReg.Kind = eRegionKind_Cutout then continue;

// add contours of SplitPlaneregions as holes
                GMPC := SplitPlaneReg.GeometricPolygon.Replicate;

                GMPC2 := PCBServer.PCBGeometricPolygonFactory;
                for K := 0 to (GMPC.Count - 1) do
                begin
                    WHole := GMPC.Contour(K);
                    if not GMPC.IsHole(K) then
                        GMPC2.AddContour(WHole);
                end;

                NewRegion.GeometricPolygon.AddContourIsHole(GMPC2.Contour(0), True);
            end;

            inc(SPIndex);
        end;

        NewRegion.UpdateShapeFromContour;
//          NewRegion.UpdateContourFromShape(true);
        NewRegion.Layer := PLayer;
        NewRegion.EndModify;
        NewRegion.GraphicallyInvalidate;

        LayerObj := MLayerStack.Next(eLayerClass_InternalPlane, LayerObj);
    end;
end;

procedure CreateMechLayerPlaneCopy;
var
    SplitPrim      : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    NewRegion      : IPCB_Region;
    LText          : WideString;
    PLayer         : TLayer;
    MLayer         : TLayer;
    PNet           : IPCB_Net;
    PlaneIndex     : integer;
    SPIndex        : integer;
    I, J           : integer;
    UnionIndex     : integer;
    PObjSet        : TObjectSet;
    SplitPList     : TObjectList;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    MLayerStack := Board.MasterLayerStack;

    ReportLog := TstringList.Create;
    Layersetutils.NonEditableLayers.SerializeToString;

    PlaneIndex := 0;

    LayerObj := MLayerStack.First(eLayerClass_InternalPlane);
    while LayerObj <> nil do                       //TInternalPlaneAdapter()
    begin
        inc(PlaneIndex);
        V7_Layer := LayerObj.V7_LayerID;
        PLayer := V7_Layer.ID;

        UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);
        MLayer := LayerUtils.MechanicalLayer(cPlaneMechLayer + PlaneIndex - 1);
        LayerObj.PullBackDistance;

        PObjSet := MkSet(eSplitPlaneObject, eRegionObject, ePolyObject);
        SplitPList := GetSplitPlaneObjs(PLayer, PObjSet);

        for I := 0 to (SplitPList.Count - 1) do
        begin
            SplitPrim := SplitPList.Items(I);
// net property belongs to splitplane (polygon)   .InNet DNW
            PNet :=SplitPrim.Net;

            SPIndex := 1;

            LText := SplitPrim.Detail;
            if SplitPrim.ObjectID = eSplitPlaneObject then
                Ltext := SplitPrim.Descriptor;

            DrawPolyRegOutline(SplitPrim, MLayer, MilsToCoord(cLineWidth), LText, UnionIndex);

// hand drawn region in plane.
            if SplitPrim.ObjectID = eRegionObject then
            begin
//  outline is drawn by SplitPlane parent poly.
                if SplitPrim.InPolygon then
                    SplitPlaneReg := SplitPrim
                else
                begin
                    NewRegion:= SplitPrim.Replicate;
                    NewRegion.Polygon := nil;
                    NewRegion.InPolygon := false;
                    NewRegion.Enabled_vPolygon := false;
                    NewRegion.SetState_Kind(eRegionKind_Cutout);
                    NewRegion.Layer := MLayer;
                    NewRegion.UnionIndex := UnionIndex;
                    Board.AddPCBObject(NewRegion);
                end;
            end;

            if false then
            if (SplitPrim.ObjectID = ePolyObject) then
            begin
                NewRegion := SplitPrim.GetPrimitiveAt(1, eRegionObject);
                if NewRegion <> nil then
                begin
                    NewRegion.Polygon := nil;
                    Newregion.InPolygon := false;
                    NewRegion.Enabled_vPolygon := false;

                    NewRegion.SetState_Kind(eRegionKind_Copper);
                    NewRegion.Layer := MLayer;
                    NewRegion.UnionIndex := UnionIndex;
                    Board.AddPCBObject(NewRegion);
                end;
            end;

            if SplitPrim.ObjectID = eSplitPlaneObject then
            begin
                SplitPlane := SplitPrim;
                SplitPlane.GetPrimitiveCount(AllObjects);

                for J := 1 to SplitPlane.GetPrimitiveCount(MkSet(eRegionObject)) do
                begin
                    SplitPlaneReg := SplitPlane.GetPrimitiveAt(J, eRegionObject);
                    if SplitPlaneReg.Layer <> PLayer then continue;

                    SplitPlaneReg.Kind;
                    SplitPlaneReg.HoleCount;     // why zero? .Holes[i], where's the "plot" layer
                    SplitPlaneReg.Detail;
                    SplitPlaneReg.Enabled_vPolygon;
                    SplitPlaneReg.InPolygon;

                    NewRegion:= SplitPlaneReg.Replicate;
                    NewRegion.Polygon := nil;
                    Newregion.InPolygon := false;
                    NewRegion.Enabled_vPolygon := false;

                    NewRegion.SetState_Kind(eRegionKind_Copper);
                    NewRegion.Layer := MLayer;
                    NewRegion.UnionIndex := UnionIndex;
                    Board.AddPCBObject(NewRegion);
                end;
            end;

            inc(SPIndex);
        end;

        LayerObj := MLayerStack.Next(eLayerClass_InternalPlane, LayerObj);
    end;
end;

procedure ReportPlaneNets;
var
    BIter        : IPCB_BoardIterator;
    SubStack     : IPCB_LayerStack;
    SplitPlane   : IPCB_SplitPlane;
    SPRegion     : IPCB_SplitPlaneRegion;
    LayerObj     : IPCB_LayerObject;
    Layer        : TLayer;
    Net          : IPCB_Net;
    NetName      : WideString;
    Area         : extended;
    BrdPath      : WideString;
    I, J         : integer;
    PIndex       : integer;
    SPIndex      : integer;
    PObjSet      : TObjectSet;
    SplitPList   : TObjectList;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowMessage('not a Pcb document');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    MLayerStack := Board.MasterLayerStack;

    BrdPath     := ExtractFilePath(Board.FileName);
    if BrdPath = '' then BrdPath := 'c:\temp\';

    ReportLog := TStringList.Create;
    PObjSet   := MkSet(eSplitPlaneObject);

    for J := 0 to (MLayerStack.SubstackCount - 1) do
    begin
        SubStack := MLayerStack.SubStacks[J];
        LayerObj := SubStack.First(eLayerClass_InternalPlane);
        ReportLog.Add('Sub Stack ' + IntToStr(J + 1) + '  name: ' + SubStack.Name + '  ID: ' + SubStack.ID);
        ReportLog.Add('idx layerID short  long                   area                   desc.                    net');
        PIndex := 1;

        While (LayerObj <> Nil ) do
        begin
            V7_Layer := LayerObj.V7_LayerID;
            Layer    := V7_Layer.ID;
            SPIndex  := 1;

            SplitPList := GetSplitPlaneObjs(Layer, PObjSet);

            for I := 0 to (SplitPList.Count - 1) do
            begin
                SplitPlane := SplitPList.Items(I);

                SplitPlane.ObjectId;
                Layer := SplitPlane.Layer;
                Area := SplitPlane.AreaSize;
                NetName := 'no net';
                Net := SplitPlane.Net;
                if Net <> nil then                    // .InNet DNW with SplitPlanes!
                begin
                    NetName := Net.Name;
                end;
                ReportLog.Add(PadRight(IntToStr(PIndex),2) + ':' + PadRight(IntToStr(SPIndex),2) + ' Layer ' + IntToStr(Layer) + ':' + LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short) + ' ' +
                              Board.LayerName(Layer) + '  area: ' + SqrCoordToUnitString(Area, eMM, 2) + '  ' + SplitPlane.Descriptor + '  net: ' + NetName);

                inc(SPIndex);
            end;

            inc(PIndex);
            LayerObj := SubStack.Next(eLayerClass_InternalPlane, LayerObj);
        end;

        ReportLog.Add('');
    end;

    ReportLog.SaveToFile(BrdPath + 'plane-nets-report.txt');
    ReportLog.Free;
end;

Procedure DeleteSelectedItem;
Var
    Board             : IPCB_Board;
    BOLine            : IPCB_BoardOutline;
    Prim              : IPCB_Primitive;
    Polygon           : IPCB_Polygon;
    Layer             : TLayer;
    I                 : integer;
    DeleteList        : TObjectList;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowMessage('This is not a Pcb document');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

    Prim := Board.SelectecObject(0);
    if Prim <> nil then
    begin
        PCBServer.PreProcess;
        if Prim.Enabled_vPolygon and Prim.InPolygon then
        begin
            Polygon := Prim.Polygon;     //track on plane pullback TBoardOutlineAdaptor.
            Polygon.RemovePCBObject(Prim);
        end;
        Board.RemovePCBObject(Prim);
        PCBServer.DestroyPCBObject(Prim);
        PCBServer.PostProcess;
        exit;
    end;

// only trk/arc prims "in" the boardoutline are plane borders.

    DeleteList := TObjectList.Create;
    DeleteList.OwnsObjects := false;
    BOLine := Board.BoardOutline;
    PCBServer.PreProcess;

    for I := 1 to BOLine.GetPrimitiveCount(Mkset(eTrackObject)) do
    begin
        Prim := BOLine.GetPrimitiveAt(I, eTrackObject);

//        if Prim.Layer = eMultiLayer then continue;
        if not StripAllOutlines then
        begin
            if LayerUtils.IsInternalPlaneLayer(Prim.Layer) then continue;
            if LayerSetUtils.InternalPlaneLayers.Contains(Prim.Layer) then continue;
        end;
        DeleteList.Add(Prim);
    end;

    for I := 1 to BOLine.GetPrimitiveCount(Mkset(eArcObject)) do
    begin
        Prim := BOLine.GetPrimitiveAt(I, eArcObject);

//        if Prim.Layer = eMultiLayer then continue;
        if not StripAllOutlines then
        if LayerUtils.IsInternalPlaneLayer(Prim.Layer) then continue;

        DeleteList.Add(Prim);
    end;

    if StripAllOutlines then
        ShowMessage('found ' + IntToStr(DeleteList.Count) + ' polygon arc/track on any layer' )
    else
        ShowMessage('found ' + IntToStr(DeleteList.Count) + ' rogue polygon arc/track not on plane layers' );

    for I := 0 to DeleteList.Count - 1 do
    begin
        Prim := DeleteList.Items(I);
        Polygon := Prim.Polygon;
        if AutoRedrawOutlines then
            Polygon.BeginModify;
        Polygon.RemovePCBObject(Prim);
        if AutoRedrawOutlines then
            Polygon.EndModify;
//        Polygon.GraphicallyInvalidate;
        Board.InvalidatePlane(Prim.Layer);  // LayerObj.LayerID);

        Board.RemovePCBObject(Prim);
        PCBServer.DestroyPCBObject(Prim);
    end;
    DeleteList.Clear;

    PCBServer.PostProcess;

    Board.ValidateInvalidPlanes;
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
End;
{..............................................................................}

function GetSplitPlaneObjs(Layer : TLayer, const ObjSet : TObjectSet) : TObjectList;
var
    PlaneIter   : IPCB_BoardIterator;
    SplitPrim   : IPCB_Primitive;
    LayerSet    : IPCB_LayerSet;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    LayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);
    PlaneIter := Board.BoardIterator_Create;
    PlaneIter.AddFilter_ObjectSet(ObjSet);
    PlaneIter.AddFilter_IPCB_LayerSet(LayerSet);

    SplitPrim := PlaneIter.FirstPCBObject;
    while (SplitPrim <> Nil) Do
    begin
        Result.Add(SplitPrim);
        SplitPrim := PlaneIter.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(PlaneIter);
end;

function DrawPolyRegOutline(PolyRegion : IPCB_Region, Layer : TLayer, const LWidth : Tcoord, LText : WideString, UIndex : integer) : TObjectList;
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
    MaxSBR   : TCoordRect;
    Location : TCoordPoint;
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
    if PolyRegion.ObjectID = eSplitPlaneObject                    then IsPoly := true;
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
            Track.Width := LWidth;
            Track.Layer := Layer;
            Track.x1 := PolySeg1.vx; // + RefP.X - BR.x1;
            Track.y1 := PolySeg1.vy;
            Track.x2 := PolySeg2.vx; 
            Track.y2 := PolySeg2.vy; 
            Track.UnionIndex := UIndex;

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
            Arc.LineWidth := LWidth;
            Arc.Radius     := PolySeg1.Radius;
            Arc.XCenter    := PolySeg1.cx;      // + RefP.X - BR.x1;
            Arc.YCenter    := PolySeg1.cy;
            Arc.StartAngle := PolySeg1.Angle1;
            Arc.EndAngle   := PolySeg1.Angle2;
            Arc.UnionIndex := UIndex;      // no point in PcbLib.

            Board.AddPCBObject(Arc);
            PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
            Result.Add(Arc);
            SBR := Arc.BoundingRectangle;
            MaxSBR := MaxBR(MaxSBR, SBR);
        end;
    end;

    if LText <> '' then
    begin
        Location := Point(MaxSBR.X1 + RectWidth(MaxSBR) / 2, MaxSBR.Y1 + RectHeight(MaxSBR) / 2);
        AddText(LText, Location, Layer, UIndex);
    end;
end;

Function AddRegionToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Region;
Var
    I          : Integer;
    GPC        : IPCB_GeometricPolygon;
    GPCVL      : Pgpc_vertex_list;  //Contour
    PolySeg    : TPolySegment;
    SegCount   : integer;
    UnionIndex : Integer;
    IsPoly   : boolean;

Begin
//    UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);

    IsPoly := false;
    if PolyRegion.ViewableObjectID = eViewableObject_BoardOutline then IsPoly := true;
    if PolyRegion.ViewableObjectID = eViewableObject_Poly         then IsPoly := true;
    if PolyRegion.ObjectID         = eSplitPlaneObject            then IsPoly := true;

    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    Result.Layer      := Layer;
    Result.Kind       := eRegionKind_Copper;
//    Result.UnionIndex := UnionIndex;
    if PolyRegion.InNet then
        Result.Net             := PolyRegion.Net;

    PolySeg := TPolySegment;
    if IsPoly  then
        SegCount := PolyRegion.PointCount
    else
        SegCount := PolyRegion.ShapeSegmentCount;

    if SegCount > 0 then
    begin
        Result.ShapeSegmentCount := SegCount;
        for I := 0 to (SegCount - 0) do
        begin

            if IsPoly then
                PolySeg := PolyRegion.Segments(I)
            else
                PolySeg := PolyRegion.ShapeSegments(I);

            Result.ShapeSegments(I) := PolySeg;
            ReportLog.Add(IntToStr(PolySeg.Kind) + ' ' + CoordUnitToString(PolySeg.vx - BOrigin.X ,eMils) + '  ' + CoordUnitToString(PolySeg.vy - BOrigin.Y, eMils) );
        end;
        Result.UpdateContourFromShape(true);
    end
    else
    begin
        GPCVL := PolyRegion.MainContour;
        Result.ShapeSegmentCount := GPCVL.Count;
        PolySeg.Kind := ePolySegmentLine;
        for I := 0 to (GPCVL.Count) do     // loop to count
        begin
            PolySeg.vx   := GPCVL.x(I);
            PolySeg.vy   := GPCVL.y(I);
            Result.ShapeSegments(I) := PolySeg;
            ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
        end;
    end;

// add holes
    if (not IsPoly) and (not MainContour) then
    begin
        GPC := PolyRegion.GeometricPolygon;
        for I := 0 to (GPC.Count - 1) do
        begin
            if GPC.IsHole(I) then
            begin
                GPCVL := GPC.Contour(I);
                Result.GeometricPolygon.AddContourIsHole(GPCVL, True);
            end;
        end;
    end;

    Board.AddPCBObject(Result);
    Result.GraphicallyInvalidate;
    PCBServer.PostProcess;
end;

Function AddPolygonToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Polygon;
Var
    I          : Integer;
    NewReg     : IPCB_Region;
    Poly       : IPCB_Polygon;
    GPC        : IPCB_GeometricPolygon;
    GPCVL      : Pgpc_vertex_list;  //Contour
    PolySeg    : TPolySegment;
    SegCount   : integer;
    UnionIndex : Integer;
    IsPoly     : boolean;
    RepourMode : TPolygonRepourMode;
Begin
    UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);

    IsPoly := false;
    if PolyRegion.ViewableObjectID = eViewableObject_BoardOutline then IsPoly := true;
    if PolyRegion.ViewableObjectID = eViewableObject_Poly         then IsPoly := true;
    if PolyRegion.ObjectID         = eSplitPlaneObject            then IsPoly := true;

    //Update so that Polygons always repour - avoids polygon repour yes/no dialog box popping up.
    RepourMode := PCBServer.SystemOptions.PolygonRepour;
    PCBServer.SystemOptions.PolygonRepour := eAlwaysRepour;

    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(ePolyObject, eNoDimension, eCreate_Default);
//    Result.Name                := PolygonName;
    Result.Layer               := Layer;
    Result.PolyHatchStyle      := ePolySolid;
    Result.RemoveIslandsByArea := False;
    Result.RemoveNarrowNecks   := True;
    Result.ArcApproximation    := MilsToCoord(0.5);
    Result.RemoveDead          := False;
    Result.PourOver            := ePolygonPourOver_SameNet;  //  ePolygonPourOver_SameNetPolygon;
    Result.AvoidObsticles      := True;
    if PolyRegion.InNet then
        Result.Net             := PolyRegion.Net;

    PolySeg := TPolySegment;
    if IsPoly  then
        SegCount := PolyRegion.PointCount
    else
        SegCount := PolyRegion.ShapeSegmentCount;

    if SegCount > 0 then
    begin
        Result.PointCount := SegCount;
        for I := 0 to (SegCount - 0) do
        begin

            if IsPoly then
                PolySeg := PolyRegion.Segments(I)
            else
                PolySeg := PolyRegion.ShapeSegments(I);

            Result.Segments(I) := PolySeg;
            ReportLog.Add(IntToStr(PolySeg.Kind) + ' ' + CoordUnitToString(PolySeg.vx - BOrigin.X ,eMils) + '  ' + CoordUnitToString(PolySeg.vy - BOrigin.Y, eMils) );
        end;
    end
    else
    begin
        GPCVL := PolyRegion.MainContour;
        Result.PointCount := GPCVL.Count;
        PolySeg.Kind := ePolySegmentLine;
        for I := 0 to (GPCVL.Count) do     // loop to count
        begin
            PolySeg.vx         := GPCVL.x(I);
            PolySeg.vy         := GPCVL.y(I);
            Result.Segments(I) := PolySeg;
            ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
        end;
    end;

// add cutouts
    if (not IsPoly) and (not MainContour) then
    begin
        GPC := PolyRegion.GeometricPolygon;
        Result.UnionIndex := UnionIndex;
        for I := 0 to (GPC.Count - 1) do
        begin
            if GPC.IsHole(I) then
            begin
                GPCVL  := GPC.Contour(I);
                NewReg := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
                NewReg.SetOutlineContour(GPCVL);
                NewReg.SetState_Kind(ePolyRegionKind_Cutout);
                NewReg.Layer := Layer;
                NewReg.UnionIndex := UnionIndex;
                Board.AddPCBObject(NewReg);
            end;
        end;
    end;

    Board.AddPCBObject(Result);
    Result.Rebuild;
    Result.GraphicallyInvalidate;
    PCBServer.PostProcess;
    PCBServer.SystemOptions.PolygonRepour := RepourMode;
end;

Function AddSplitPlaneToBoard(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_SplitPlane;
Var
    I          : Integer;
    NewRegion  : IPCB_Region;
    Poly       : IPCB_Polygon;
    GPC        : IPCB_GeometricPolygon;
    GPCVL      : Pgpc_vertex_list;  //Contour
    PolySeg    : TPolySegment;
    SegCount   : integer;
    UnionIndex : Integer;
    IsPoly     : boolean;

Begin
//    UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);

    IsPoly := false;
    if PolyRegion.ViewableObjectID = eViewableObject_BoardOutline then IsPoly := true;
    if PolyRegion.ViewableObjectID = eViewableObject_Poly         then IsPoly := true;
    if PolyRegion.ObjectID         = eSplitPlaneObject            then IsPoly := true;

    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eSplitPlaneObject, eNoDimension, eCreate_Default);
    Result.Layer := Layer;

    if PolyRegion.InNet then
        Result.Net := PolyRegion.Net;

    PolySeg := TPolySegment;
    if IsPoly  then
        SegCount := PolyRegion.PointCount
    else
        SegCount := PolyRegion.ShapeSegmentCount;

    if SegCount > 0 then
    begin
        Result.PointCount := SegCount;
        for I := 0 to (SegCount - 0) do
        begin

            if IsPoly then
                PolySeg := PolyRegion.Segments(I)
            else
                PolySeg := PolyRegion.ShapeSegments(I);

            Result.Segments(I) := PolySeg;
            ReportLog.Add(IntToStr(PolySeg.Kind) + ' ' + CoordUnitToString(PolySeg.vx - BOrigin.X ,eMils) + '  ' + CoordUnitToString(PolySeg.vy - BOrigin.Y, eMils) );
        end;
    end
    else
    begin
        GPCVL := PolyRegion.MainContour;
        Result.PointCount := GPCVL.Count;
        PolySeg.Kind      := ePolySegmentLine;
        for I := 0 to (GPCVL.Count) do     // loop to count
        begin
            PolySeg.vx         := GPCVL.x(I);
            PolySeg.vy         := GPCVL.y(I);
            Result.Segments(I) := PolySeg;
            ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
        end;
    end;

// do need to make copper region same as poly & add holes to that?
// plane poly with region holes just get wiped out.. need make region cutouts.

// add cutouts
    if (not IsPoly) and (not MainContour) then
    begin
        GPC := PolyRegion.GeometricPolygon;
        for I := 0 to (GPC.Count - 1) do
        begin
            if GPC.IsHole(I) then
            begin
                GPCVL := GPC.Contour(I);
                NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
                NewRegion.SetOutlineContour(GPCVL);
                NewRegion.SetState_Kind(eRegionKind_Cutout);
                NewRegion.Layer := Layer;
               Board.AddPCBObject(NewRegion);
            end;
        end;
    end;

// add after regions? so plane redraw pours around them
    Board.AddPCBObject(Result);
    Result.GraphicallyInvalidate;
    Board.InvalidatePlane(Layer);
    PCBServer.PostProcess;
end;

function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;
var
    BR : TCoordRect;
begin
    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);

    Result.Layer      := Layer;
//    Result.IsHidden := false;
    Result.UseTTFonts := false;
    Result.UnderlyingString  := NewText;
    Result.Size       := MilsToCoord(cTextHeight);
    Result.Width      := MilsToCoord(cTextWidth);
    BR := Result.BoundingRectangle;
    Result.XLocation  := Location.X - RectWidth(BR) /2;
    Result.YLocation  := Location.Y - RectHeight(BR) /2;
    Result.UnionIndex := UIndex;

    Board.AddPCBObject(Result);           // each board is the FP in library
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
    PCBServer.PostProcess;
end;

function MaxBR(SBR, TBR : TCoordRect) : TCoordRect;
begin
    Result := TCoordRect;
    Result.X1 := Min(TBR.X1, SBR.X1);
    Result.X2 := Max(TBR.X2, SBR.X2);
    Result.Y1 := Min(TBR.Y1, SBR.Y1);
    Result.Y2 := Max(TBR.Y2, SBR.Y2);
end;

