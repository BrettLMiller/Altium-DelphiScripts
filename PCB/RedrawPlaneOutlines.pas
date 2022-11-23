{..............................................................................
 RedrawPlaneOutlines.pas

 Deletes/replaces all plane outline primitives in Pcb.

 If run with selected object then only remove that & no auto-redraw

 Author: BL Miller
 23/11/2022  v0.1  POC delete selected object.


             //      eBoardOutlineObject  not on plane layer
             //      eSplitPlanePolygon  returns childen ?.
             //      eSplitPlaneObject   TSplitPlaneAdaptor child one Region
.............................................................................}
const
   AutoRedrawOutlines = true;          // redraw all plane outlines.
   StripAllOutlines   = true;          // remove outlines from all layers not just non-plane layers.

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
        if (Prim.Layer >= eInternalPlane1) and (Prim.Layer <= eInternalPlane16) then continue;

        DeleteList.Add(Prim);
    end;

    for I := 1 to BOLine.GetPrimitiveCount(Mkset(eArcObject)) do
    begin
        Prim := BOLine.GetPrimitiveAt(I, eArcObject);

//        if Prim.Layer = eMultiLayer then continue;
        if not StripAllOutlines then
        if (Prim.Layer >= eInternalPlane1) and (Prim.Layer <= eInternalPlane16) then continue;

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
        Board.RemovePCBObject(Prim);
        PCBServer.DestroyPCBObject(Prim);
    end;
    DeleteList.Clear;

    PCBServer.PostProcess;

    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
End;
{..............................................................................}
