{ SelectCMPInOutSideBOL.pas

Author BL Miller
20240405   v0.10 POC
}

procedure SelectCMPs(const InNotOut : integer);
var
    Board : IPCB_Board;
    BOL   : IPCB_BoardOutline;
    BI    : IPCB_BoardIterator;
    Prim  : IPCB_Primitive;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    BOL   := Board.BoardOutline;

    BI := Board.BoardIterator_Create;
    BI.AddFilter_ObjectSet(MkSet(eComponentObject));
    BI.AddFilter_LayerSet(AllLayers);

    Prim := BI.FirstPCBObject;
    While Prim <> nil do
    begin
        if (InNotOut = eInside) then
        if BOL.PrimitiveInsidePoly(Prim) then
            Prim.Selected := true;

        if (InNotOut = eOutSide) then
        if not BOL.PrimitiveInsidePoly(Prim) then
            Prim.Selected := true;

        Prim := BI.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BI);
end;

procedure Inside;
begin
    SelectCMPs(eInside);
end;

procedure Outside;
begin
    SelectCMPs(eOutside);
end;

