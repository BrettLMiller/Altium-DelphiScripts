{..............................................................................
 DeleteSelectedItemsInPcbLibParts.pas

 Deletes all selected primitives in PcbLib.
 Iterate and find Selected Objects for all footprints within the current library.

 Use FSO FindSimilarObjects filter UI to preselect objects.

 Created by: Colby Siemer
 Modified by: BL Miller

 24/07/2020  v1.1  fix one object not deleting (the actual user picked obj)
 25/07/2020  v1.2  set focused doc / current view as "dirty" as required.
 26/07/2020  v1.3  Using temp FP list finally solves problem.  Use create TempComp in middle.
 15/08/2020  v1.4  Take temp FP ObjectList soln from 02.pas (26/07/2020)
 07/01/2021  v1.5  Try again with TInterfaceList & rearranged Delete() outside of GroupIterator
 08/01/2021  v1.6  Added StatusBar percentage delete progress & Cursor busy.
 03/07/2022  v1.7  refactor FP iterating simplify deleting with another objectlist.

1000 primitives takes 2:30 mins & 1GB ram

Can NOT delete primitives that are referenced inside an iterator as this messes up "indexing".
Must re-create the iterator after any object deletion.
Use of TInterfaceList (for external dll calls etc) may not be required.

Creating a temporary component is required.
Selecting Comp with CurrentLib.SetState_CurrentComponent(TempPcbLibComp) clears all selections.

delete footprint..
       CurrentLib.DeRegisterComponent(TempPCBLibComp);
       PCBServer.DestroyPCBLibComp(TempPCBLibComp);
..............................................................................}

const
    MaxObjects = 1000;
    FP = '___TemporaryComponent__DeleteMeWhenDone___';   // name for temp FP comp.

Procedure DeleteSelectedItemsFromFootprints;
Var
    GUIMan            : IGUIManager;
    CurrentLib        : IPCB_Library;
    TempPCBLibComp    : IPCB_LibComponent;

    FIterator         : IPCB_LibraryIterator;
    GIterator         : IPCB_GroupIterator;
    Footprint         : IPCB_LibComponent;

    FPList            : TObjectList;
    DeleteList        : TObjectList;
    FPDeleteList      : TObjectList;
    I, J, K           : Integer;
    MyPrim            : IPCB_Primitive;
    Prim2             : IPCB_Primitive;

    HowMany           : String;
    HowManyInt        : Integer;
    SelCountTot       : integer;
    intDialog         : Integer;
    Remove            : boolean;
    First             : boolean;                // control (limit) LibCompList to ONE instance.
    sStatusBar        : WideString;
    iStatusBar        : integer;

Begin
     GUIMan := Client.GUIManager;

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

    DeleteList  := TObjectList.Create;
    DeleteList.OwnsObjects := false;
    FPList      := TObjectList.Create;            // hold a list of affected LibComponents.
    FPList.OwnsObjects := false;

    SelCountTot := 0;
    HowManyInt  := 0;

    for I := 0 to (CurrentLib.ComponentCount - 1) do
    begin
        Footprint := CurrentLib.GetComponent(I);

        First := true;

        GIterator := Footprint.GroupIterator_Create;
//  Use a line such as the following if you would like to limit the type of items you are allowed to delete, in the example line below,
//  this would limit the script to Component Body Objects
//       GIterator.Addfilter_ObjectSet(MkSet(eComponentBodyObject));

        MyPrim := GIterator.FirstPCBObject;
        while MyPrim <> Nil Do
        begin
            if MyPrim.Selected = true then
            begin
                if (First) then FPList.Add(Footprint);
                First := false;
                DeleteList.Add(MyPrim);
                inc(SelCountTot);
            end;
            MyPrim := GIterator.NextPCBObject;
        end;
        Footprint.GroupIterator_Destroy(GIterator);

        if DeleteList.Count >= MaxObjects then break;

    end;

// these are cleared again by focusing the temp component..
    CurrentLib.Board.SelectedObjects_BeginUpdate;
    CurrentLib.Board.SelectedObjects_Clear;
    CurrentLib.Board.SelectedObjects_EndUpdate;

// Create a temporary component to hold focus while we delete items
    TempPCBLibComp := PCBServer.CreatePCBLibComp;
    TempPcbLibComp.Name := FP;
    CurrentLib.RegisterComponent(TempPCBLibComp);

// focus the temp footprint
    CurrentLib.SetState_CurrentComponent(TempPcbLibComp);
//    CurrentLib.CurrentComponent := TempPcbLibComp;
    CurrentLib.Board.ViewManager_FullUpdate;          // update all panels assoc. with PCB
    CurrentLib.RefreshView;

    BeginHourGlass(crHourGlass);
    PCBServer.PreProcess;

    FPDeleteList := TObjectList.Create;            // hold a list of prims in a FP to delete.
    FPDeleteList.OwnsObjects := false;

    for I := 0 to (FPList.Count - 1) do
    begin
        Footprint := FPList.Items(I);
        
//        Footprint := CurrentLib.GetComponent(I);
//        if Footprint.Name = TempPCBLibComp.Name  then continue;
        
        iStatusBar := Int(HowManyInt / SelCountToT * 100);
        sStatusBar := ' Deleting : ' + IntToStr(iStatusBar) + '% done';
        GUIMan.StatusBar_SetState (1, sStatusBar);


// can NOT delete Prim without re-creating the Group Iterator.
// so make another list to delete from!

        GIterator := Footprint.GroupIterator_Create;
        MyPrim := GIterator.FirstPCBObject;
        while MyPrim <> Nil Do
//        for K := 1 to Footprint.GetPrimitiveCount(MkSet(eTrackObject)) do
        begin
// sadly no collection of ALL..
//            MyPrim := Footprint.GetPrimitiveAt(K, eTrackObject);

            for J := 0 to (DeleteList.Count - 1) do
            begin
                Prim2 := DeleteList.Items(J);
                if (MyPrim.I_ObjectAddress = Prim2.I_ObjectAddress) then
                begin
                    FPDeleteList.Add(Prim2);
//  can only match once so jump out
                    break;
                end;
            end;

            MyPrim := GIterator.NextPCBObject;
        end;
        Footprint.GroupIterator_Destroy(GIterator);

        for J := 0 to (FPDeleteList.Count - 1) do
        begin
            Prim2 := FPDeleteList.Items(J);
            Footprint.RemovePCBObject(Prim2);
            PCBServer.DestroyPCBObject(Prim2);
            inc(HowManyInt);
        end;
        FPDeleteList.Clear;
               
    end;

    FPDeleteList.Free;
    DeleteList.Clear;
    DeleteList.Free;
    FPList.Clear;
    FPList.Destroy;

    PCBServer.PostProcess;

    CurrentLib.Board.GraphicallyInvalidate;

//  Delete Temporary Footprint
    CurrentLib.RemoveComponent(TempPcbLibComp);
    PcbServer.DestroyPCBLibComp(TempPcbLibComp);

    CurrentLib.Navigate_FirstComponent;
    CurrentLib.Board.ViewManager_FullUpdate;
    CurrentLib.Board.GraphicalView_ZoomRedraw;
    CurrentLib.RefreshView;
    EndHourGlass;

    if HowManyInt > 0 then CurrentLib.Board.SetState_DocumentHasChanged;

    HowMany := IntToStr(HowManyInt);
    if HowManyInt = 0 then HowMany := '-NO-';
    ShowMessage('Deleted ' + HowMany + ' Items | selected count : ' + IntToStr(SelCountTot) );
//    ShowMessage('Deleted ' + HowMany + ' Items ' + '  List ' + IntToStr(DeleteList.Count) + '  SelCount' + IntToStr(SelCountTot) );

End;
{..............................................................................}

