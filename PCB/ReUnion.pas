{  ReUnion.pas

  ReUnion()
   - using pre-selected objects that is in a union, the script will:
   - add next clicked object(s) into same union


  RemoveFootprintUnion()
  - PcbLib remove all unions from all footprints' primitives.
  - PcbDoc remove all unions from selected footprint's primitives.

  RemoveSelectedFromUnion()
  - PcbDoc or PcbLib

Author BL Miller
16/05/2020  v0.20 Added Remove objects from Union (free primitives & groups i.e. components)
2024-03-23  v0.21 support remove Union in PcbLibs.

Add to Union
Button RunScriptText
Text=Var B,P,U;Begin B:=PCBServer.GetCurrentPCBBoard;if(B.SelectecObjectCount=0) then exit;P:=B.SelectecObject(0);U:=P.UnionIndex;if U=0 then exit;P:=B.GetObjectAtCursor(AllObjects,AllLayers,'pick ReUnion obj');if Assigned(P) then if P.UnionIndex=0 then P.UnionIndex := U;end;

Remove from Union
Text=Var B,P,U;Begin B:=PCBServer.GetCurrentPCBBoard;if(B.SelectecObjectCount=0) then exit;P:=B.SelectecObject(0);P.UnionIndex:=0;end;


Script is missing some component union refresh/update trick for removing primitives from Union.
close reopen PCB & Unions works perfectly..

    UM := Board.BoardUnionManager;
    IPCB_SmartUnionObject;
    IPCB_SmartUnionPlaceHolder;

    J := IPCB_BoardUnionManager.FindUnusedUnionIndex;
}

function GetCurrentPcbOrLib (var IsLib : boolean) : WideString; forward;
function ProcessFootprintUnions(Comp : IPCB_Component, IsLib : boolean, const UIndex) : integer; forward;

var
    UM        : IPCB_BoardUnionManager;
    SourceLib : IPCB_Library;
    Board     : IPCB_Board;
    DocKind   : Widestring;

procedure ReUnion;
var
    P,G    : IPCB_Primitive;
    UIndex : integer;
    IsLib  : boolean;

begin
    IsLib := false;
    DocKind := GetCurrentPcbOrLib (IsLib);

    if(Board.SelectecObjectCount = 0) then exit;
    P      := Board.SelectecObject(0);
    UIndex := P.UnionIndex;
    if UIndex = 0 then exit;

//    B.ChooseLocation(x, y, 'pick ReUnion obj');
    P := nil;
    repeat
        if P <> nil then
        begin
            G := P;
            if P.InComponent then G := P.Component;

            if (G.ObjectId = eComponentObject) then
            begin
                ProcessFootprintUnions(G, IsLib, UIndex);
            end else
            begin
                G.BeginModify;
                G.SetState_UnionIndex := UIndex;
                G.Selected := true;
                G.EndModify;
                G.GraphicallyInvalidate;
                Board.ViewManager_GraphicallyInvalidatePrimitive(G);
            end;
        end;

        P:= Board.GetObjectAtCursor(AllObjects, AllLayers, 'pick ReUnion object(s) ');
    until P = nil;
end;

procedure RemoveFootprintUnion;
var
    Comp   : IPCB_LibComponent;
    Prim   : IPCB_Primitive;
    IsLib  : boolean;
    i      : integer;

begin
    IsLib := false;
    DocKind := GetCurrentPcbOrLib (IsLib);

    if IsLib then
    begin
        for i := 0 to (SourceLib.ComponentCount - 1) do
        begin
            Comp := SourceLib.GetComponent(i);
            ProcessFootprintUnions(Comp, IsLib, 0);
        end;
// PcbDoc
    end else
    begin
        Comp := nil;
        Prim := Board.SelectecObject(0);
        if Prim.ObjectId = eComponentObject then Comp := Prim;
        if Prim.InComponent then Comp := Prim.Component;
        if Comp <> nil then
            ProcessFootprintUnions(Comp, IsLib, 0);
    end;
end;

procedure RemoveSelectedFromUnion;
var
    Prim   : IPCB_Primitive;
    Group  : IPCB_Primitive;
    UIndex : integer;
    J      :  integer;
    IsLib  : boolean;

begin
    IsLib := false;
    DocKind := GetCurrentPcbOrLib (IsLib);

    if(Board.SelectecObjectCount = 0) then exit;

    for J := 0 to (Board.SelectecObjectCount - 1) do
    begin
        Prim   := Board.SelectecObject(J);
        UIndex := Prim.UnionIndex;
//    if UIndex = 0 then exit;
        Group := Prim;
        if Prim.InComponent then Group := Prim.Component;

        Group.BeginModify;
        Group.SetState_UnionIndex := 0;
        Group.Selected := true;

        if (Group.ObjectId = eComponentObject) then
            ProcessFootprintUnions(Group, IsLib, 0);

        Group.EndModify;
        Group.GraphicallyInvalidate;
        Board.ViewManager_GraphicallyInvalidatePrimitive(Group);
    end;
end;

procedure ReportUnion;
var
    Prim   : IPCB_Primitive;
    UIndex : integer;
    IsLib  : boolean;

begin
    IsLib := false;
    DocKind := GetCurrentPcbOrLib (IsLib);

    if(Board.SelectecObjectCount = 0) then exit;
    Prim := Board.SelectecObject(0);
    UIndex := Prim.UnionIndex;

    Prim.UniqueId;
    ShowMessage('Union index : ' + IntToStr(UIndex));
//    if UIndex = 0 then exit;
end;

procedure ReportDistance;
var
    Prim1  : IPCB_Primitive;
    Prim2  : IPCB_Primitive;
    UIndex : integer;
    Distance   : TCoord;
    Replicated : boolean;
    IsLib      : boolean;
begin
    IsLib := false;
    DocKind := GetCurrentPcbOrLib (IsLib);

    if(Board.SelectecObjectCount < 2) then exit;
    Prim1 := Board.SelectecObject(0);
    Prim2 := Board.SelectecObject(1);

    Replicated := false;
    if Prim2.Layer <> Prim1.Layer then
    begin
        Prim2 := Prim2.Replicate;
        Prim2.Layer := Prim1.Layer;
        Replicated := true;
    end;

    Distance := Board.PrimPrimDistance(Prim1, Prim2);

    if (Replicated) then
        PcbServer.DestroyPCBObject(Prim2);

    ShowMessage('P-P distance : ' + CoordUnitToString(Distance, eMM) );

end;

function ProcessFootprintUnions(Comp : IPCB_Component, IsLib : boolean, const UIndex) : integer;
var
    Prim   : IPCB_Primitive;
    GIter  : IPCB_GroupIterator;
begin
    Result := 0;
    Comp.BeginModify;
    if not(IsLib) then
    begin
        Comp.SetState_UnionIndex := UIndex;
        Comp.Name.SetState_UnionIndex := UIndex;
        Comp.Comment.SetState_UnionIndex := UIndex;
    end;

    GIter := Comp.GroupIterator_Create;
    GIter.AddFilter_ObjectSet(AllObjects);
    GIter.AddFilter_LayerSet(AllLayers);
    Prim := GIter.FirstPCBObject;
    while Prim <> Nil Do
    begin
        Prim.BeginModify;
        Prim.SetState_UnionIndex := UIndex;
        Prim.EndModify;
        Prim := GIter.NextPCBObject;
    end;
    Comp.GroupIterator_Destroy(GIter);
    Comp.EndModify;
    Comp.GraphicallyInvalidate;
    Board.ViewManager_GraphicallyInvalidatePrimitive(Comp);
end;

function GetCurrentPcbOrLib (var IsLib : boolean) : WideString;
var
    Document : IDocument;
begin
    Result := '';
    SourceLib := nil;
    IsLib  := false;
    Document := GetWorkSpace.DM_FocusedDocument;
    Result   := Document.DM_DocumentKind;

    if not ((Result = cDocKind_PcbLib) or (Result = cDocKind_Pcb)) Then
    begin
        ShowMessage('No Pcb or Lib selected. ');
        Result := '';
        exit;
    end;

    if (Result = cDocKind_PcbLib) then
        IsLib := true;

    if IsLib then
    begin
        SourceLib := PCBServer.GetCurrentPCBLibrary;
        Board := SourceLib.Board;
    end else
        Board := PCBServer.GetCurrentPCBBoard;
end;
