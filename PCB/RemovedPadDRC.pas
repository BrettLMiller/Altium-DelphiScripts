{ RemovedPadDRC.pas
 Summary   Creates DRC Violations for Minimum Annular Ring rule if:
           - Pad or Via has removed pad & is connected on layer
           Creates a special (disabled) MinimumAnnularRing rule to violate.

MinimumAnnularRing has no Layer scope & ignores OnLayer/ExistsOnLayer., all violations show as same layer.

Author: BL Miller
20231214  : 0.1  POC from NetViaAntennasDRC & PadShapeRemoved.pas
            0.12 Violate against rule for each layer.

Extra proc CleanViolations()  just in case clean up needed at some point..

tbd:
Does this need to consider legacy Protel planes (all one net), test sysPrefs for InternalPlanes.

info:
Board.GetState_SplitPlaneNets(NetsList : TStringList);  speed up?
Board.GetState_AutomaticSplitPlanes;
Pad.PlaneConnectionStyleForLayer(ALayer : TLayer) : TPlaneConnectionStyle;
Polygon/SplitPlane.GetState_HitPrimitive;
}

{..............................................................................}
const
    SpecialRuleName1 = '__Script-PadRemoved__';
    SpecialRuleKind  = eRule_MinimumAnnularRing;
    cAllRules        = -1;

var
    Board      : IPCB_Board;
    LayerStack : IPCB_MasterLayerStack;

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
        if Rule.Name = RuleName then
        begin
            Result := Rule;
            break;
        end;
    end;
end;

// Rule generated to violate!
function AddSpecialViaRule(const RuleName, const RuleKind : WideString, const LayerName : WideString, const CText : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(RuleKind);   //TRuleKind
//    PCBServer.PreProcess;
    Result.Name := RuleName + LayerName;
// Layer scope does not work in built-in DRC
    Result.Scope1Expression := 'ExistsOnLayer(' + Chr(39) + LayerName + Chr(39) + ')';
    Result.Scope2Expression := '';
    Result.Comment          := CText;

    Result.Minimum          := MilsToCoord(200);
    Result.DRCEnabled       := true;
    Board.AddPCBObject(Result);
//    PCBServer.PostProcess;
end;

function MakeViolation(Board : IPCB_Board, Rule : IPCB_Rule, Prim : IPCB_Primitive, const Layer : TLayer) : IPCB_Violation;
var
//   Rule      : IPCB_Rule;
   Violation : IPCB_Violation;
begin
// always finds same wrong layer rule
//    Rule := Board.FindDominantRuleForObject(Prim, RuleKind);

    if Rule.IsUnary then
//    Rule.Scope1Includes(Prim);     // adds nothing
    Violation := nil;
    if Rule.CheckUnaryScope(Prim) then
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

procedure DetectViaAndPads;
var
    Iter           : IPCB_BoardIterator;
    SpatIter       : IPCB_SpatialIterator;
    PlaneIter      : IPCB_Iterator;
    SPRGIter       : IPCB_GroupIterator;
    Via            : IPCB_Via;
    Pad            : IPCB_Pad;
    Violation      : IPCB_Violation;
    Prim           : IPCB_Primitive;
    PVPrim         : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    LayerObj       : IPCB_LayerObject;
    PLayerSet      : IPCB_LayerSet;
    Layer          : TLayer;
    TV7_Layer      : IPCB_TV7_Layer;
    Rectangle      : TCoordRect;
    Rule1          : IPCB_Rule;
    RulesList      : TObjectList;
    Connection     : Integer;
    ViolCount      : integer;
    ViolCount2     : integer;
    S, VersionStr  : String;
    MajorADVersion : WideString;
    found          : Boolean;
    R, SP          : integer;
    Connected      : boolean;
    bRemoved       : boolean;
    bOnLayer       : boolean;
    bPrimViolates  : boolean;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    PCBServer.SystemOptions;
    Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

// Check AD version for layer stack version
    MajorADVersion := GetBuildNumberPart(Client.GetProductVersion, 0);

    LayerStack := Board.MasterLayerStack;

// clear existing violations
    if ConfirmNoYes('Clear Existing DRC Violation Markers ? ') then
        Client.SendMessage('PCB:ResetAllErrorMarkers', '', 255, Client.CurrentView);

    BeginHourGlass(crHourGlass);

// test for special rule
    RulesList := GetMatchingRulesFromBoard(SpecialRuleKind);

    PCBServer.PreProcess;

    LayerObj := LayerStack.First(eLayerClass_Electrical);
    while LayerObj <> nil do
    begin
        TV7_Layer := LayerObj.V7_LayerID;
        Layer := TV7_Layer.ID;

        Rule1 := FoundRuleName(RulesList, SpecialRuleName1 + LayerObj.Name);

        if Rule1 = nil then  Rule1 := AddSpecialViaRule(SpecialRuleName1, SpecialRuleKind, LayerObj.Name, 'Disabled Removed Pad Shape Violations');
        if Rule1 <> nil then Rule1.DRCEnabled := true;

        LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
    end;

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

    SpatIter := Board.SpatialIterator_Create;
    SpatIter.AddFilter_ObjectSet(MkSet(eTrackObject, eArcObject, ePadObject, eFillObject, eRegionObject));

    PVPrim := Iter.FirstPCBObject;
    while (PVPrim <> nil) do
    begin
        Connection  := 0;

        PVPrim.SetState_DRCError(false);           // clear marker used without REAL violation object
        bPrimViolates := false;

        Rectangle  := PVPrim.BoundingRectangle;
        Pad := nil;
        Via := nil;

        if PVPrim.ObjectId = ePadObject then
        begin
            Pad := PVPrim;
        end;
        if PVPrim.ObjectId = eViaObject then
            Via := PVPrim;

        LayerObj := LayerStack.First(eLayerClass_Electrical);
        while LayerObj <> nil do
        begin
            TV7_Layer := LayerObj.V7_LayerID;
            Layer := TV7_Layer.ID;
            PLayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);

            Connected := false;
            bRemoved  := false;
            bOnLayer  := false;

            if PVPrim.ObjectID = eViaObject then
            if Via.IntersectLayer(Layer) then
            if Via.SizeOnLayer(Layer) <= Via.HoleSize then
                bRemoved := true;

            if PVPrim.ObjectId = ePadObject then
            if Pad.IsPadRemoved(Layer) then
                bRemoved := true;

            if bRemoved then
            begin
                if PVPrim.ObjectID = eViaObject then
                if Via.IntersectLayer(Layer) then
                begin
                    if LayerUtils.IsInternalPlaneLayer(Layer) then
                    if Via.GetState_IsConnectedToPlane(Layer) then
                        bOnLayer := true;
                    if LayerUtils.IsSignalLayer(Layer) then
                        bOnLayer := true;
                end;

                if PVPrim.ObjectID = ePadObject then
                if (Pad.Layer = eMultiLayer) or (Pad.Layer = Layer) then
                    bOnLayer := true;
            end;

//  signal layers
            if bRemoved and bOnLayer then
            if LayerUtils.IsSignalLayer(Layer) then
            begin
                SpatIter.AddFilter_Area(Rectangle.Left - 100, Rectangle.Bottom - 100, Rectangle.Right + 100, Rectangle.Top + 100);
                SpatIter.AddFilter_IPCB_LayerSet(PLayerSet);

                Prim := SpatIter.FirstPCBObject;
                while (Prim <> Nil) Do
                begin
                    found := false;

                    if (Prim.UniqueId <> PVPrim.UniqueID) then
                    begin
                        if (Prim.ObjectID = ePadObject) then
                        begin
                            if Prim.ShapeOnLayer(Layer) <> eNoShape then found := true;
                        end else
                            if (Prim.Layer = Layer) then found := true;
                    end;
//                   ShowMessage('PP distance ' + IntToStr(Board.PrimPrimDistance(Prim, Via)) );
                    if found then
                    if Board.PrimPrimDistance(Prim, PVPrim) = 0 then
                    begin
                        Connected := true;
                        Inc(Connection);
                        break;
                    end;
                    Prim := SpatIter.NextPCBObject;
                end;
            end;

//  Plane layers
            if bRemoved and bOnLayer then
            if LayerUtils.IsInternalPlaneLayer(Layer) then
            begin
                PlaneIter.AddFilter_IPCB_LayerSet(PLayerSet);
                SplitPlane := PlaneIter.FirstPCBObject;
                while (SplitPlane <> Nil) Do
                begin
//                    if SplitPlane.PrimitiveInsidePoly(Via) then
//                    if SplitPlane.GetState_HitPrimitive(Via) then
                    SPRGIter := SplitPlane.GroupIterator_Create;
                    SPRGIter.AddFilter_IPCB_LayerSet(PLayerSet);
                    SPRGIter.AddFilter_ObjectSet(MkSet(eRegionObject));
                    SplitPlaneReg := SPRGIter.FirstPCBObject;
                    while SplitPlaneReg <> nil do
                    begin
                        if Board.PrimPrimDistance(SplitPlaneReg, PVPrim) = 0 then
                        begin
                            Connected := true;
                            inc(Connection);
                            break;
                        end;
                        SplitPlaneReg := SPRGIter.NextPCBObject;
                    end;

                    SplitPlane.GroupIterator_Destroy(SPRGIter);
                    SplitPlane := PlaneIter.NextPCBObject;
                end;
            end;

            if bRemoved and bOnLayer and Connected then
            begin
                bPrimViolates := true;
                Violation := nil;
                Rule1 := FoundRuleName(RulesList, SpecialRuleName1 + LayerObj.Name);

                if Rule1 <> nil then
                    Violation := MakeViolation(Board, Rule1, PVPrim, Layer);
                if Violation <> nil then inc(ViolCount);
          //      PVPrim.Selected := True;
            end;

            LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
        end;

        if bPrimViolates then inc(ViolCount2);

        PVPrim := Iter.NextPCBObject;
    end;

    Board.SpatialIterator_Destroy(SpatIter);
    Board.BoardIterator_Destroy(PlaneIter);
    Board.BoardIterator_Destroy(Iter);

//   need to retain rules to make DRC UI display violation interactive

    LayerObj := LayerStack.First(eLayerClass_Electrical);
    while LayerObj <> nil do
    begin
        Rule1 := FoundRuleName(RulesList, SpecialRuleName1 + LayerObj.Name);
        if Rule1 <> nil then
        begin
            Rule1.DRCEnabled := false;
            if ViolCount = 0 then
            begin
                Board.RemovePCBObject(Rule1);
                PCBServer.DestroyPCBObject(Rule1);
            end;
        end;

        LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
    end;

    PCBServer.PostProcess;
    ShowInfo (IntToStr(ViolCount2) + ' Pad&Via(s) with ' + IntToStr(ViolCount) +' removed pads & connection Violations found/DRC marked');
    EndHourGlass;

    Board.ViewManager_FullUpdate;
//    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;


// Just in case some clean up is required to remove stubborn violations..
procedure CleanViolations;
var
    Iterator  : IPCB_BoardIterator;
    Violation : IPCB_Violation;
    Via       : IPCB_Via;
    VObjList  : TObjectList;
    I         : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

// broken weird behaviour so hide.

    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;
