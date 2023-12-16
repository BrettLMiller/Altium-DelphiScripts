{ NetViaAntennasDRC.pas
 Summary   Creates DRC Violations for Via Routing rules if:
           - Via is connected on only one layer
           - Via not connected at both ends
           Also runs NetAntennae Rules (rulekind).
           Creates a special (disabled) RoutingViaStyle rule to violate.

 Created by:    Petar Perisin
..............................................................................
 Modified by Randy Clemmons
 Added code to support for AD14

B. Miller
23/08/2019 : from SelectViaAntennas.pas
23/08/2019 : Add DRC violations/markers to Vias, simplified layer objects.
24/08/2019 : Remove Rule when there are no violations.
27/09/2019 : Add NetAntennae Rules check
24/10/2019 : Add 100 Coord to Via size; Message text change
14/06/2020 : Fix iterator LayerSet filter
2023-06-30 : Use DefinitionLayerIterator interface
2023-07-08 : DefintionLayerIterator is useless; use board layerstack.
           : Fix broken Planes; has never worked since before AD16.
           : Add Strict stub via detection
20230710   : use MasterLayerStack methods.
           : IsConnectedToPlane(TV6Layer) still needed (Planes are TV6)
20231216   : remove part of the CleanViolations() code that is broken. 

Extra proc CleanViolations()  just in case clean up needed at some point..
}
{..............................................................................}

const
    SpecialRuleName1 = '__Script-ViaAntennas__';
    SpecialRuleName2 = '__Script-ViaAntennaStubs__';
    SpecialRuleKind = eRule_RoutingViaStyle;
    cAllRules       = -1;

    cViaStubStrict = true;

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
function AddSpecialViaRule(const RuleName, const RuleKind : WideString, const CText : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(RuleKind);   //TRuleKind
//    PCBServer.PreProcess;
//    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
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
//    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
//    PCBServer.PostProcess;
end;

function MakeViolation(Board : IPCB_Board, Rule : IPCB_Rule, Prim : IPCB_Primitive) : IPCB_Violation;
var
   Violation : IPCB_Violation;
begin
//    Violation := PCBServer.PCBObjectFactory(eViolationObject, eNoDimension, eCreate_Default);
//    Violation.Description := 'new description';


    Violation := nil;
    if Rule.IsUnary then
//    Rule.Scope1Includes(Prim);     // adds nothing
    if Rule.CheckUnaryScope(Prim) then
        Violation := Rule.ActualCheck(Prim, nil);
    if Violation <> nil then
    begin
        Violation.Name;
        Violation.Description;
//        Violation.SetState_Name('new name');
//        Violation.SetState_Description('new description');
//        Violation.Description := 'new description';
//        Violation.Detail := 'new detail';

        Board.AddPCBObject(Violation);
        Prim.SetState_DRCError(true);
        Prim.GraphicallyInvalidate;
    end;
    Result := Violation;
end;

procedure SelectViaAntennas;
var
    Iter           : IPCB_BoardIterator;
    SpatIter       : IPCB_SpatialIterator;
    PlaneIter      : IPCB_Iterator;
    SPRGIter       : IPCB_GroupIterator;
    Via            : IPCB_Via;
    Violation      : IPCB_Violation;
    Prim           : IPCB_Primitive;
    SplitPlane     : IPCB_SplitPlane;
    SplitPlaneReg  : IPCB_SplitPlaneRegion;
    LayerObj       : IPCB_LayerObject;
    PLayerSet      : IPCB_LayerSet;
    Layer          : TLayer;
    TV7_Layer      : IPCB_TV7_Layer;
    Rectangle      : TCoordRect;
    Rule1          : IPCB_Rule;
    Rule2          : IPCB_Rule;
    Rule3          : IPCB_Rule;
    RulesList      : TObjectList;
    Connection     : Integer;
    ViolCount      : integer;
    ViolCount2     : integer;
    S, VersionStr  : String;
    MajorADVersion : Integer;
    found          : Boolean;
    R, SP          : integer;
    StartLayer     : IPCB_LayerObject;
    StopLayer      : IPCB_LayerObject;
    ConnOnStart    : boolean;
    ConnOnStop     : boolean;
    Connected      : boolean;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    PCBServer.SystemOptions;
    Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

// Check AD version for layer stack version
    VersionStr := Client.GetProductVersion;
    S := Copy(VersionStr,0,2);
    MajorADVersion := StrToInt(S);

    LayerStack := Board.MasterLayerStack;

// clear existing violations
    if ConfirmNoYes('Clear Existing DRC Violation Markers ? ') then
        Client.SendMessage('PCB:ResetAllErrorMarkers', '', 255, Client.CurrentView);

    BeginHourGlass(crHourGlass);

// test for special rule
//    RulesList := TObjectList.Create;
    RulesList := GetMatchingRulesFromBoard(SpecialRuleKind);

    Rule1      := FoundRuleName(RulesList, SpecialRuleName1);
    Rule2      := FoundRuleName(RulesList, SpecialRuleName2);
// load builtin NetAntennae rule
    RulesList := GetMatchingRulesFromBoard(eRule_NetAntennae);

    if Rule1 = nil then  Rule1 := AddSpecialViaRule(SpecialRuleName1, SpecialRuleKind, 'Disabled ViaAntenna violations');
    if Rule1 <> nil then Rule1.DRCEnabled := true;
    if cViaStubStrict then
    begin
        if Rule2 = nil then  Rule2 := AddSpecialViaRule(SpecialRuleName2, SpecialRuleKind, 'Disabled ViaAntenna Stubs violations');
        if Rule2 <> nil then Rule2.DRCEnabled := true;
    end;

    ViolCount  := 0;
    ViolCount2 := 0;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.IncludeSignalLayers;
    PLayerSet.Include(eMultiLayer);

    Iter := Board.BoardIterator_Create;
    Iter.AddFilter_ObjectSet(MkSet(eViaObject));
    Iter.AddFilter_IPCB_LayerSet(PLayerSet);         // SignalLayers &  eMultiLayer

    PlaneIter := Board.BoardIterator_Create;
    PlaneIter.AddFilter_ObjectSet(MkSet(eSplitPlaneObject));

    SpatIter := Board.SpatialIterator_Create;
    SpatIter.AddFilter_ObjectSet(MkSet(eTrackObject, eArcObject, ePadObject, eFillObject, eRegionObject));

    Via := Iter.FirstPCBObject;
    while (Via <> nil) do
    begin
        Connection  := 0;
        ConnOnStart := false;
        ConnOnStop  := false;

        Via.SetState_DRCError(false);           // clear marker used without REAL violation object

        Rectangle  := Via.BoundingRectangle;
        StartLayer := nil;
        StopLayer  := nil;

        LayerObj := LayerStack.First(eLayerClass_Electrical);
        while LayerObj <> nil do
        begin
            if Via.StartLayer = LayerObj then
                StartLayer := LayerObj;
            if Via.StopLayer = LayerObj then
                StopLayer := LayerObj;

            Connected   := false;

            TV7_Layer := LayerObj.V7_LayerID;
            Layer := TV7_Layer.ID;
//            showmessage(intTostr(Layer));
            PLayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);

//  signal layers
            if Via.IntersectLayer(Layer) then
            if LayerUtils.IsSignalLayer(Layer) then
            begin
                found := false;

                SpatIter.AddFilter_Area(Rectangle.Left - 100, Rectangle.Bottom - 100, Rectangle.Right + 100, Rectangle.Top + 100);
                SpatIter.AddFilter_IPCB_LayerSet(PLayerSet);

                Prim := SpatIter.FirstPCBObject;
                while (Prim <> Nil) Do
                begin
                    if (Prim.ObjectID = ePadObject) then
                    begin
                        if Prim.ShapeOnLayer(Layer) <> eNoShape then found := true;
                    end else
                        if (Prim.Layer = Layer) then found := true;

//                   ShowMessage('PP distance ' + IntToStr(Board.PrimPrimDistance(Prim, Via)) );
                    if found then
                    if Board.PrimPrimDistance(Prim, Via) = 0 then
                    begin
                        Connected := true;
                        Inc(Connection);
                        break;
                    end;
                    Prim := SpatIter.NextPCBObject;
                end;
            end;

//  Plane layers
            if Via.IntersectLayer(Layer) then
            if Via.GetState_IsConnectedToPlane(Layer) then
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
                        if Board.PrimPrimDistance(SplitPlaneReg, Via) = 0 then
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
// stubs
            if Connected then
            begin
                if LayerObj = StartLayer then ConnOnStart := true;
                if LayerObj = StopLayer  then ConnOnStop  := true;
            end;

            LayerObj := LayerStack.Next(eLayerClass_Electrical, LayerObj);
        end;

        if Connection = 1 then
        begin
            Violation := nil;
            if Rule1 <> nil then
                Violation := MakeViolation(Board, Rule1, Via);
            if Violation <> nil then inc(ViolCount);
      //      Via.Selected := True;
        end;

        if cViaStubStrict then
        if not (ConnOnstart and ConnOnStop) then
        begin
            Violation := nil;
            if Rule2 <> nil then
                Violation := MakeViolation(Board, Rule2, Via);
            if Violation <> nil then inc(ViolCount2);
        end;

        for R := 0 to (RulesList.Count - 1) do
        begin
            Rule3 := RulesList.Items(R);
            Violation := MakeViolation(Board, Rule3, Via);
            if Violation <> nil then inc(ViolCount);
        end;

        Via := Iter.NextPCBObject;
    end;

    Board.SpatialIterator_Destroy(SpatIter);
    Board.BoardIterator_Destroy(PlaneIter);
    Board.BoardIterator_Destroy(Iter);

//   need to retain rules to make DRC UI display violation interactive
    if Rule1 <> nil then
    begin
        Rule1.DRCEnabled := false;
        if ViolCount = 0 then
        begin
            Board.RemovePCBObject(Rule1);
            PCBServer.DestroyPCBObject(Rule1);
        end;
    end;
    if Rule2 <> nil then
    begin
        Rule2.DRCEnabled := false;
        if ViolCount2 = 0 then
        begin
            Board.RemovePCBObject(Rule2);
            PCBServer.DestroyPCBObject(Rule2);
        end;
    end;

    ShowInfo (IntToStr(ViolCount) + ' VIA antenna + ' + IntToStr(Violcount2) + ' stub Violations found/DRC marked');
    EndHourGlass;

    Board.ViewManager_FullUpdate;
end;


// Just in case some clean up is required to remove stubborn violations..
procedure CleanViolations;
var
    Iterator  : IPCB_BoardIterator;
    Violation : IPCB_Violation;
    Via       : IPCB_Via;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    PCBServer.PreProcess;
    Board.BeginModify;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eViaObject));
    Iterator.AddFilter_LayerSet(AllLayers);

    Via := Iterator.FirstPCBObject;
    while (Via <> nil) do
    begin
        Via.SetState_DRCError(false);
        Via.GraphicallyInvalidate;
        Via := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    Board.EndModify;
    PCBServer.PostProcess;
    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;
