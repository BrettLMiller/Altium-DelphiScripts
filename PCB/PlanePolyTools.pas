{ PlanePolyTools.pas
   Deletes/replaces all plane outline primitives in Pcb.
       Editing can cause plane split & outline lines to end up on another layer!
       If run with selected object then only remove that & no auto-redraw

   CreateSignalLayerPolyCopy():
       For each InternalPlaneLayer
       Inserts new SignalLayer above BottomLayer with Polgyon & Poly-cutouts from SplitPlane

   CreateMechLayerCopy:
       outlines & net labels plane shapes. makes polys from splitplanes.
       Run MakePlaneNetClearance first to get (any) relief structures

   CreatePlaneAntiRegion
       makes a region to fill the pullback & splitline space(s).

   CopyPlanePolyPlane
       copy Polygon or Region to make a Splitplane or SplitPlane to polygon
       Select polyregion primitive & then set current layer to target InternalPlane or Signal Layer
       Region (copper) copy will create anti-regions for any holes.
       To preserve the SplitPlane it must make an outline border,
       so create SplitPlane border with width of plane pull-back.

   Make/DRCPlaneNetClearance
       Apply Elect Clearance rules to SplitPlane & Nets with DRC Rule like:
         Scope1 = OnLayer('Internal Plane 1') and  IsRegion and InNet('GND')
         Scope2 = Net = 'NewNet'
       Make region cutouts (anti-pads) around pad/via to pass DRC.

   CreateBlindViaPlanePads
       Makes pad on (unconnected) InternalPlane StopLayer to allow hole plating & strengthen outer pad/via
       and allow stacked microvias.
       Makes true Net & class clearance like MakeDRCPlaneNetClearance
       Adds clearance ring (from Rules) & adds splitplane "Pad" with assigned net same size as Via start layer.
       Recommend user to use PlaneConnectStyle rule for microvia drillpair to avoid silly unconnected spokes.

 Author: BL Miller
 23/11/2022  v0.1  POC delete selected object.
 12/04/2023  v0.2  copy plane to mech layer (+ve)
 29/05/2023  v0.21 report SplitPlane nets
 2023-07-10  v0.30 make mech copies & make SignalLayer poly from SplitPlanes.
 2023-07-13  v0.31 make "anti-region"s on plane layers
 2023-07-14  v0.32 copy selected poly & Splitplanes to Plane & Signal layers.
 2023-08-04  v0.33 allow region (copper) copy to Plane
 2023-08-06  v0.34 add DRC check for nets & SplitPlanes
 2023-09-18  v0.35 add PlanePads for microvia terminating (short antenna via) in InternalPlane.
 2023-09-18  v0.36 fix stacked microvias, allow splitplane to be set "No Net".
 2024-03-20  v0.37 fix one of the clearance rule checks for MakePlaneNetClearance anti-pads
 2024-04-06  v0.38 fix MakePlaneClearance work for each layer & stop excessive duplicates. Tidy MechLayerCopy

Anti-Regions allows removal of split lines in AD17.
The built-in Poly grow function is NOT very robust, better with simple shape geometry.

AD21.7 ?? added splitplane open-beta options for via anti-pad & polygon-like repouring

Basically useless fn:
  Board.GetVoidsOnPlaneLayer(Layer); not in AD17
  SplitPlane.GetNegativeRegion       not in AD17

   eSplitPlanePolygon  returns childen ?.
   eSplitPlaneObject   TSplitPlaneAdaptor child one Region

TBD:
   still some duplicate polycutouts in MakePlaneNetClearance
   sub-stacks
   Blind Via pads on plane layers.


info:
Board.GetState_SplitPlaneNets(NetsList : TStringList);  speed up?
Board.GetState_AutomaticSplitPlanes;
Pad.PlaneConnectionStyleForLayer(ALayer : TLayer) : TPlaneConnectionStyle;
Polygon/SplitPlane.GetState_HitPrimitive;
                    // vv- Protel 99 SE style with Typo!
TPlaneDrawMode = ( ePlaneDrawoOutlineLayerColoured , ePlaneDrawOutlineNetColoured, ePlaneDrawInvertedNetColoured);

.............................................................................}
const
   AutoRedrawOutlines = true;          // redraw all plane outlines.
   StripAllOutlines   = true;          // remove outlines from all layers not just non-plane layers.
   cLineWidth         = 2;
   cTextHeight        = 16;
   cTextWidth         = 4;
   cNoNetName         = 'no-net';
   eSections          = 4;
   cArcResolution     = 0.01;    // mils: impacts number of edges etc..

   cPlaneMechLayer    = 21;       // + 15 layer target mechlayer for all internal plane copy
   cTempMechLayer1    = 32;       // temp scratchpad. creating region on plane layers is destructive.

var
    Board       : IPCB_Board;
    MLayerStack : IPCB_MasterLayerStack;
    LayerObj    : IPCB_LayerObject;
    PLayerSet   : IPCB_LayerSet;
    V7_Layer    : TPCB_V7_Layer;
    ReportLog   : TStringList;
    BOrigin     : TCoordPoint;
    VerMajor    : integer;

function DrawPolyRegOutline(PolyRegion : IPCB_Region, Layer : TLayer, const LWidth : TCoord, const LText : WideString, const UIndex : integer) : TObjectList; forward;
function AddPolygonToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Polygon;      forward;
function AddRegionToBoard2(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_Region;        forward;
function AddSplitPlaneToBoard(PolyRegion : IPCB_Region, const Layer : TLayer, const MainContour : boolean) : IPCB_SplitPlane; forward;
function AddText(NewText : WideString; Location : TLocation, Layer : TLayer, UIndex : integer) : IPCB_Text;                   forward;
function AddPlanePad(AVia : IPCB_Via, PLayer : TLayer, MoreClear : TCoord) : IPCB_SplitPlane; forward;
function AddAntiRing(AVia : IPCB_Via, PLayer : TLayer, MoreClear : TCoord) : IPCB_Arc;        forward;
function MaxBR(SBR, TBR : TCoordRect) : TCoordRect; forward;
function CheckPrimClear(Board : IPCB_Board, Prim : IPCB_Primitive, SPL : IPCB_SplitPlane, const Violate : boolean) : TCoord;  forward;
function AddMoreClear(Prim : IPCB_Primitive, const Layer : TLayer, Expand : TCoord) : IPCB_Region;         forward;
function MakeViolation(Rule : IPCB_Rule, Prim1 : IPCB_Primitive, Prim2 : IPCB_Primitive) : IPCB_Violation; forward;
function GetSplitPlaneObjs(Layer : TLayer, const ObjSet : TObjectSet) : TObjectList; forward;
function GetSpatialObjs(RBox : TCoordRect, Layer : TLayer, const ObjSet : TObjectSet) : TObjectList; forward;
procedure PlaneNetClearances(const Make : boolean); forward;

// seems does nothing to SplitPlanes.
// plane view options now in ViewConfig?.
procedure ChangePlaneDrawMode;
var
   DrawMode : TPlaneDrawMode;
   SysOpts  : IPCB_SystemOptions;
begin
    SysOpts  := PCBServer.SystemOptions;
    DrawMode := SysOpts.PlaneDrawMode;
    case DrawMode of
      ePlaneDrawoOutlineLayerColoured : DrawMode := ePlaneDrawOutlineNetColoured;
//      ePlaneDrawOutlineNetColoured    : DrawMode := ePlaneDrawInvertedNetColoured;
//      ePlaneDrawInvertedNetColoured   : DrawMode := ePlaneDrawOutlineNetColoured;
      ePlaneDrawOutlineNetColoured   : DrawMode := ePlaneDrawoOutlineLayerColoured;
    end;
    SysOpts.SetState_PlaneDrawMode(DrawMode);
    Board := PCBServer.GetCurrentPCBBoard;
    Board.RebuildSplitBoardRegions(true);
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
// dnw
    Board.SetState_ViewConfigFromString('Plane Drawing', 'Solid Net Colored');

    Board.GetState_ViewConfigAsString('Plane Drawing Mode', DrawMode);

//dnw
    Client.SendMessage('PCB:SetupPreferences', 'PlaneDrawingMode = Solid Net Colored', 512, Client.CurrentView);
end;

procedure BlindViaPlanePad;
var
    Iter           : IPCB_BoardIterator;
    SplitPlane     : IPCB_SplitPlane;
    SplitPList     : TObjectList;
    NewSplitPList  : TObjectList;
    AVia           : IPCB_Via;
    ShapeLayer     : TLayer;
    NewSP          : IPCB_Region;
    UnionIndex     : Integer;

    PObjSet      : TObjectSet;
    PLayer       : TLayer;
    I            : integer;
    MoreClear    : TCoord;
    VAD          : TCoord;
    VRect        : TCoordRect;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;

    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    MLayerStack := Board.MasterLayerStack;
    UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));

    ReportLog := TStringList.Create;
    Board.BeginModify;

    NewSplitPList := TObjectList.Create;
    NewSplitPList.OwnsObjects := false;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.IncludeSignalLayers;
    PLayerSet.IncludeInternalPlaneLayers;
    PLayerSet.Include(eMultiLayer);
    Iter := Board.BoardIterator_Create;
    Iter.AddFilter_ObjectSet(MkSet(eViaObject));
    Iter.AddFilter_IPCB_LayerSet(PLayerSet);

    LayerObj := MLayerStack.First(eLayerClass_InternalPlane);
    while LayerObj <> nil do
    begin
        V7_Layer   := LayerObj.V7_LayerID;
        PLayer     := V7_Layer.ID;

// static list from each internal plane layer
        PObjSet := MkSet(eSplitPlaneObject);

        AVia := Iter.FirstPCBObject;
        while (AVia <> nil) do
        begin
            SplitPList := GetSplitPlaneObjs(PLayer, PObjSet);
            for I := 0 to (SplitPList.Count - 1) do
            begin
                SplitPlane := SplitPList.Items(I);

                if NewSplitPList.Indexof(SplitPlane) > -1 then continue;
                if SplitPlane.Net = AVia.Net then continue;
// limit repeats of Anti-Ring
                if Not SplitPlane.PointInPolygon(AVia.x, AVia.y) then continue;

                MoreClear := -1;
                if AVia.StopLayer = LayerObj then
                begin
                    ShapeLayer := AVia.StartLayer.V7_LayerID.ID;
                    MoreClear := CheckPrimClear(Board, AVia, SplitPlane, false);
                end;

                VAD := AVia.SizeOnLayer(AVia.StartLayer.V7_LayerID.ID);

// need to add SplitPlaneRegion for each "pad" to set Region net? or just ring?
// MoreClear = -1 for same net & in SplitPlane: no ring required.
// only add split ring if net not same as SP region.
                if (MoreClear >= 0) then
                begin
// MoreClear internalplane calculated on hole & with NO annular ring
                    if (MoreClear = 0) then MoreClear := (VAD - AVia.HoleSize) / 2;

                    AddAntiRing(AVia, PLayer, MoreClear);

                    NewSP := AddPlanePad(AVia, PLayer, MoreClear);
                    NewSP.BeginModify;
                    NewSP.UnionIndex := UnionIndex;
                    if AVia.Net <> nil then
                        NewSP.Net := AVia.Net;
                    NewSP.EndModify;
                    NewSplitPList.Add(NewSP);

                    SplitPlane.GraphicallyInvalidate;
                    Board.RebuildSplitBoardRegions(false);
                end;
            end;

            SplitPList.Clear;
            AVia := Iter.NextPCBObject;
        end;

        Board.InvalidatePlane(PLayer);
        Board.RebuildSplitBoardRegions(false);

        LayerObj := MLayerStack.Next(eLayerClass_InternalPlane, LayerObj);
    end;

    Board.BoardIterator_Destroy(Iter);
    Board.EndModify;
    Board.RebuildSplitBoardRegions(true);
    Board.ValidateInvalidPlanes;
    NewSplitPList.Clear;
    ReportLog.Free;
end;

function AddAntiRing(AVia : IPCB_Via, PLayer : TLayer, MoreClear : TCoord) : IPCB_Arc;
var
    AArc        : IPCB_Arc;
    VAD         : TCoord;
begin
    Result := nil;

    VAD := AVia.SizeOnLayer(AVia.StartLayer.V7_LayerID.ID);

    Result := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    Result.XCenter := AVia.x;
    Result.YCenter := AVia.y;
    Result.Radius := (VAD + MoreClear) / 2;
    Result.LineWidth := MoreClear;
    Result.StartAngle := 0;
    Result.EndAngle := 360;
    Result.Layer := PLayer;
    Board.AddPCBObject(Result);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
end;

function AddPlanePad(AVia : IPCB_Via, PLayer : TLayer, MoreClear : TCoord) : IPCB_SplitPlane;
var
    NewRegion   : IPCB_Region;
    PolySeg     : TPolySegment;
    VAD         : TCoord;
    X, Y        : extended;
    theta       : extended;
    SegCount    : integer;
    I           : integer;

begin
    VAD := AVia.SizeOnLayer(AVia.StartLayer.V7_LayerID.ID);

    NewRegion       := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    NewRegion.Layer := PLayer;
    NewRegion.Kind  := eRegionKind_Copper;
    NewRegion.Net   := AVia.Net;

    SegCount := 0;
    theta    := 0;

    for I := 0 to (eSections - 1) do
    begin
        PolySeg := TPolySegment;
        PolySeg.Kind   := ePolySegmentArc;

        X := AVia.X + (VAD/2);
        Y := AVia.Y;
        RotateCoordsAroundXY(X, Y, AVia.x, AVia.y, theta);

        PolySeg.vx := X;
        PolySeg.vy := Y;

        PolySeg.cx     := AVia.x;
        PolySeg.cy     := AVia.y;
        PolySeg.Radius := VAD / 2;
        PolySeg.Angle1 := theta;
        theta := theta + (360 / eSections);
        PolySeg.Angle2 := theta;
        inc(SegCount);
        NewRegion.ShapeSegmentCount := SegCount;
        NewRegion.ShapeSegments(SegCount - 1) := PolySeg;
    end;
    NewRegion.UpdateContourFromShape(true);

    Result := AddSplitPlaneToBoard(NewRegion, PLayer, false);
end;

procedure MakePlaneNetClearance;
begin
    PlaneNetClearances(true);
end;
procedure DRCPlaneNetclearances;
begin
    PlaneNetClearances(false);
end;

procedure PlaneNetClearances(const Make : boolean);
var
    Iter           : IPCB_BoardIterator;
    Prim           : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPList     : TObjectList;
    NewRegion      : IPCB_Region;
    UnionIndex     : Integer;

    PObjSet        : TObjectSet;
    PLayer     : TLayer;
    I          : integer;
    MoreClear  : TCoord;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;
    MLayerStack := Board.MasterLayerStack;
    UnionIndex := GetHashID_ForString(GetWorkSpace.DM_GenerateUniqueID);
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));

    ReportLog := TStringList.Create;
    Board.BeginModify;

    Iter := Board.BoardIterator_Create;
    Iter.AddFilter_ObjectSet(MkSet(eViaObject, ePadObject));

    LayerObj := MLayerStack.First(eLayerClass_InternalPlane);
    while LayerObj <> nil do
    begin
        V7_Layer   := LayerObj.V7_LayerID;
        PLayer     := V7_Layer.ID;

        PObjSet := MkSet(eSplitPlaneObject);
        SplitPList := GetSplitPlaneObjs(PLayer, PObjSet);

        for I := 0 to (SplitPList.Count - 1) do
        begin
            SplitPlane := SplitPList.Items(I);

            PLayerSet := LayerSetUtils.EmptySet;
            PLayerSet.Include(eMultiLayer);
            PLayerSet.Include(PLayer);
            Iter.AddFilter_IPCB_LayerSet(PLayerSet);

            Prim := Iter.FirstPCBObject;
            while (Prim <> nil) do
            begin
                MoreClear := 0;
                if SplitPlane.GetState_HitPrimitive(Prim) then
                begin
                    if Prim.ObjectID = ePadObject then
                    if Prim.Layer = eMultiLayer then
                        MoreClear := CheckPrimClear(Board, Prim, SplitPlane, not Make);

                    if Prim.ObjectID = eViaObject then
                        MoreClear := CheckPrimClear(Board, Prim, SplitPlane, not Make);

                    if (Make) then
                    begin
                        NewRegion := AddMoreClear(Prim, PLayer, MoreClear);
                        NewRegion.UnionIndex := UnionIndex;
                        Board.AddPCBObject(NewRegion);
                    end;
                end;
                Prim := Iter.NextPCBObject;
            end;

            SplitPlane.GraphicallyInvalidate;
        end;
        Board.InvalidatePlane(PLayer);

        LayerObj := MLayerStack.Next(eLayerClass_InternalPlane, LayerObj);
    end;

    Board.BoardIterator_Destroy(Iter);
    Board.EndModify;
    Board.RebuildSplitBoardRegions(true);
    Board.ValidateInvalidPlanes;
    ReportLog.Free;
end;

function AddMoreClear(Prim : IPCB_Primitive, const Layer : TLayer, Expand : TCoord) : IPCB_Region;
var
    GPC       : IPCB_GeometricPolygon;
begin
    GPC    := PCBServer.PCBContourMaker.MakeContour(Prim, Expand, Layer);
    Result := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    Result.GeometricPolygon := GPC;
    Result.SetState_Kind(eRegionKind_Cutout);
    Result.SetState_Layer(Layer);
end;

// plane pour hard up to anti-pad so zero clearance is NOT a connection.
// plane anti-pad is larger than "pad" by clearance, contour of pad on layer is the anti-pad.
// reliefs (connection) seem part of pad/via, set by plane conn style rules, includes annular ring.
function CheckPrimClear(Board : IPCB_Board, Prim : IPCB_Primitive, SPL : IPCB_SplitPlane, const Violate : boolean) : TCoord;
var
    SplitPlaneReg : IPCB_SplitPlaneRegion;
    SPLReg        : IPCB_SplitPlaneRegion;
    SPRGIter      : IPCB_GroupIterator;
    PLayer        : TLayer;
    Clearance     : TCoord;
    MinClear      : TCoord;
    Rule, Rule2   : IPCB_Rule;
    PNet, PNet2   : IPCB_Net;
    PPCClear      : TCoord;
    Gap, Gap2     : TCoord;
    Gap3, Gap4    : TCoord;
    Violation     : IPCB_Violation;
begin

    Result := 0;
    PLayer := SPL.Layer;
    PNet   := SPL.Net;
    PNet2  := Prim.Net;
    PPCClear := Prim.PowerPlaneClearance;

    SPRGIter := SPL.GroupIterator_Create;
    SPRGIter.AddFilter_IPCB_LayerSet(MkSet(SPL.Layer));
    SPRGIter.AddFilter_ObjectSet(MkSet(eRegionObject));
    SPLReg := SPRGIter.FirstPCBObject;

// MinClear = 0 does NOT mean connection as to the anti-pad!!
    MinClear := kMaxCoord;
    while SPLReg <> nil do
    begin
        Clearance := Board.PrimPrimDistance(SPLReg, Prim);
        if Clearance < MinClear then
            SplitPlaneReg := SPLReg;

        MinClear := Min(MinClear, Clearance);
        SPLReg := SPRGIter.NextPCBObject;
    end;
    SPL.GroupIterator_Destroy(SPRGIter);

// if same net then ignore as would be connected with relief structure.
    if MinClear = 0 then
    if PNet <> nil then
    if PNet.UniqueId = PNet2.UniqueId then
    begin
        Result := -1;
        exit;
    end;

// recalc actual clearance with pad size on layer & holesize
// but that only work with simple round shape!
//    MinClear := (Prim.SizeOnLayer(PLayer) - Prim.HoleSize) /2;
    MinClear := MinClear + PPCClear;

    Gap  := MinClear;
    Gap2 := 0;
    Gap3 := 0;
    Gap4 := 0;
//    PNet.Name;
    Prim.ObjectId;
    if Prim.InNet then PNet2.Name;
    CoordToMils(MinClear);

// this is the default clearance to plated barrel/hole for antipads no connection.
    Rule := Board.FindDominantRuleForObjectPair(SPL, Prim, eRule_PowerPlaneClearance);
    if Rule <> nil then
    begin
        Gap2 := Rule.Clearance;
        if Violate then
        if Rule.Enabled and (Gap2 > MinClear) then
        begin
            Violation := MakeViolation(Rule, SplitPlaneReg, Prim);
            if Violation <> nil then
                Board.AddPCBObject(Violation);
        end;
    end;
    Gap := Max(Gap, Gap2);

    Rule := Board.FindDominantRuleForObjectPair(PNet, Prim, eRule_Clearance);
    if Rule <> nil then
    begin
        Gap3 := Rule.GetClearance(PNet, Prim);
        if PNet <> nil then
        if PNet.UniqueId = PNet2.UniqueId then Gap3 := 0;
        if Violate then
        if Rule.Enabled and (Gap3 > MinClear) then
        begin
            Violation := MakeViolation(Rule, PNet, Prim);
            if Violation <> nil then
                Board.AddPCBObject(Violation);
        end;
    end;
    Gap := Max(Gap, Gap3);

    Rule := Board.FindDominantRuleForObjectPair(SPL, PNet2, eRule_Clearance);
    if Rule <> nil then
    begin
        Gap2 := Rule.GetClearance(SPL, PNet2);
// splitPlaneRreg has NO NET property
        if PNet.UniqueId = PNet2.UniqueId then Gap2 := 0;
        if Rule.Enabled and Violate and (Gap2 > MinClear) then
        begin
            Violation := MakeViolation(Rule, SPL, PNet2);
            if Violation <> nil then
            begin
//                Violation.Layer := SPL.Layer;
                Board.AddPCBObject(Violation);
            end;
        end;
    end;
    Gap := Max(Gap, Gap2);

    Rule := Board.FindDominantRuleForObjectPair(PNet, Prim, eRule_Clearance);
    if Rule <> nil then
    begin
        Gap2 := Rule.GetClearance(PNet, Prim);
        if Rule.Enabled and Violate and (Gap2 > MinClear) then
        begin
            Violation := MakeViolation(Rule, PNet, Prim);
            if Violation <> nil then
            begin
                Violation.Layer := SPL.Layer;
                Board.AddPCBObject(Violation);
            end;
        end;
    end;
    Gap := Max(Gap, Gap2);

    Rule := Board.FindDominantRuleForObjectPair(PNet, PNet2, eRule_Clearance);
    if Rule <> nil then
    begin
        Gap4 := Rule.GetClearance(PNet, PNet2);
        if Rule.Enabled and Violate and (Gap4 > MinClear) then
        begin
            Violation := MakeViolation(Rule, PNet, PNet2);
            if Violation <> nil then
            begin
                Violation.Layer := SPL.Layer;
                Board.AddPCBObject(Violation);
            end;
        end;
    end;
    Gap := Max(Gap, Gap4);

    Gap := Gap - MinClear;
    if Gap > 0 then
        Result := Gap;
end;

function MakeViolation(Rule : IPCB_Rule, Prim1 : IPCB_Primitive, Prim2 : IPCB_Primitive) : IPCB_Violation;
var
    ViolDesc : Widestring;
    ViolName : WideString;
begin
    Result := Rule.ActualCheck(Prim1, Prim2);     // do NOT need to test reverse !
    if Result <> nil then
    begin
        Prim1.SetState_DRCError(true);
        Prim2.SetState_DRCError(true);
        Prim1.GraphicallyInvalidate;
        Prim2.GraphicallyInvalidate;
    end;
end;

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
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));

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
        NetName := cNoNetName;
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

    Board.InvalidatePlane(CLayer);
    Board.EndModify;
    Board.GraphicallyInvalidate;
    Board.RebuildSplitBoardRegions(false);
    Board.ValidateInvalidPlanes;
    ReportLog.Free;
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
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));

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
        for I := 0 to (SplitPList.Count - 1) do
        begin
            SplitPrim := SplitPList.Items(I);

            if SplitPrim.ObjectID = eSplitPlaneObject then
            begin
                    SplitPlane := SplitPrim;

                    NewPoly := AddPolygonToBoard2(SplitPlane, SLayer, true);
                    NewPoly.BeginModify;
                    NetName := cNoNetName;
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

    ReportLog := TStringList.Create;
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
    Board.RebuildSplitBoardRegions(true);
    Board.ValidateInvalidPlanes;
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
    ReportLog.Free;
end;

procedure CreateMechLayerPlaneCopy;
var
    SplitPrim      : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    NewRegion      : IPCB_Region;
    GPC            : IPCB_GeometricPolygon;
    CPIL           : TInterfaceList;
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
    bDrawOutline   : boolean;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then exit;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    MLayerStack := Board.MasterLayerStack;
    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    ReportLog := TstringList.Create;
    Layersetutils.NonEditableLayers.SerializeToString;
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));
    Board.BeginModify;
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

            if (SplitPrim.ObjectId = eSplitPlaneObject) or
               (SplitPrim.ObjectId = ePolyObject) then
                DrawPolyRegOutline(SplitPrim, MLayer, MilsToCoord(cLineWidth), LText, UnionIndex);

//  free regions drawn in plane layer.
//  outline is drawn by SplitPlane parent poly.
            if SplitPrim.ObjectID = eRegionObject then
            if not SplitPrim.InPolygon then
            begin
                GPC := SplitPrim.GeometricPolygon;
                CPIL := CreateInterfaceList;
                PCBServer.PCBContourUtilities.SplitIntoConnectedPolygons(GPC, CPIL);
                for J := 0 to (CPIL.Count - 1) do
                begin
                    NewRegion:= SplitPrim.Replicate;
                    NewRegion.GeometricPolygon := CPIL.Items(J);
                    NewRegion.Polygon := nil;
                    NewRegion.InPolygon := false;
                    NewRegion.Enabled_vPolygon := false;
                    NewRegion.SetState_Kind(eRegionKind_Cutout);
                    NewRegion.Layer := MLayer;
                    NewRegion.UnionIndex := UnionIndex;
                    Board.AddPCBObject(NewRegion);
                end;
            end;

// draw splitplane regions but no holes or reliefs.
//            if false then
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
    Board.EndModify;
    ReportLog.Free;
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

                SPRegion := SplitPlane;
                
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

    Board.RebuildSplitBoardRegions(true);
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

function GetSpatialObjs(RBox : TCoordRect, Layer : TLayer, const ObjSet : TObjectSet) : TObjectList;
var
    SIter   : IPCB_SpatialIterator;
    SplitPrim   : IPCB_Primitive;
    LayerSet    : IPCB_LayerSet;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    LayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);
    SIter := Board.SpatialIterator_Create;
    SIter.AddFilter_ObjectSet(ObjSet);
    SIter.AddFilter_IPCB_LayerSet(LayerSet);
    SIter.AddFilter_Area(RBox.X1,RBox.Y1,RBox.X2,RBox.Y2);

    SplitPrim := SIter.FirstPCBObject;
    while (SplitPrim <> Nil) Do
    begin
        Result.Add(SplitPrim);
        SplitPrim := SIter.NextPCBObject;
    end;
    Board.SpatialIterator_Destroy(SIter);
end;

function DrawPolyRegOutline(PolyRegion : IPCB_Region, Layer : TLayer, const LWidth : Tcoord, const LText : WideString, UIndex : integer) : TObjectList;
var
    GMPC     : IPCB_GeometricPolygon;
    PolySeg1 : TPolySegment;
    PolySeg2 : TPolySegment;
    BR       : TCoordRect;
    SegCount : integer;
    I, J     : Integer;
    X, Y     : TCoord;
    Track    : IPCB_Track;
    Arc      : IPCB_Arc;
    SBR      : TCoordRect;
    MaxSBR   : TCoordRect;
    Location : TCoordPoint;
    IsPoly   : boolean;
    GPCVL      : Pgpc_vertex_list;  //Contour

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
            Result.Add(Arc);
            SBR := Arc.BoundingRectangle;
            MaxSBR := MaxBR(MaxSBR, SBR);
        end;
    end;
    if Segcount = 0 then
    if PolyRegion.ObjectID = eRegionObject then
    begin
        GMPC := PolyRegion.GeometricPolygon;
        for J := 0 to GMPC.Count -1 do
        begin
            GPCVL := GMPC.Contour(J);   //PolyRegion.MainContour;

            for I := 0 to (GPCVL.Count-1) do     // loop to count
            begin
              Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
              Track.Width := LWidth;
              Track.Layer := Layer;
              Track.x1 := GPCVL.x(I);    // + RefP.X - BR.x1;
              Track.y1 := GPCVL.y(I);
              Track.x2 := GPCVL.x(I+1);
              Track.y2 := GPCVL.y(I+1);
              Track.UnionIndex := UIndex;

              Board.AddPCBObject(Track);
              Track.EndModify;
              Result.Add(Track);
              SBR := Track.BoundingRectangle;
              MaxSBR := MaxBR(MaxSBR, SBR);

              ReportLog.Add(CoordUnitToString(GPCVL.x(I) - BOrigin.X ,eMils) + '  ' + CoordUnitToString(GPCVL.y(I) - BOrigin.Y, eMils) );
            end;
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
    IsPoly     : boolean;

Begin
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
            if PolySeg.Kind = ePolySegmentLine then
                ReportLog.Add(IntToStr(PolySeg.Kind) + ' ' + CoordUnitToString(PolySeg.vx - BOrigin.X ,eMils) + '  ' + CoordUnitToString(PolySeg.vy - BOrigin.Y, eMils) );
            if PolySeg.Kind = ePolySegmentArc then
                ReportLog.Add(IntToStr(PolySeg.Kind) + ' ' + CoordUnitToString(PolySeg.cx - BOrigin.X ,eMils) + '  ' + CoordUnitToString(PolySeg.cy - BOrigin.Y, eMils) );
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
//                NewRegion.GeometricPolygon.AddContourIsHole(GPCVL, True);

                NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
                NewRegion.SetOutlineContour(GPCVL);
                NewRegion.SetState_Kind(eRegionKind_Cutout);
                NewRegion.Layer := Layer;
//                NewReg.UnionIndex := UnionIndex;
               Board.AddPCBObject(NewRegion);
//                Result.AddPCBObject(NewReg);
            end;
        end;
    end;

// add after regions so plane redraw pours around them
    Board.AddPCBObject(Result);
    Result.GraphicallyInvalidate;
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

