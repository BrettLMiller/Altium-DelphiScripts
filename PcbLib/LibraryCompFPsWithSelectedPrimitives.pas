{Show Library footprints that have selected primitives.
  Works on PcbLib
  Select primitives from multiple footprints using PCBLIB List or Filter panel
  or Find Selected Objects and use the "Whole Library" option.
  Displays selected primitives as selected in the Parent footprint
  and lists the primitives viewed in the ClipBoard.

  Attempts to reselect all primitives (not completely successfully)

 Modified Brett Miller 2023-06-05
 By Eric Albach 2020-02-28
 Based on Altium's LibraryIterator.pas script

DNW in PcbLib sadly.. does NOT jump/navigate to next footprint
 PCB:Jump
 Parameters : Object = Selected | Type = Next

}

Procedure ShowFootprints;
Var
    CurrentLib        : IPCB_Library;
    Footprint         : IPCB_LibComponent;
    APrim             : IPCB_Primitive;
    APrim2            : IPCB_Primitive;
    Iterator          : IPCB_GroupIterator;
    PrimList          : TObjectList;

    bFirstTime    : Boolean;
    bFinished     : boolean;
    NoOfPrims    : Integer;
    SL           : TStringlist;
    ClipB        : TClipboard;
    intDialog    : Integer;
    I, J         : integer;
    ObjSet       : TSet;

Begin
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB Library document');
        Exit;
    End;

    if  CurrentLib.Board.SelectedObjectsCount = 0 then exit;

    PrimList := TObjectList.Create;
    PrimList.OwnsObjects := false;
    ObjSet := MkSet();

// cache selected objs as FP select for origin & bounding rect will destroy state.
    for I := 0 to (CurrentLib.Board.SelectedObjectsCount - 1) do
    begin
        APrim := CurrentLib.Board.SelectecObject(I);
        PrimList.Add(APrim);
        if not InSet(APrim.ObjectId, ObjSet) then
            ObjSet := SetUnion(Objset, MkSet(APrim.ObjectId));
    end;

    SL         := TStringList.Create;
    bFirstTime := True;
    bFinished  := false;

    CurrentLib.Navigate_FirstComponent;
    CurrentLib.Board.ViewManager_FullUpdate;    // required else zoom focus is wrong sometimes!

    for I := 0 to (CurrentLib.ComponentCount - 1) do
    begin
        Footprint := CurrentLib.GetComponent(I);
        CurrentLib.SetState_CurrentComponent(Footprint);   // this unselects all objects
        CurrentLib.RefreshView;

        If bFirstTime Then
        Begin
            SL.Add(ExtractFileName(Footprint.Board.FileName));
            SL.Add('');
            SL.Add('These footprint had selected Primitives:');
        End;
        bFirstTime := False;

        NoOfPrims := Footprint.GetPrimitiveCount(AllObjects);

        Iterator := Footprint.GroupIterator_Create;
        Iterator.SetState_FilterAll;
        Iterator.AddFilter_IPCB_LayerSet(LayerSetUtils.AllLayers);
        Iterator.AddFilter_ObjectSet(ObjSet);
        APrim := Iterator.FirstPCBObject;
        While (APrim <> Nil) Do
        Begin
            for J := 0 to (PrimList.Count - 1) do
            begin
                APrim2 := PrimList.Items(J);

                if (APrim.I_ObjectAddress = APrim2.I_ObjectAddress) then
                begin
                    SL.Add(Footprint.Name + ' | ' + APrim.ObjectIDString + ' | ' + APrim.Detail);

                    APrim.SetState_Selected(true);
                    APrim.GraphicallyInvalidate;
                    Client.SendMessage('PCB:Jump', 'Object=Selected',  255, Client.CurrentView);
                    Client.SendMessage('PCB:Zoom', 'ZoomLevel=10.0|Action=Redraw',  255, Client.CurrentView);

                    intDialog := MessageDlg(Footprint.Name + ' | ' + APrim.ObjectIDString + ' - Show Next ? ', mtConfirmation, mbOKCancel, 0);
                    if intDialog = mrCancel then
                    begin
                        bFinished := true;
                        SL.Add('exited before all listed..');
                        break;
                    end;
                end;
            end;

            if bFinished then break;

            APrim := Iterator.NextPCBObject;
        End;
        Footprint.GroupIterator_Destroy(Iterator);
        if bFinished then break;
    End;

    ShowMessage(SL.Text);
// this ONLY seems to work on the focused footprint..
    CurrentLib.Board.SelectedObjects_BeginUpdate;
    CurrentLib.Board.SelectedObjects_Clear;
    for I := 0 to (PrimList.Count) - 1 do
        CurrentLib.Board.SelectedObjects_Add(PrimList.Items(I));
    CurrentLib.Board.SelectedObjects_EndUpdate;

    PrimList.Destroy;

    ClipB := TClipboard.Create;
    ClipB.AsText := StringReplace(SL.Text, #10, #13#10, rfReplaceAll);
    SL.Clear;
    ClipB.free;
End;
{..............................................................................}

