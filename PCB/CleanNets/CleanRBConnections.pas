{ CleanRBConnections.pas

Run CleanNets() for all connection objects.

Sometimes moving rooms & groups of components leaves unresolved
connections (rubberbands)

<SHIFT>  move locked components, move if other end is NOT a CMP
<CTRL>   extended selection: leave moved FP selected, allow group move.

<ALT>   is not available with ChooseLocation()   check this is consistent AD17 & AD21

B. Miller
12/07/2019 : v0.1  Initial POC
04/09/2019 : v0.2  Fix modifying Connections inside iterator loop!
29/07/2022 : v0.21 fix modifier keys & add "locked" support.
2023-07-19 : v0.22 fix TCoord maths problems.
2023-07-30 : v0.23 allow <SHIFT> to move CMP connected to non-comp net (via, region etc)
}
const
    cESC      =-1;
    cAltKey   = 1;
    cShiftKey = 2;
    cCntlKey  = 3;

    cDebugF   = false;

var
    Board  : IPCB_Board;
    Keyset : TSet;
    Report : TStringList;

Procedure CleanUpNetConnections(Board : IPCB_Board);
var
    Connect  : IPCB_Connection;
    Iterator : IPCB_BoardIterator;
    Net      : IPCB_Net;
    NetList  : TStringList;
    N        : integer;

begin
    NetList := TStringList.Create;
    NetList.Sorted := true;
    NetList.Duplicates := dupIgnore;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Connect := Iterator.FirstPCBObject;
    while (Connect <> Nil) Do
    begin
        Net := Connect.Net;
        if Net <> Nil then
            NetList.AddObject(Net.Name, Net);

        Connect := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    for N := 0 to (NetList.Count - 1) do
    begin
        Net := NetList.Objects(N);
        Board.CleanNet(Net);
    end;
    NetList.Free;
end;

function TestInsideBoard(Component : IPCB_Component) : boolean;
// for speed.. any part of comp touches or inside BO
var
    BOL    : IPCB_BoardOutline;
    Prim   : IPCB_Primitive;
    PIter  : IPCB_GroupIterator;
begin

    BOL := Board.BoardOutline;
//    Result := BOL.PrimitiveInsidePoly(Component);
    Result := false;
    PIter  := Component.GroupIterator_Create;
    PIter.AddFilter_ObjectSet(MkSet(ePadObject, eRegionObject));
    Prim := PIter.FirstPCBObject;
    While (Prim <> Nil) Do
    Begin
        if Board.BoardOutline.GetState_HitPrimitive (Prim) then
//        if BOL.PrimitiveInsidePoly(Prim) then
        begin
            Result := true;
            break;
        end;
        Prim := PIter.NextPCBObject;
    End;
    Component.GroupIterator_Destroy(PIter);
end;

function CleanCompNets(FP : IPCB_Component) : boolean;
var
    Prim     : IPCB_Primitive;
    Net      : IPCB_Net;
    NetList  : TStringList;
    N, i     : integer;
begin
    Result := false;
    NetList := TStringList.Create;
    NetList.Sorted := true;
    NetList.Duplicates := dupIgnore;

    if FP.ObjectId = eComponentObject then
        for i := 1 to FP.GetPrimitiveCount(MkSet(ePadObject) ) do
        begin
            Prim := FP.GetPrimitiveAt(i, ePadObject);
            Net := Prim.Net;
            if Net <> Nil then
                NetList.AddObject(Net.Name, Net);
        end
    else
        if FP.InNet then
        begin
            Net := FP.Net;
            if Net <> Nil then
                NetList.AddObject(Net.Name, Net);
        end;

    for N := 0 to (NetList.Count - 1) do
    begin
        Net := NetList.Objects(N);
        Board.CleanNet(Net);
        Result := true;
    end;
    NetList.Free;
end;

// spatial does not work on group primitives.
function GetComponentAtXY(ObjectSet : TObjectSet, const X, const Y : TCoord) : IPCB_Component;
var
    SIterator  : IPCB_SpatialIterator;
    Prim       : IPCB_Primitive;
    Distance : TCoord;
begin
    Result := nil;
    Distance := 1000;
    SIterator := Board.SpatialIterator_Create;
    SIterator.SetState_FilterAll;
    SIterator.AddFilter_LayerSet(MkSet(eTopLayer, eBottomLayer));
    SIterator.AddFilter_ObjectSet(ObjectSet);
    SIterator.AddFilter_Area(X - Distance, Y - Distance, X + Distance, Y + Distance);
    Prim := SIterator.FirstPCBObject;

    while Prim <> Nil do
    begin
        if Prim.InComponent then
        begin
            Result := Prim.Component;
            break;
        end;
        Prim := SIterator.NextPCBObject;
    end;
    Board.SpatialIterator_Destroy(SIterator);
end;

procedure MoveCompToXY(Prim : IPCB_Primitive, x: TCoord, y : TCoord);
begin
    if Prim = nil then exit;
    if not Prim.Moveable then
    if not InSet(cShiftKey, KeySet) then exit;

    Prim.BeginModify;
    Prim.MoveToXY(x,y);
    Prim.EndModify;
    Board.ViewManager_GraphicallyInvalidatePrimitive(Prim);

    CleanCompNets(Prim);

    if not InSet(cCntlKey, KeySet) then
        Client.SendMessage('PCB:DeSelect','Scope=All',255,Client.CurrentView);

    Prim.Selected := true;
//    Board.AddObjectToHighlightObjectList(Prim);

    Client.SendMessage('PCB:MoveObject','Drag=True|Object=Selection|ContextObject=Component',255, Client.CurrentView);

// try these to get on cursor.
//    ResetParameters;
//    AddStringParameter('RepositionSelected', 'True');
//    RunProcess('PCB:PlaceComponent');
end;

function GreaterMagnitude(FP1 : IPCB_Primitive, FP2 : IPCB_Primitive, x : TCoord, y : TCoord) : IPCB_Primitive;
var
    SMag1, SMag2 : double;
    BR1, BR2     : TRect;
    CP1, CP2     : TCoordPoint;
begin
    Result := FP1;
    if Result = nil then
    begin
        Result := FP2;
        exit;
    end;
    BR1 := FP1.BoundingRectangleForSelection;
    BR2 := FP2.BoundingRectangleForSelection;
    CP1 := Point(BR1.X1 + RectWidth(BR1)/2, BR1.Y1 + RectHeight(BR1)/2);
    CP2 := Point(BR2.X1 + RectWidth(BR2)/2, BR2.Y2 + RectHeight(BR2)/2);

    SMag1 := Power((x - CP1.X), 2) + Power((y - CP1.Y), 2);
    SMag2 := Power((x - CP2.X), 2) + Power((y - CP2.Y), 2);
    SMag1 := Sqrt(SMag1);
    SMag2 := Sqrt(SMag2);

    Report.Add('FP1:' + FloatValueToString(SMag1, eMil) + '  FP2:' + FloatValueToString(SMag2, eMil));
    if SMag2 > SMag1 then Result := FP2;
end;

Procedure LassoCMPsByConnection;
var
    Connect     : IPCB_Connection;
    Iterator    : IPCB_BoardIterator;
    SIterator   : IPCB_SpatialIterator;
    FP1, FP2    : IPCB_Component;
    Net         : IPCB_Net;
    LayerSet    : IPCB_LayerSet;
    Prim        : IPCB_Primitive;
    x, y        : TCoord;
    NM1, NM2    : WideString;
    ObjectSet   : TObjectSet;
    msg         : WideString;
    DoAgain   : boolean;
    FP1Inside : boolean;
    FP2Inside : boolean;
    Grid      : TCoord;
    Choose    : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    Grid := Board.SnapGridSize;
    Grid := 1000;

    Report := TStringList.Create;

    Client.SendMessage('PCB:DeSelect','Scope=All',255,Client.CurrentView);

//    TV6_LayerSet := AllLayers;
    ObjectSet := MkSet(eConnectionObject);
    LayerSet := LayerSetUtils.CreateLayerSet.Include(eConnectLayer);

    msg := 'Pick your connection (ESC exit)';

    DoAgain := true;
    repeat
        Choose := Board.ChooseLocation(x, y, msg);
        if Choose <> false then  // false = ESC Key is pressed
        begin
//   read modifier keys just as/after the "pick" mouse click
           if ShiftKeyDown   then KeySet := MkSet(cShiftKey);
// can't use ALT key
           if AltKeyDown     then KeySet := SetUnion(KeySet, MkSet(cAltKey));
           if ControlKeyDown then KeySet := SetUnion(KeySet, MkSet(cCntlKey));

           SIterator := Board.SpatialIterator_Create;
           SIterator.SetState_FilterAll;
           SIterator.AddFilter_IPCB_LayerSet(LayerSet);  // (eConnectLayer);
           SIterator.AddFilter_ObjectSet(ObjectSet);
           SIterator.AddFilter_Area(X - Grid/2, Y - Grid/2, X + Grid/2, Y + Grid/2);
           Prim := SIterator.FirstPCBObject;

           while Prim <> Nil do
           begin
               break;
               Prim := SIterator.NextPCBObject;
           end;
           Board.SpatialIterator_Destroy(SIterator);

//            Prim := eNoObject;
//            Prim := Board.GetObjectAtXYAskUserIfAmbiguous(x, y, ObjectSet, TV6_LayerSet, eEditAction_Focus);         // eEditAction_DontCare

            if (Prim = Nil) then
                continue;

            Connect := Prim;
            if (Connect <> Nil) then
            begin
                Connect.Selected := true;
                Net := Connect.Net;
                if Net <> Nil then
                    Report.Add('X:' + CoordUnitToString(Connect.X1, eMil) +  ' Y:' + CoordUnitToString(Connect.Y1, eMil) );
            end;

            FP1 := GetComponentAtXY(MkSet(ePadObject), Connect.X1, Connect.Y1);
            FP2 := GetComponentAtXY(MkSet(ePadObject), Connect.X2, Connect.Y2);
            
            
            NM1 := 'no FP'; NM2 := NM1;
            if FP1 <> nil then NM1 := FP1.Name.Text;
            if FP2 <> nil then NM2 := FP2.Name.Text;
            Report.Add('FP1:' + NM1 + '  FP2:' + NM2);

            FP1Inside := false;
            if FP1 <> nil then
                FP1Inside := TestInsideBoard(FP1);

            FP2Inside := false;
            if FP2 <> nil then
                Fp2Inside := TestInsideBoard(FP2);

// only one is CMP FP
            if Not (FP1 <> nil) then
            if (FP2 <> nil) and ((not FP2Inside) or ShiftKeyDown) then
                MoveCompToXY(FP2, x, y);

            if Not(FP2 <> nil) then
            if (FP1 <> nil) and ((not FP1Inside) or ShiftKeyDown) then
                MoveCompToXY(FP1, x, y);

            if (FP1 <> nil) and (FP2 <> nil) then
            begin
                if FP1Inside and (not FP2Inside) then
                    MoveCompToXY(FP2, x, y);
                if (not FP1Inside) and FP2Inside then
                    MoveCompToXY(FP1, x, y);
// both in or both out, find not closest
                if (not FP1Inside) and (not FP2Inside) then
                begin
                    Prim := GreaterMagnitude(FP1, FP2, x,y);
                    MoveCompToXY(Prim, x, y);
                end;
                if (FP1Inside and FP2Inside) then
                begin
                    Prim := GreaterMagnitude(FP1, FP2, x,y);
                    MoveCompToXY(Prim, x, y);
                end;
            end;

        end
        else
            DoAgain := false;

    until not(DoAgain);

    if cDebugF then
        Report.SaveToFile('c:\temp\debug.txt');
end;

procedure RubberBandMan;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BeginHourGlass(crHourGlass);

    CleanUpNetConnections(Board);

    Board.SetState_DocumentHasChanged;
    Board.GraphicallyInvalidate;

    EndHourGlass;
    Board.GraphicalView_ZoomRedraw;
end;

procedure CleanNetsProcessCall;
begin
    Client.SendMessage('PCB:Netlist', 'Action=CleanUpNets|Prompt=false' , 255, Client.CurrentView);
end;

