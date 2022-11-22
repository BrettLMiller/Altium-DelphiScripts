{..............................................................................
 DeleteSelectedPlaneBorderTrack.pas

 Specific targeting of poly track/arc border (pullback) of plane layers.

 MUST Zoom-select offending track/arc with PCBList.

 Can delete trk/arc from components FPs & hatched polygons.
 
 
 Author BL Miller
 22/11/2022  v0.1  POC delete selected trk/arc primitive object.

.............................................................................}


Procedure DeleteSelectedItem;
Var
    Board             : IPCB_Board;
    Comp              : IPCB_Component;
    Prim              : IPCB_Primitive;
    Polygon           : IPCB_Polygon;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowMessage('This is not a Pcb document');
        Exit;
    End;

    PCBServer.PreProcess;

    if Board.SelectecObjectCount = 1 then
    begin
        Prim := Board.SelectecObject(0);
        if (Prim.ObjectId = eTrackObject) or (Prim.ObjectId = eArcObject) then
        begin
            if Prim.Enabled_vPolygon then
            begin
                Polygon := Prim.Polygon;     //track on plane pullback TBoardOutlineAdaptor.
                Polygon.RemovePCBObject(Prim);
            end;

// pointless as replaced by any repour
            if Prim.InPolygon then
            begin
                Polygon := Prim.Polygon;     // hatch poly
                Polygon.RemovePCBObject(Prim);
            end;

            if Prim.InComponent then
            begin
                Comp := Prim.Component;
                Comp.RemovePCBObject(Prim);
            end;

            Board.RemovePCBObject(Prim);
            PCBServer.DestroyPCBObject(Prim);
        end;

    end;

    PCBServer.PostProcess;

    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
End;
{..............................................................................}

