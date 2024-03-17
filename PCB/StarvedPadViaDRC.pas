{ StarvedPadViaDRC.pas

 PcbDoc
  
 Summary   Creates DRC Violations for Minimum Annular Ring rule if:
           - Pad or Via has starved plane or polygon connection on layer
           - Creates a special (disabled) MinimumAnnularRing rule to violate.
           - does not modify or remove existing Rules.

Planes:
Pad & Via annular rings (pads) are (effectively) removed from padstack &
replaced by relief construct region part of the polygon pour.
Contouring pad shape on layer only returns the barrel hole for ReliefConnect but returns nothing for directconnect.
Need to use to use PlaneConnectStyle & Relief Expansion etc to determine the correct test shape.
Relief expand the existing (hole) shape to allow non-round hole support in Vias.

Polygons:
Pad stack is not modifed.
Test shape is the pad shape.

Poly&Plane:
Use Connection Style etc to determine number of connection spokes & widths.
Use perimeter of pad shape & total spokes to determine correct copper.
Use pad shape & expanded shape & local polyregion intersections to measure actual copper.

Rule & Violation:
Script must use a Rule (that fails) to be able to raise Violation.
eRule_BrokenNets & eRule_UnconnectedPin will NOT work as Altium thinks connected!
Script creates a separate MinimumAnnularRing rule per layer.
This Rule kind supports pads & vias & has good visual indication.
The Rule(s) are disabled when script exits.
MinimumAnnularRing has no Layer scope & ignores OnLayer/ExistsOnLayer., all violations show as same layer.
But the Violation properties does show the actual layer.

Author: BL Miller
2023-12-14  0.10 POC from NetViaAntennasDRC & PadShapeRemoved.pas
            0.12 Violate against rule for each layer.
2024-03-16  0.14 POC Polygon test uses DRC rules to determine expected copper
                 Plane shape test uses hole shape NOT expanded by relief
2024-03-17  0.15 Plane shape test uses relief expanded pad shape
                 Makes union shape with PV hole as Plane DirectConnectStyle has NO pad!

TBD:
1.  use Minimum setting in MinimumAnnularRing rule to store starvation limit as percentage
    (1000mil or 100mm == 100%) so user can change from default value in Rule
2.  HoleToGeoPoly() support slots & non-round holes.

info:
IPCB_Board.PrimPrimDistance in SplitPlanes works for Vias, FAILS for Pads, could be due to plane pad removal.

Board.GetState_SplitPlaneNets(NetsList : TStringList);  speed up?
Board.GetState_AutomaticSplitPlanes;
Pad.PlaneConnectionStyleForLayer(ALayer : TLayer) : TPlaneConnectionStyle;
Polygon/SplitPlane.GetState_HitPrimitive;

Legacy Plane layers: --- DO NOT USE ---
const ePlaneDirectConnect ePlaneReliefConnect etc.
IPCB_PowerPlaneConnectStyleRule.PowerPlaneConnectStyle is just IPCB_Primitive prop.
}

{..............................................................................}
const
    SpecialRuleKind1 = eRule_MinimumAnnularRing;
    SpecialRuleName1 = '__Script-DRC-Starved_PVs_';
    cAllRules        = -1;
    cReport          = true;
    cArcResolution   = 0.001;   // mils: impacts number of edges etc..
    cExpansion       = 2;       // mils: width of test annular ring around pad-via
// internal plane
    cPadCopperMinPC  = 99;      // minimum percent of nominal plane/poly connection copper.
    cViaCopperMinPC  = 99;
// Polygons
    cPolyCopperMinPC = 50;      // minimim percentage total copper spoke actual to defined
var
    Board      : IPCB_Board;
    LayerStack : IPCB_MasterLayerStack;
    Rpt        : TStringList;

function GetMatchingRulesFromBoard (const RuleKind : TRuleKind) : TObjectList; forward;
function FoundRuleName(RulesList : TObjectList, const RuleName : WideString) : IPCB_Rule; forward;
function AddRule_MinimumAnnularRing(const RuleName, const LayerName : WideString, const CText : WideString) : IPCB_Rule; forward;
function MakeViolation(Board : IPCB_Board, Rule : IPCB_Rule, Prim : IPCB_Primitive, const Layer : TLayer) : IPCB_Violation; forward;
// if ANet is nil then get all polys on layer
function GetPolygonsOnLayer (const Layer : TLayer, const ANet : IPCB_Net) : TObjectList; forward;
function PerimeterLength (GMPC : IPCB_GeometricPolygon, MainContour : boolean) : extended; forward;
function HoleToGMPC(PVPrim : IPCB_Primitive) : IPCB_GeometricPolygon; forward;
function MeasureQoC(PVPrim, PolyReg : IPCB_Primitive, const Expand : TCoord, const Layer : TLayer, var Perimeter : TCoord) : Extended; forward;

procedure DetectViaAndPads;
var
    Iter           : IPCB_BoardIterator;
    Iter2          : IPCB_BoardIterator;
    PGIter         : IPCB_GroupIterator;
    PlaneIter      : IPCB_BoardIterator;
    SPRGIter       : IPCB_GroupIterator;
    Via            : IPCB_Via;
    Pad            : IPCB_Pad;
    PVNet          : IPCB_Net;
    SPNet          : IPCB_Net;
    NetName        : WideString;
    Violation      : IPCB_Violation;
    Prim           : IPCB_Primitive;
    PVPrim         : IPCB_Primitive;
    Polygon        : IPCB_Polygon;
    PPCS           : TPlaneConnectStyle;
    PPReliefs      : integer;
    PPConnWidth    : TCoord;
    PlaneRX        : TCoord;
    PolyTotWidth   : TCoord;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    LayerObj       : IPCB_LayerObject;
    PLayerSet      : IPCB_LayerSet;
    Layer          : TLayer;
    TV7_Layer      : IPCB_TV7_Layer;
    Rule1, Rule2   : IPCB_Rule;
    RulesList      : TObjectList;
    PolyList       : TObjectList;
    Connections     : Integer;
    ViolCount      : integer;
    ViolCount2     : integer;
    MajorADVersion : WideString;
    R, SP          : integer;
    PPD            : TCoord;
    Connected      : boolean;          // state of connection
    bConnection    : boolean;          // should be connected
    bOnLayer       : boolean;
    bPrimViolates  : boolean;
    RuleName       : WideString;
    PercentCopper  : extended;
    Perimeter      : TCoord;
    PercentPM      : extended;
    FilePath       : WideString;
    i : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    PCBServer.SystemOptions;
    Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

// Check AD version for layer stack version
    MajorADVersion := GetBuildNumberPart(Client.GetProductVersion, 0);

    LayerStack := Board.MasterLayerStack;
    if cReport then
        Rpt := TStringList.Create;

// clear existing violations
    if ConfirmNoYes('Clear Existing DRC Violation Markers ? ') then
        Client.SendMessage('PCB:ResetAllErrorMarkers', '', 255, Client.CurrentView);

    BeginHourGlass(crHourGlass);
    PCBServer.PCBContourMaker.SetState_ArcResolution(MilsToCoord(cArcResolution));
    PCBServer.PreProcess;

    RulesList := GetMatchingRulesFromBoard(SpecialRuleKind1);

    ViolCount  := 0;
    ViolCount2 := 0;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.IncludeSignalLayers;
    PLayerSet.Include(eMultiLayer);

    Iter := Board.BoardIterator_Create;
    Iter.AddFilter_ObjectSet(MkSet(eViaObject, ePadObject));
    Iter.AddFilter_IPCB_LayerSet(PLayerSet);         // SignalLayers &  eMultiLayer

    PlaneIter := Board.BoardIterator_Create;
    PlaneIter.AddFilter_ObjectSet(MkSet(eSplitPlaneObject));

    PVPrim := Iter.FirstPCBObject;
    while (PVPrim <> nil) do
    begin
        Connections  := 0;

        NetName := '<no net>';
        PVNet := PVPrim.Net;
        if PVPrim.InNet then
            NetName := PVNet.Name;
        PVPrim.SetState_DRCError(false);           // clear marker used without REAL violation object
        bPrimViolates := false;

        Pad := nil;
        Via := nil;

        if PVPrim.ObjectId = ePadObject then
        begin
            Pad := PVPrim;
        end;
        if PVPrim.ObjectId = eViaObject then
            Via := PVPrim;

        if cReport then
            Rpt.Add(PVPrim.ObjectIDString + ' | ' + NetName);

        LayerObj := LayerStack.First(eLayerClass_Electrical);
        while LayerObj <> nil do
        begin
            TV7_Layer := LayerObj.V7_LayerID;
            Layer := TV7_Layer.ID;
            PLayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);

            Connected   := false;
            bConnection := false;
            bOnLayer    := false;

            if PVPrim.InNet then
            if PVPrim.ObjectID = eViaObject then
            if Via.IntersectLayer(Layer) then
            begin
                if LayerUtils.IsInternalPlaneLayer(Layer) then
                if Via.GetState_IsConnectedToPlane(Layer) then
                    bOnLayer := true;
                if LayerUtils.IsSignalLayer(Layer) then
                    bOnLayer := true;
            end;

            if PVPrim.InNet then
            if PVPrim.ObjectID = ePadObject then
            if (Pad.Layer = eMultiLayer) or (Pad.Layer = Layer) then
                bOnLayer := true;

// create required rule for layer
            RuleName := SpecialRuleName1 + LayerObj.Name;
            if bOnLayer then
            begin
                Rule1 := FoundRuleName(RulesList, RuleName);
                if Rule1 = nil then
                begin
                    Rule1 := AddRule_MinimumAnnularRing(RuleName, LayerObj.Name, '(disabled) Broken Net to PV Violations');
                    RulesList := GetMatchingRulesFromBoard(SpecialRuleKind1);
                end;
                Rule1.Minimum;
            end;

//  signal layers
            if bOnLayer then
            if LayerUtils.IsSignalLayer(Layer) then
            begin
                PolyList := GetPolygonsOnLayer(Layer, PVNet);

                for i := 0 to (PolyList.Count - 1) do
                begin
                    Polygon := PolyList.Items(i);

                    if Polygon.Net <> PVNet then     // should always be false!
                        continue;
                    if not Polygon.PrimitiveInsidePoly(PVPrim) then
                        continue;

                    bConnection := true;
                    if cReport then Rpt.Add('net connection on '+ LayerObj.Name);

                    PGIter := Polygon.GroupIterator_Create;
                    PGIter.AddFilter_ObjectSet(MkSet(eRegionObject, eTrackObject, eArcObject));
                    Prim := PGIter.FirstPCBObject;
                    while (Prim <> Nil) Do
                    begin
                        PolyTotWidth := 0;
                        Rule2 := Board.FindDominantRuleForObjectPair(PVPrim, Polygon, eRule_PolygonConnectStyle);
                        if Rule2 <> nil then
                        begin
                            PPCS        := Rule2.ConnectStyle;
                            PPReliefs   := Rule2.ReliefEntries;
                            PPConnWidth := Rule2.ReliefConductorWidth;
                            PolyTotWidth := PPConnWidth * PPReliefs;
                        end;


                        PPD := Board.PrimPrimDistance(Prim, PVPrim);
                        if cReport then
                            Rpt.Add('--- ' +  Prim.ObjectIDString + ' | ' + CoordUnitToString(PPD, eMils) );

                        if PPD = 0 then
                        begin
//                            Connected := true;
                            PercentCopper := MeasureQoC(PVPrim, Prim, 0, Layer, Perimeter);
                            PercentPM     := PolyTotWidth / Perimeter *100;

                            if PPCS = eDirectConnectToPlane then PercentPM := 100;
                            if PercentCopper > 0 then Connected := true;

                            if cReport then
                                Rpt.Add('--- copper: ' + FloatToStr(PercentCopper) + ' % |  Perimeter ' + FloatToStr(PercentPM) + ' %');

                            if PercentCopper < cPolyCopperMinPC then Connected := false;
{
                            if PPCS = eDirectConnectToPlane then
                            if (PercentCopper * 0.99) < 100 then Connected := false;

                            if PPCS = eReliefConnectToPlane then
                            if (PercentCopper * 0.99) < PercentPM then Connected := false;
}
// this would have PPD > 0!
//                            if PPCS = eNoConnect then
//                            if (PercentCopper > 0) then Connected := true;

                            if Connected then
                                Inc(Connections);
                        end;
                        Prim := PGIter.NextPCBObject;
                    end;
                    Polygon.GroupIterator_Destroy(PGIter);
                end;
            end;

//  Plane layers
            if bOnLayer then
            if LayerUtils.IsInternalPlaneLayer(Layer) then
            begin
                PlaneIter.AddFilter_IPCB_LayerSet(PLayerSet);
                SplitPlane := PlaneIter.FirstPCBObject;
                while (SplitPlane <> Nil) Do
                begin
                    SPNet := SplitPlane.Net;
//                    if SplitPlane.PrimitiveInsidePoly(PVPrim) then
                    if SPNet = PVNet then bConnection := true;

                    if bConnection then
                    if cReport then Rpt.Add('net connection on '+ LayerObj.Name);

                    if bConnection then
                    if SplitPlane.GetState_HitPrimitive(PVPrim) then
                    begin
                        Rule2 := Board.FindDominantRuleForObjectPair(PVPrim, SplitPlane, eRule_PowerPlaneConnectStyle);
                        if Rule2 <> nil then
                        begin
                            PPCS         := Rule2.PlaneConnectStyle;        // 0 relief, 1 direct, 2 no connect
                            PPReliefs    := Rule2.ReliefEntries;
                            PPConnWidth  := Rule2.ReliefConductorWidth;
                            PlaneRX      := Rule2.ReliefExpansion;
                            PolyTotWidth := PPConnWidth * PPReliefs;

                        end;
//  no psuedo pad shape & spokes generated.                      //  eNoConnect 
                        if PPCS <> eReliefConnectToPlane then
                            PlaneRx := 0;

                        SPRGIter := SplitPlane.GroupIterator_Create;
                        SPRGIter.AddFilter_IPCB_LayerSet(PLayerSet);
                        SPRGIter.AddFilter_ObjectSet(MkSet(eRegionObject));
                        SplitPlaneReg := SPRGIter.FirstPCBObject;
                        while SplitPlaneReg <> nil do
                        begin
//   PrimPrimDistance in SplitPlanes only seems to work for Vias
                            PPD := Board.PrimPrimDistance(SplitPlaneReg, PVPrim);
                            if PPD = 0 then Connected := true;

                            PercentCopper := MeasureQoC(PVPrim, SplitPlaneReg, PlaneRX, Layer, Perimeter);
                            PercentPM     := PolyTotWidth / Perimeter *100;

                            if PPCS = eDirectConnectToPlane then PercentPM := 100;
//  PVPrim does touch region
                            if PercentCopper > 0 then Connected := true;

                            if cReport then
                                Rpt.Add('--- ' + SplitPlaneReg.ObjectIDString + ' | ' + CoordUnitToString(PPD, eMils) );
                            if cReport then
                                Rpt.Add('--- copper: ' + FloatToStr(PercentCopper) + ' % |  Perimeter ' + FloatToStr(PercentPM) + ' %');

//                            if PPCS = eReliefConnectToPlane then
//                            if (PercentCopper * 0.99) < PercentPM then Connected := false;

                            if PVPrim.ObjectID = eViaObject then
                            if PercentCopper < cViaCopperMinPC then Connected := false;

                            if PVPrim.ObjectID = ePadObject then
                            if PercentCopper < cPadCopperMinPC then Connected := false;

                            if Connected then
                                inc(Connections);

                            SplitPlaneReg := SPRGIter.NextPCBObject;
                        end;

                        SplitPlane.GroupIterator_Destroy(SPRGIter);
                    end;
                    SplitPlane := PlaneIter.NextPCBObject;
                end;
            end;

            if bOnLayer and bConnection and (not Connected) then
            begin
                bPrimViolates := true;
                Violation := nil;

                if Rule1 <> nil then
                    Violation := MakeViolation(Board, Rule1, PVPrim, Layer);
                if Violation <> nil then inc(ViolCount);
          //      PVPrim.Selected := True;
                if cReport then
                    Rpt.Add(' --- not connected ');
            end;

            LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
        end;

        if bPrimViolates then inc(ViolCount2);

        if cReport then Rpt.Add('');

        PVPrim := Iter.NextPCBObject;
    end;

    Board.BoardIterator_Destroy(PlaneIter);
    Board.BoardIterator_Destroy(Iter);

//   need to retain rules to make DRC UI display violation interactive

    LayerObj := LayerStack.First(eLayerClass_Electrical);
    while LayerObj <> nil do
    begin
        RuleName := SpecialRuleName1 + LayerObj.Name;
        Rule1 := FoundRuleName(RulesList, RuleName);
        if Rule1 <> nil then
        begin
            Rule1.DRCEnabled := false;
//            if ViolCount = 0 then
//            begin
//                Board.RemovePCBObject(Rule1);
//                PCBServer.DestroyPCBObject(Rule1);
//            end;
        end;
        LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
    end;

    PCBServer.PostProcess;
    EndHourGlass;

    if RulesList <> nil then RulesList.Clear;
    if PolyList <> nil then PolyList.Clear;

    FilePath := Board.FileName;
    FilePath := ExtractFilePath(FilePath) + ExtractFileName(Filepath);
    if FilePath = '' then
        FilePath := SpecialFolder_Temporary + 'PrimPrimDistance.txt'
    else
    begin
        ChangeFileExt(FilePath, '');
        FilePath := FilePath + '_PrimPrimDistance.txt';
    end;
    if cReport then Rpt.SaveToFile(FilePath);

    Board.ViewManager_FullUpdate;
//    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
    ShowInfo (IntToStr(ViolCount2) + ' Pad&Via(s) with ' + IntToStr(ViolCount) +' removed pads & connection Violations found/DRC marked');
end;


// Just in case some clean up is required to remove stubborn violations..
procedure CleanViolations;
var
    Iterator  : IPCB_BoardIterator;
    Violation : IPCB_Violation;
    PVPrim    : IPCB_Primitive;
    VObjList  : TObjectList;
    I         : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;


    VObjList := TObjectList.Create;
    VObjList.OwnsObjects := false;

    Iterator := Board.BoardIterator_Create;
{
    Iterator.AddFilter_ObjectSet(MkSet(eViolationObject));
    Iterator.AddFilter_LayerSet(AllLayers);
//    Iterator.AddFilter_Method(eProcessAll);

    Violation := Iterator.FirstPCBObject;
    while Violation <> Nil do
    begin
        VObjList.Add(Violation);
        Violation := Iterator.NextPCBObject;
    end;
    for I := 0 to (VObjList.Count - 1) do
    begin
        Violation := VObjList.Items(I);
        Board.RemovePCBObject(Violation);
        PCBServer.DestroyPCBObject(Violation);
    end;
}
    VObjList.Clear;
    VObjList.Free;

    Iterator.AddFilter_ObjectSet(MkSet(eViaObject, ePadObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    PVPrim := Iterator.FirstPCBObject;
    while (PVPrim <> nil) do
    begin
        PVPrim.SetState_DRCError(false);
        PVPrim.GraphicallyInvalidate;
        PVPrim := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;

{------------------------------------------------------------------------------}
function MeasureQoC(PVPrim, PolyReg : IPCB_Primitive, const Expand : TCoord, const Layer : TLayer, var Perimeter : TCoord) : Extended;
// Expand: used with Planes ReliefExpansion to recreate pad shape as per rule; zero for Polygons
var
    GMPC1, GMPC2  : IPCB_GeometricPolygon;
    GMPC3         : IPCB_GeometricPolygon;
    Area1, Area2  : extended;
    Area3, Area4  : extended;
begin
//  PV shape on layer
    GMPC1 := PCBServer.PCBContourMaker.MakeContour(PVPrim, Expand, Layer);
// safety hole as direct connect plane has zero pad!
    GMPC2 := HoleToGMPC(PVPrim);
    PCBServer.PCBContourUtilities.ClipSetSet(eSetOperation_Union, GMPC2, GMPC1, GMPC1);
    Area1 := GMPC1.Area;
    if (false) and (Area1 > 0) then
    begin
        GMPC1 := PCBServer.PCBContourMaker.MakeContour(PVPrim, Expand, eMultiLayer);
        Area1 := GMPC1.Area;
    end;
    if Area1 > 0 then
        Perimeter := PerimeterLength(GMPC1, true)
    else
        Perimeter := 0;
//  expanded PV
    GMPC2 := PCBServer.PCBContourMaker.MakeContour(PVPrim, Expand + MilsToCoord(cExpansion), Layer);
    Area2 := GMPC2.Area;
    Area2 := Area2 - Area1;

// shape of poly region around PV
    GMPC3 := PCBServer.PCBContourMaker.MakeContour(PolyReg, 0, Layer);
//  PolyReg intersection with PV shape
    PCBServer.PCBContourUtilities.ClipSetSet(eSetOperation_Intersection, GMPC3, GMPC1, GMPC1);
//  PolyReg intersection with expanded PV shape
    PCBServer.PCBContourUtilities.ClipSetSet(eSetOperation_Intersection, GMPC3, GMPC2, GMPC2);
// check PolyRegion touches PV!
    Area3 := GMPC1.Area;
    if Area3 = 0 then
    begin
        Result := 0;
    end else
    begin
//  intersection of polyregion & expanded PV
        Area4 := GMPC2.Area;
        Area3 := Area4 - Area3;
//  ratio of connection spoke area to expanded area
        Result := Area3 / Area2 * 100;
    end;
end;

function MakeViolation(Board : IPCB_Board, Rule : IPCB_Rule, Prim : IPCB_Primitive, const Layer : TLayer) : IPCB_Violation;
var
   Violation : IPCB_Violation;
begin
// always finds same wrong layer rule
//    Rule := Board.FindDominantRuleForObject(Prim, RuleKind);
// DNW                                                             // eNoDimension
//    Violation := PCBServer.PCBObjectFactory(eViolationObject, SpecialRuleKind, eCreate_Default);
//    Violation.Rule := Rule;
//    Violation.Description := 'new description';

    Violation := nil;
//    if Rule.IsUnary then
//    Rule.Scope1Includes(Prim);     // adds nothing
//    if Rule.CheckUnaryScope(Prim) then
        Violation := Rule.ActualCheck(Prim, nil);

    if Violation <> nil then
    begin
        Violation.Name;
        Violation.Description;
        Violation.Layer := Layer;
        Board.AddPCBObject(Violation);
        Prim.SetState_DRCError(true);
        Prim.GraphicallyInvalidate;
    end;
    Result := Violation;
end;

function HoleToGMPC(PVPrim : IPCB_Primitive) : IPCB_GeometricPolygon;
var
    Contour  : IPCB_Contour;
    HoleSize : integer;
begin
    Result := PCBServer.PCBGeometricPolygonFactory;
    HoleSize := PVPrim.HoleSize;
    Contour := PCBServer.PCBContourFactory;
    PCBServer.PCBContourMaker.AddArcToContour(Contour, 0, 360, PVPrim.x, PVPrim.y, HoleSize/2, true);
    Result.AddContour(Contour);
end;

function PerimeterLength (GMPC : IPCB_GeometricPolygon, const MainContour : boolean) : extended;
var
    GPVL        : IPCB_Contour; // Pgpc_vertex_list;
    GPVL2       : IPCB_Contour; // Pgpc_vertex_list;
    X1,Y1,X2,Y2 : extended;
    I, J, K     : integer;
    L           : extended;
begin
    Result := 0;
    L := 0;
    GPVL := PCBServer.PCBContourFactory;
    for i := 0 to (GMPC.Count - 1) do
    begin
        GPVL2 := GMPC.Contour(i);
        if GPVL2.Area > L then
        begin
            L := GPVL2.Area;
            GPVL := GPVL2;
        end;
    end;
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
                Result := Result + (L * k1Mil);
    end;
end;

function GetPolygonsOnLayer (const Layer : TLayer, const ANet : IPCB_Net) : TObjectList;
var
    Iterator : IPCB_BoardIterator;
    Poly     : IPCB_Polygon;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(ePolyObject));
    Iterator.AddFilter_LayerSet(MkSet(Layer));
    Iterator.AddFilter_Method(eProcessAll);
    Poly := Iterator.FirstPCBObject;
    while (Poly <> Nil) Do
    begin
        if ANet = nil then
            Result.Add(Poly)
        else
            begin
                if ANet = Poly.Net then Result.Add(Poly)
            end;
        Poly := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);
end;

function GetMatchingRulesFromBoard (const RuleKind : TRuleKind) : TObjectList;
var
    Iterator : IPCB_BoardIterator;
    Rule     : IPCB_Rule;
begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);
    Rule := Iterator.FirstPCBObject;
    while (Rule <> Nil) Do
    begin
        if RuleKind = cAllRules then
            Result.Add(Rule)
        else
            if Rule.RuleKind = RuleKind then Result.Add(Rule);

        Rule := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);
end;

function FoundRuleName(RulesList : TObjectList, const RuleName : WideString) : IPCB_Rule;
var
    Rule : IPCB_Rule;
    R    : integer;
begin
    Result := nil;
    for R := 0 to (RulesList.Count - 1) do
    begin
        Rule := RulesList.Items(R);
        if SameString(Rule.Name, RuleName, true) then
        begin
            Result := Rule;
            break;
        end;
    end;
end;

// Rule generated to violate!
//  IPCB_UnConnectedPinRule;
//  IPCB_BrokenNetRule
function AddRule_BrokenNets(const RuleName, const LayerName : WideString, const CText : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(eRule_BrokenNets);
//    PCBServer.PreProcess;
    Result.Name := RuleName;
// Layer scope does not work in built-in DRC
    Result.Scope1Expression    := 'ExistsOnLayer(' + Chr(39) + LayerName + Chr(39) + ')';
    Result.Scope2Expression    := '';
    Result.Comment             := CText;
    Result.Minimum             := MilsToCoord(500);
    Result.CheckBadConnections := true;
    Board.AddPCBObject(Result);
    Result.DRCEnabled          := true;
//    PCBServer.PostProcess;
end;

function AddRule_RoutingViaStyle(const RuleName, const LayerName : WideString, const CText : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(eRule_RoutingViaStyle);
    Result.Name := RuleName;
    Result.Scope1Expression := 'IsVia';
    Result.Scope2Expression := '';
    Result.Comment          := CText;
    Result.MinWidth         := MilsToCoord(200);
    Result.MaxWidth         := MilsToCoord(200);
    Result.MinHoleWidth     := MilsToCoord(100);
    Result.MaxHoleWidth     := MilsToCoord(100);
    Result.DRCEnabled       := true;
{
 Property PreferedHoleWidth : TCoord
 Property PreferedWidth : TCoord
 Property ViaStyle : TRouteVia
}
    Board.AddPCBObject(Result);
end;

function AddRule_MinimumAnnularRing(const RuleName, const LayerName : WideString, const CText : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(eRule_MinimumAnnularRing);   //TRuleKind
    Result.Name := RuleName;
// Layer scope does not work in built-in DRC
    Result.Scope1Expression := 'ExistsOnLayer(' + Chr(39) + LayerName + Chr(39) + ')';
    Result.Scope2Expression := '';
    Result.Comment          := CText;

    Result.Minimum          := MilsToCoord(500);
    Result.DRCEnabled       := true;
    Board.AddPCBObject(Result);
end;

