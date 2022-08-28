{ CleanRBConnections.pas

Run CleanNets() for all connection objects.

Sometimes moving rooms & groups of components leaves unresolved 
connections (rubberbands)

<SHIFT>  move locked components
<CTRL>   extended selection.

<ALT>   is not available with ChooseLocation()   check this is consistent AD17 & AD21

B. Miller
12/07/2019 : v0.1  Initial POC
04/09/2019 : v0.2  Fix modifying Connections inside iterator loop!
29/07/2022 : v0.21 fix modifier keys & add "locked" support.

}
const
    cESC      =-1;
    cAltKey   = 1;
    cShiftKey = 2;
    cCntlKey  = 3;

var
    Board  : IPCB_Board;
    Keyset : TSet;

procedure CleanNetsProcessCall;
begin
    Client.SendMessage('PCB:Netlist', 'Action=CleanUpNets|Prompt=false' , 255, Client.CurrentView);
end;

Procedure CleanUpNetConnections(Board : IPCB_Board);
var
    Connect  : IPCB_Connection;
    Iterator : IPCB_BoardIterator;
    Net      : IPCB_Net;
    NetList  : TObjectList;
    N        : integer;

begin
    NetList := TObjectList.Create;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Connect := Iterator.FirstPCBObject;
    while (Connect <> Nil) Do
    begin
        Net := Connect.Net;
        if Net <> Nil then
            if NetList.IndexOf(Net) = -1 then
                NetList.Add(Net);

        Connect := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    for N := 0 to (NetList.Count - 1) do
    begin
        Net := NetList.Items(N);
        Board.CleanNet(Net);
    end;
    NetList.Destroy;
end;

function TestInsideBoard(Component : IPCB_Component) : boolean;
// for speed.. any part of comp touches or inside BO
var
    Prim   : IPCB_Primitive;
    PIter  : IPCB_GroupIterator;
begin
    Result := false;
    PIter  := Component.GroupIterator_Create;
    PIter.AddFilter_ObjectSet(MkSet(ePadObject, eRegionObject));
    Prim := PIter.FirstPCBObject;
    While (Prim <> Nil) and (not Result) Do
    Begin
        if Board.BoardOutline.GetState_HitPrimitive (Prim) then
            Result := true;
        Prim := PIter.NextPCBObject;
    End;
    Component.GroupIterator_Destroy(PIter);
end;

function CleanCompNets(FP : IPCB_Component) : boolean;
var
    Prim       : IPCB_Primitive;
    Net      : IPCB_Net;
    NetList  : TObjectList;
    N, i     : integer;
begin
    Result := false;
    NetList := TObjectList.Create;
    NetList.OwnsObjects := false;

    if FP.ObjectId = eComponentObject then
        for i := 1 to FP.GetPrimitiveCount(MkSet(ePadObject) ) do
        begin
            Prim := FP.GetPrimitiveAt(i, ePadObject);
            Net := Prim.Net;
            if Net <> Nil then
                if NetList.IndexOf(Net) = -1 then
                    NetList.Add(Net);
        end
    else
        if FP.InNet then
        begin
            Net := Prim.Net;
                if Net <> Nil then
                    if NetList.IndexOf(Net) = -1 then
                        NetList.Add(Net);
        end;

    for N := 0 to (NetList.Count - 1) do
    begin
        Net := NetList.Items(N);
        Board.CleanNet(Net);
        Result := true;
    end;
    NetList.Destroy;
end;

function GetComponentAtXY(ObjectSet : TObjectSet, X,Y : TCoord) : IPCB_Component;
var
    SIterator  : IPCB_SpatialIterator;
    Prim       : IPCB_Primitive;
    Distance : TCoord;
begin
    Result := nil;
    Distance := 100;
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

    PCBServer.SendMessageToRobots(Prim.I_ObjectAddress, c_Broadcast, PCBM_BeginModify , c_NoEventData);
    Prim.BeginModify;
    Prim.MoveToXY(x,y);
    Prim.EndModify;
    PCBServer.SendMessageToRobots(Prim.I_ObjectAddress, c_Broadcast, PCBM_EndModify , c_NoEventData);

    Prim.SetState_XSizeYSize;
    Board.ViewManager_GraphicallyInvalidatePrimitive(Prim);
//    Prim.GraphicallyInvalidate;

    if not InSet(cCntlKey, KeySet) then
        Client.SendMessage('PCB:DeSelect','Scope=All',255,Client.CurrentView);

    Prim.Selected := true;
    Board.AddObjectToHighlightObjectList(Prim);
    CleanCompNets(Prim);

    Client.SendMessage('PCB:MoveObject','Drag=True|Object=Selection|ContextObject=Component',255, Client.CurrentView);
end;

function GreaterMagnitude(FP1 : IPCB_Primitive, FP2 : IPCB_Primitive, x : TCoord, y : TCoord) : IPCB_Primitive;
var
    SMag1, SMag2 : double;
    BR1, BR2     : TRect;
begin
    Result := FP1;
    if Result = nil then
    begin
        Result := FP2;
        exit;
    end;
    BR1 := FP1.BoundingRectangle;
    BR2 := FP2.BoundingRectangle;

    SMag1 :=            (x - BR1.X1)*(x - BR1.X1) + (y - BR1.Y1)*(y - BR1.Y1);
    SMag1 := Min(SMag1, (x - BR1.X2)*(x - BR1.X2) + (y - BR1.Y1)*(y - BR1.Y1) );
    SMag1 := Min(SMag1, (x - BR1.X2)*(x - BR1.X2) + (y - BR1.Y2)*(y - BR1.Y2) );
    SMag1 := Min(SMag1, (x - BR1.X1)*(x - BR1.X1) + (y - BR1.Y2)*(y - BR1.Y2) );

    SMag2 :=            (x - BR2.X1)*(x - BR2.X1) + (y - BR2.Y1)*(y - BR2.Y1);
    SMag2 := Min(SMag2, (x - BR2.X2)*(x - BR2.X2) + (y - BR2.Y1)*(y - BR2.Y1) );
    SMag2 := Min(SMag2, (x - BR2.X2)*(x - BR2.X2) + (y - BR2.Y2)*(y - BR2.Y2) );
    SMag2 := Min(SMag2, (x - BR2.X1)*(x - BR2.X1) + (y - BR2.Y2)*(y - BR2.Y2) );
    if SMag2 > SMag1 then Result := FP2;
end;


function GetStatusBar : WideString;
var
    GUIMan       : IGUIManager;
    ClientModule : IClient;
    S            : WideString;
    Focus        : WideString;

begin
    ClientModule := Client;
    If ClientModule = Nil Then Exit;
    GUIMan := ClientModule.GUIManager;
    If GUIMan = Nil Then Exit;

    GUIMan.StatusBar_GetState(0,Text);
    Result := GUIMan.StatusBar_GetState(0);
//    Focus := GUIMan.GetFocusedPanelName;
end;
Procedure SetStatusBar(Text : WideString);
var
    GUIMan       : IGUIManager;
    ClientModule : IClient;
begin
    ClientModule := Client;
    If ClientModule = Nil Then Exit;
    GUIMan := ClientModule.GUIManager;
    If GUIMan = Nil Then Exit;
    GUIMan.StatusBar_SetState(0,Text);
end;

Procedure LassoCompByConnections;
var
    Connect     : IPCB_Connection;
    Iterator    : IPCB_BoardIterator;
    SIterator   : IPCB_SpatialIterator;
    FP1, FP2    : IPCB_Component;
    Net         : IPCB_Net;
    LayerSet    : IPCB_LayerSet;
    Prim        : IPCB_Primitive;
    x, y        : TCoord;
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

    Client.SendMessage('PCB:DeSelect','Scope=All',255,Client.CurrentView);

//    TV6_LayerSet := AllLayers;
    ObjectSet := MkSet(eConnectionObject);
    LayerSet := LayerSetUtils.EmptySet.Include(eConnectLayer);

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
           SIterator.AddFilter_Area(X - Grid, Y - Grid, X + Grid, Y + Grid);
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
//                    ShowMessage('net name : '+ Net.Name);
                    SetStatusBar((Net.Name));
 //               ShowMessage('X:' + IntToStr(Connect.X1) +  ' Y:' +IntToStr(Connect.Y1));
            end;

            FP1 := GetComponentAtXY(MkSet(ePadObject, eComponentObject, eRegionObject), Connect.X1, Connect.Y1);
            FP2 := GetComponentAtXY(MkSet(ePadObject, eComponentObject, eRegionObject), Connect.X2, Connect.Y2);

            FP1Inside := false;
            if FP1 <> nil then
                FP1Inside := TestInsideBoard(FP1);

            FP2Inside := false;
            if FP2 <> nil then
                Fp2Inside := TestInsideBoard(FP2);
// in Board
            if (FP1 = nil) and (not FP2Inside) then
                MoveCompToXY(FP2, x, y)
            else if (FP2 = nil) and (not FP1Inside) then
                MoveCompToXY(FP1, x, y)
            else if FP1Inside and (not FP2Inside) then
                MoveCompToXY(FP2, x, y)
            else if (not FP1Inside) and FP2Inside then
                MoveCompToXY(FP1, x, y)
// both in or both out, find not closest
            else if (not FP1Inside) and (not FP2Inside) then
            begin
                Prim := GreaterMagnitude(FP1, FP2, x,y);
                MoveCompToXY(Prim, x, y);
            end
            else if (FP1Inside and FP2Inside) then
            begin
                Prim := GreaterMagnitude(FP1, FP2, x,y);
                MoveCompToXY(Prim, x, y);
            end;
        end
        else
            DoAgain := false;

    until not(DoAgain);
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

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 1024, Client.CurrentView);
end;
