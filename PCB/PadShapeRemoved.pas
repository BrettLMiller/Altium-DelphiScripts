{ PadShapeRemoved.pas
    detects pads removed from Pads & Vias (Tools / Remove Unused Pad shapes)
    selects these P&V & adds to report.

Author : BL Miller
20231214 : 0.1  POC
20231217 : 0.11 set net override colour to Pads&Vias & highlight (select)

TBD: use NetViaAntenna.pas code to detect connection to primitives on Layer.

IPCB_Pad.RestoreUnusedPads;
howto for Vias: copy StackSizeOnLayer() to SizeOnLayer() ??
}

var
    PCBLib         : IPCB_Library;
    Board          : IPCB_Board;
    MLayerStack    : IPCB_MasterLayerStack;
    Report         : TStringList;

procedure main;
var
    LayerObj    : IPCB_LayerObject;
    LayerClass  : TLayerClassID;
    LS          : IPCB_LayerSet;
    BIterator   : IPCB_BoardIterator;
    PV          : IPCB_Primitive;
    CMP         : IPCB_Component;
    Layer       : TLayer;
    ANet        : IPCB_Net;
    NetName     : WideString;
    CMPRefDes   : WideString;
    bRemoved    : boolean;
    IPCB_Via;
    IPCB_Pad;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    MLayerStack := Board.MasterLayerStack;
    LayerClass := eLayerClass_Electrical;  //signal
    LS := LayerSetUtils.CreateLayerSet.Include(eMultiLayer);

    Report := TStringList.Create;

    // LS.IncludeInternalPlaneLayers;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_IPCB_LayerSet(LS);
    BIterator.AddFilter_ObjectSet(MkSet(ePadObject, eViaObject));
    PV := Biterator.FirstPCBObject;
    while PV <> nil do
    begin
        CMPRefDes := '';
        NetName := 'no net';

        if PV.InComponent then
        begin
            CMP := PV.Component;
            CMPRefDes := CMP.Name.Text;
        end;
        if PV.InNet then
        begin
            ANet := PV.Net;
            NetName := ANet.Name;
        end;

        LayerObj := MLayerStack.First(LayerClass);
        While (LayerObj <> Nil ) do
        begin
            Layer := LayerObj.V7_LayerID.ID;

            bRemoved := false;

            if PV.ObjectID = eViaObject then
            if PV.IntersectLayer(Layer) then
            if PV.SizeOnLayer(Layer) <= PV.HoleSize then
                bRemoved := true;

            if PV.ObjectId = ePadObject then
            if PV.IsPadRemoved(Layer) then
                bRemoved := true;

            if bRemoved then
            begin
                if PV.InNet then
                begin
                    ANet.OverrideColorForDraw := true;
                 //   ANet.LiveHighlightMode := eHighlight_Thicken;  // Dim;
                 //   ANet.SetState_IsHighlighted(true);
                 //   Board.AddObjectToHighlightObjectList(ANet);
                end;

                Board.AddObjectToHighlightObjectList(PV);

//                PV.Selected := true;
//                ShowMessage('PV pad removed : ' + PV.Descriptor + '  ' + Layer2String(Layer));
                Report.Add(PV.Descriptor + ' | ' + Layer2String(Layer) + ' | ' + CMPRefDes + ' | ' + NetName);
            end;

            LayerObj := MLayerStack.Next(Layerclass, LayerObj);
        end;

        PV := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);
    Board.GraphicallyInvalidate;
    Board.SetState_Navigate_HighlightObjectList(eHighlight_Dim, true);

    Board.ViewManager_FullUpdate;

    Report.SaveToFile(ExtractFilePath(Board.FileName) + 'PV-pad-removedreport.txt' );
end;

procedure UnHighlightNets;
var
    BIterator   : IPCB_BoardIterator;
    ANet        : IPCB_Net;
begin
    Board  := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_IPCB_LayerSet(LayerSetUtils.AllLayers);
    BIterator.AddFilter_ObjectSet(MkSet(eNetObject));
    ANet := Biterator.FirstPCBObject;
    while ANet <> nil do
    begin
        ANet.OverrideColorForDraw := false;
        ANet.LiveHighlightMode := eHighlight_Graph;
        ANet.SetState_IsHighlighted(false);
        ANet.GraphicallyInvalidate;
        ANet.ShowNetConnects;
        ANet := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;
end;
