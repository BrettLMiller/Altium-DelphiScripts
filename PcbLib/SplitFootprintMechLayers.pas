{..............................................................................
 SplitFootprintMechLayers.pas

 Author: BL Miller

 2024-03-23  0.1  POC
 2024-03-24  0.2  determine mech layers used first, more scalable with 1024 layers!

Notes:
Can NOT delete primitives that are referenced inside an iterator as this messes up "indexing".
Must re-create the iterator after any object deletion.
Can NOT delete primitives if FP is "current"
Selecting Comp with CurrentLib.SetState_CurrentComponent(TempPcbLibComp) clears all selections.

delete footprint..
       CurrentLib.DeRegisterComponent(TempPCBLibComp);
       PCBServer.DestroyPCBLibComp(TempPCBLibComp);
..............................................................................}

const
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;       
    AD19MaxMechLayers = 1024;

var
    VerMajor          : integer;
    MaxMechLayers     : integer;
    LegacyMLS         : boolean;

function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) : IPCB_MechanicalLayer; forward;

Procedure SplitFootprint;
Var
    CurrentLib        : IPCB_Library;
    Board             : IPCB_Board;
    LayerStack        : IPCB_LayerStack;
    SComp             : IPCB_LibComponent;
    NewFP             : IPCB_LibComponent;
    GIterator         : IPCB_GroupIterator;
    FPList            : TObjectList;
    i, j              : Integer;
    Prim              : IPCB_Primitive;
    Prim2             : IPCB_Primitive;

    HowManyInt        : Integer;
    intDialog         : Integer;

    MLayerUsed        : TStringList;
    MLIndex           : integer;
    MechLayer         : IPCB_MechanicalLayer;
    ML1               : integer;
    NewFPName         : WideString;
    MLayerSet         : IPCB_LayerSet;

Begin
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PcbLib document');
        Exit;
    End;

// Verify user wants to continue, if cancel pressed, exit script.  If OK, continue
    intDialog := MessageDlg('!!! Operation can NOT be undone, proceed with caution !!! ', mtWarning, mbOKCancel, 0);
    if intDialog = mrCancel then
    begin
        ShowMessage('Cancel pressed. Exiting ');
        Exit;
    end;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if VerMajor >= AD19VersionMajor then
    begin
        MaxMechLayers := AD19MaxMechLayers;
        LegacyMLS     := false;
    end;

    Board := CurrentLib.Board;
    LayerStack := Board.MasterLayerStack;
    SComp      := CurrentLib.GetState_CurrentComponent;

    MLayerUsed := TStringList.Create;        // mech layer used by currnet FP prims
    MLayerUsed.Sorted := true;
    MLayerUsed.Duplicates := dupIgnore;
    MLayerUsed.NameValueSeparator := '=';
    MLayerUsed.StrictDelimiter := true;

    FPList := TObjectList.Create;            // hold a list of Comp Prims
    FPList.OwnsObjects := false;

    BeginHourGlass(crHourGlass);
    PCBServer.PreProcess;

    for i := 1 to MaxMechLayers do
    begin
        MechLayer := GetMechLayerObject(LayerStack, i, ML1);
//  UsedByPrims is property of current FP !
        if MechLayer.UsedByPrims then
            MLayerUsed.Add(IntToStr(i) + '=' + IntToStr(ML1));
    end;

    HowManyInt  := 0;
//    MLayerSet := LayerSetUtils.CreateLayerSet;
//        MLayerSet.ExcludeAllLayers;
//        MLayerSet.Include(ML1);

    for i := 0 to (MLayerUsed.Count -1) do
    begin
        MLIndex := MLayerUsed.Names(i);
        ML1     := MLayerUsed.ValueFromIndex(i);

        if (true) or MechLayer.MechanicalLayerEnabled then
        begin
            FPList.Clear;
            GIterator := SComp.GroupIterator_Create;
//            GIterator.AddFilter_IPCB_LayerSet(MLayerSet);  /// dnw in group
            Prim := GIterator.FirstPCBObject;
            while Prim <> Nil Do
            begin
                if Prim.Layer = ML1 then
                    FPList.Add(Prim);
                Prim := GIterator.NextPCBObject;
            end;
            SComp.GroupIterator_Destroy(GIterator);

            if FPList.Count > 0 then
            begin
                NewFPName := SComp.Name + '_MECHLAYER' + IntToStr(MLIndex);
                NewFP      := CurrentLib.CreateNewComponent;
                NewFP.Name := CurrentLib.GetUniqueCompName(NewFPName);
                CurrentLib.RegisterComponent(NewFP);
                CurrentLib.SetState_CurrentComponent(NewFP);
                NewFP.BeginModify;
            end;

            for j := 0 to (FPList.Count -1) do
            begin
                Prim := FPList.Items(j);
                Prim2 := Prim.Replicate;
                SComp.RemovePCBObject(Prim);
                PCBServer.DestroyPCBObject(Prim);
                Board.AddPCBObject(Prim2);
                NewFP.AddPCBObject(Prim2);
// this new CMP FP is focused so origin is different to source !!
                Prim2.MoveByXY(Board.XOrigin, Board.YOrigin);
                inc(HowManyInt);
            end;

            if FPList.Count > 0 then
                NewFP.EndModify;

        end;
    end;

    FPList.Clear;
    FPList.Destroy;
    MLayerUsed.Clear;
    PCBServer.PostProcess;

//    CurrentLib.Navigate_FirstComponent;
    CurrentLib.SetState_CurrentComponent(SComp);
    CurrentLib.Board.GraphicallyInvalidate;
    CurrentLib.Board.ViewManager_FullUpdate;
    CurrentLib.Board.GraphicalView_ZoomRedraw;
    CurrentLib.RefreshView;
    EndHourGlass;

    if HowManyInt > 0 then CurrentLib.Board.SetState_DocumentHasChanged;
End;
{..............................................................................}
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) : IPCB_MechanicalLayer;
begin
    if (LegacyMLS) then
    begin
        MLID := LayerUtils.MechanicalLayer(i);
        Result := LS.LayerObject_V7(MLID)
    end else
    begin
        Result := LS.GetMechanicalLayer(i);
        MLID := Result.V7_LayerID.ID;             // .LayerID  stops working at i=16
    end;
end;


