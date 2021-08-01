{ CleanRBConnections.pas

Run CleanNets() for all connection objects.

Sometimes moving rooms & groups of components leaves unresolved 
connections (rubberbands)

B. Miller
12/07/2019 : v0.1  Initial POC
04/09/2019 : v0.2  Fix modifying Connections inside iterator loop!

}

procedure CleanNetsProcessCall;
var
    GUIMan : IGUIManager;

begin
    GUIMan := Client.GUIManager;
    If GUIMan = Nil Then Exit;

    GUIMan.AddKeyToBuffer(13, False, False, False);       // dnw
    GUIMan.AddKeyStrokeAndLaunch(#13);                    // dnw
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

procedure RubberBandMan;
var
    Board : IPCB_Board;
    
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
