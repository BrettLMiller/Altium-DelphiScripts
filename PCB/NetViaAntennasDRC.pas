{ NetViaAntennasDRC.pas
 Summary   If Vias are connected on only one layer, then
           a DRC Violation is raised.
           Also runs NetAntennae Rules (rulekind).                                             
           Creates a special (disabled) via rule to violate. 
                                                                              
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

Extra proc CleanViolations()  just in case clean up needed at some point..
}
{..............................................................................}

const
    SpecialRuleName = '__Script-ViaAntennas__';
    SpecialRuleKind = eRule_RoutingViaStyle;
    cAllRules       = -1;

var
    Board     : IPCB_Board;

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
function AddSpecialViaRule(const RuleName, const RuleKind : WideString) : IPCB_Rule;
begin
    Result := PCBServer.PCBRuleFactory(RuleKind);   //TRuleKind
//    PCBServer.PreProcess;
//    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
    Result.Name := RuleName;
    Result.Scope1Expression := 'IsVia';
    Result.Scope2Expression := '';
    Result.Comment          :='Disabled rule placeholder for scripted violations';
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
    Violation := nil;
    if Rule.IsUnary then
//    Rule.Scope1Includes(Prim);     // adds nothing
    if Rule.CheckUnaryScope(Prim) then
        Violation := Rule.ActualCheck(Prim, nil);
    if Violation <> nil then
    begin
        Violation.Name;
        Violation.Description;

        Board.AddPCBObject(Violation);
        Prim.SetState_DRCError(true);
        Prim.GraphicallyInvalidate;
    end;
    Result := Violation;
end;

procedure SelectViaAntennas;
var
   Iter          : IPCB_BoardIterator;
   SpIter        : IPCB_SpatialIterator;
   Via           : IPCB_Via;
   Violation     : IPCB_Violation;
   Prim          : IPCB_Primitive;
   LayerStack    : IPCB_LayerStack;
   LayerObj      : IPCB_LayerObject;
   PLayerSet     : IPCB_LayerSet;
   Layer         : TLayer;
   Rectangle     : TCoordRect;
   Rule          : IPCB_Rule;
   Rule2         : IPCB_Rule;
   RulesList     : TObjectList;
   Connection    : Integer;
   ViolCount     : integer;
   S, VersionStr : String;
   MajorADVersion : Integer;
   found          : Boolean;
   R              : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

// Check AD version for layer stack version
    VersionStr := Client.GetProductVersion;
    S := Copy(VersionStr,0,2);
    MajorADVersion := StrToInt(S);

    LayerStack := Board.LayerStack_V7;

// clear existing violations
    if ConfirmNoYes('Clear Existing DRC Violation Markers ? ') then
        Client.SendMessage('PCB:ResetAllErrorMarkers', '', 255, Client.CurrentView);

    BeginHourGlass(crHourGlass);

// test for special rule
//    RulesList := TObjectList.Create;
    RulesList := GetMatchingRulesFromBoard(SpecialRuleKind);
    Rule      := FoundRuleName(RulesList, SpecialRuleName);
// load builtin NetAntennae rule
    RulesList := GetMatchingRulesFromBoard(eRule_NetAntennae);

    if Rule = nil then  Rule := AddSpecialViaRule(SpecialRuleName, SpecialRuleKind);
    if Rule <> nil then Rule.DRCEnabled := true;

    ViolCount := 0;
    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.IncludeSignalLayers;
    PLayerSet.Include(eMultiLayer);

    Iter := Board.BoardIterator_Create;
    Iter.AddFilter_ObjectSet(MkSet(eViaObject));
    Iter.AddFilter_IPCB_LayerSet(PLayerSet);         // SignalLayers &  eMultiLayer

    SpIter := Board.SpatialIterator_Create;
    SpIter.AddFilter_ObjectSet(MkSet(eTrackObject, eArcObject, ePadObject, eFillObject, eRegionObject));

    Via := Iter.FirstPCBObject;
    while (Via <> nil) do
    begin
        Connection := 0;
        Via.SetState_DRCError(false);           // clear marker used without REAL violation object

        Rectangle := Via.BoundingRectangle;

        for Layer := Via.LowLayer to Via.HighLayer do
        begin
            LayerObj := LayerStack.LayerObject(Layer);
            LayerObj.Name;

            if LayerObj.IsInLayerStack then
            begin
                if LayerUtils.IsSignalLayer(Layer) then
                begin
                    found := false;
                    PLayerSet := LayerSetUtils.EmptySet;
                    PLayerSet.Include(Layer);

                    SpIter.AddFilter_Area(Rectangle.Left - 100, Rectangle.Bottom - 100, Rectangle.Right + 100, Rectangle.Top + 100);
                    SpIter.AddFilter_IPCB_LayerSet(PLayerSet);

                    Prim := SpIter.FirstPCBObject;
                    while (Prim <> Nil) Do
                    begin
                       if (Prim.ObjectID = ePadObject) then
                       begin
                          if Prim.ShapeOnLayer(Layer) then found := true;
                       end
                       else
                           if (Prim.Layer = Layer) then found := true;

//                       ShowMessage('PP distance ' + IntToStr(Board.PrimPrimDistance(Prim, Via)) );
                       if found then
                           if Board.PrimPrimDistance(Prim, Via) = 0 then
                           begin
                               Inc(Connection);
                               break;
                           end;

                       Prim := SpIter.NextPCBObject;
                    end;
                end
                else
                    if Via.IsConnectedToPlane(Layer) then
                        Inc(Connection);
            end;
        end;

        if Connection = 1 then
        begin
            Violation := nil;
            if Rule <> nil then
                Violation := MakeViolation(Board, Rule, Via);
            if Violation <> nil then inc(ViolCount);
      //      Via.Selected := True;
        end;

        for R := 0 to (RulesList.Count - 1) do
        begin
            Rule2 := RulesList.Items(R);
            Violation := MakeViolation(Board, Rule2, Via);
            if Violation <> nil then inc(ViolCount);
        end;
       
        Via := Iter.NextPCBObject;
    end;

    Board.SpatialIterator_Destroy(SpIter);
    Board.BoardIterator_Destroy(Iter);

    if Rule <> nil then
    begin    
        Rule.DRCEnabled := false;
//   need to retain rule to make DRC UI display violation interactive
        if ViolCount = 0 then
        begin
            Board.DestroyPCBObject(Rule);
            PCBServer.DestroyPCBObject(Rule);
        end;
    end;

    ShowInfo (IntToStr(ViolCount) + ' VIA violation(s) found/DRC marked');
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

    VObjList := TObjectList.Create;
    VObjList.OwnsObjects := false;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eViolationObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

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
    VObjList.Destroy;

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

    Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;
