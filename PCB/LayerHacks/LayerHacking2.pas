{ LayerHacking2.pas
Selects all objects on required mech layer "myLayer".
myLayer can be InSetRange(1, 32)

Why:
Iterator Filters do not work with layers above eMechanical 16.
Note:
eMechanical17 to eMechanical32 are not defined.
Board.CurrentLayer fails above eMechanical 32 & the
 values returned from eMech17 - 32 are very strange.
Scripting API is a borked CF w.r.t. mech layers

Author B. Miller
10/09/2019 : V0.1 POC

}

procedure SelectBadLayer;
const
    myLayer = 29;          // == eMechanical 29

 var
    PCBSysOpts      : IPCB_SystemOptions;
    Board           : IPCB_Board;
    LayerStack      : IPCB_LayerStack_V7;
    Layer           : TLayer;
    LayerName       : WideString;
    LayerObject     : IPCB_LayerObject_V7;
    CurrentLayer    : integer;
    TargetLayerName : WideString;

    MechLayer     : IPCB_MechanicalLayer;
    i, ML1        : integer;
    SLMCache      : boolean;

    Primitive : IPCB_Primitive;
    ObjList   : TObjectList;

    FileName  : TPCBString;
    Document  : IServerDocument;
    Rpt       : TStringList;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;
    PCBSysOpts := PCBServer.SystemOptions;
    if PCBSysOpts = Nil then exit;

    SLMCache := PCBSysOpts.SingleLayerMode;
    PCBSysOpts.SingleLayerMode := true;

    Rpt := TstringList.Create;
    CurrentLayer := Board.CurrentLayer;
    Rpt.Add('Current layer : ' + PadRight(IntToStr(CurrentLayer),3) + ' ' +  Layer2String(CurrentLayer));

// enable & display required mech layer
    LayerStack := Board.LayerStack_V7;
    ML1 := LayerUtils.MechanicalLayer(myLayer);
    MechLayer := LayerStack.LayerObject_V7(ML1);
    if not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        Rpt.Add('Mech Layer Enabled : ' + LayerUtils.AsString(ML1) );
    end;
    if not MechLayer.IsDisplayed(Board) then
    begin
        MechLayer.IsDisplayed(Board) := true;
        Rpt.Add('Mech Layer Displayed : ' + LayerUtils.AsString(ML1) );
    end;

    Board.ViewManager_UpdateLayerTabs;

// cycle thru to required mech layer
    TargetLayerName :=  LayerUtils.AsString(ML1);
    i := 0;     // rogue safety
    repeat
        ResetParameters;
        AddStringParameter('LayerName','Next');
        RunProcess('PCB:SetCurrentLayer');

        CurrentLayer := Board.CurrentLayer;

        LayerObject := LayerStack.LayerObject_V7(CurrentLayer);
        LayerName := 'Broken method NO name';
        if LayerObject <> Nil then                  // 3 different indices for the same object info, Fg Madness!!!
            LayerName := LayerObject.Name;

        Rpt.Add( IntToStr(CurrentLayer) + ' ' + LayerUtils.AsString(CurrentLayer) + '  ' + Board.LayerName(CurrentLayer) + '  ' + LayerName);
        Layer2String(CurrentLayer);

        inc(i);
    until (LayerUtils.AsString(CurrentLayer) = TargetLayerName ) or (i > 100);

    if LayerUtils.AsString(CurrentLayer) = TargetLayerName then
    begin
// to be sure nothing else is selected perform a deselect all
        ResetParameters;
        AddStringParameter('Scope','All');
        RunProcess('PCB:Deselect');

// select all on layer.
        ResetParameters;
        AddStringParameter('Scope','Layer');
        RunProcess('PCB:Select');

 {       Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eTrackObject,eArcObject));

   // >>>>>  Iterator.AddFilter_LayerSet(MkSet(eMechanical1));  <<<<<<<<<<   // can NOT use this

        Iterator.AddFilter_Method(eProcessAll);
        ArcOrTrack := Iterator.FirstPCBObject;       // new iteration
        while (ArcOrTrack <> Nil) do
        begin
            ArcOrTrack.Selected := True;
            ArcOrTrack := Iterator.NextPCBObject;  // next object in the iteration
        end;
}

// iterate selected objected & make a ObjectList. deselect any that are  not trk or arc
// must NOT modify iterated objects
        ObjList := TObjectList.Create;
        for i := 0 to (Board.SelectecObjectCount - 1) do
        begin
            Primitive := Board.SelectecObject [i];
            if InSet(Primitive.ObjectId, MkSet(eTrackObject,eArcObject)) then
                ObjList.Add(Primitive);
        end;

        ResetParameters;
        AddStringParameter('Scope','All');
        RunProcess('PCB:Deselect');

        for i := 0 to (ObjList.Count - 1) do
        begin
            Primitive := ObjList.Items(i);
            Primitive.Selected := true;
        end;
        ObjList.Destroy;

// generate new BO
//        ResetParameters();
//        AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
//        RunProcess('PCB:PlaceBoardOutline');


    end;

// restore single layer mode
    PCBSysOpts.SingleLayerMode := SLMCache;

    // Display the Report
    FileName := ExtractFilePath(Board.FileName) + ChangefileExt(ExtractFileName(Board.FileName),'') + '-mechlayers.rep';
    Rpt.SaveToFile(Filename);
    Rpt.Free;

// comment out after debugging etc
    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
        Document.DoFileLoad;
    end;
end;
{.............................................
