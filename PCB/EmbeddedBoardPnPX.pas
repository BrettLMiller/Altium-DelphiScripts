{ EmbeddedBoardPnPX.pas
  (cut down version, no outlines, regions or keepouts)

  report on Embedded Board(s)
  generate built-in Placement report for single Row & single column of all embedded board objects.
  generate a full Placement report file with EMB row & column indices.

  Author BL Miller
20220503  0.1  POC adapted from EmbeddedObjects.pas.
20220606  0.2  add col row margins & full Placement file.
}

var
    Board     : IPCB_Board;
    Borigin   : TPoint;
    BUnits    : TUnit;
    Report    : TStringList;
    FileName  : WideString;

function GetEmbeddedBoardComps(EMBI : integer; var EMB : IPCB_EmbeddedBoard) : boolean; forward;
function ReportOnEmbeddedBoard (var EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean; forward;
function CollapseEmbeddedBoard (var EMB : IPCB_EmbeddedBoard) : boolean; forward;
function RestoreEmbeddedBoard (var EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean; forward;
function GetEmbeddedBoards(ABoard : IPCB_Board) : TObjectList; forward;

procedure ReportEmbeddedBoardObjs;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    RowCnt            : Array [0..100];         // ugly use of array
    ColCnt            : Array [0..100];
    RC, CC            : Integer;
    I                 : integer;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

    Report := TStringList.Create;

    EmbeddedBoardList := GetEmbeddedBoards(Board);
    ShowMessage('embedded board count : ' + IntTostr(EmbeddedBoardList.Count));
    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        RC := 1; CC := 1;
        ReportOnEmbeddedBoard(EMB, RC, CC);

// set row & column counts to 1 for all EBO
        RowCnt[I] := RC; ColCnt[I] := CC;
        CollapseEmbeddedBoard(EMB);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    ShowMessage('single ');

// Output PnP etc
    Client.SendMessage('WorkspaceManager:GenerateReport', 'ObjectKind=Assembly|Index=2|DoEditProperties=False|DefaultCaption=True|DoGenerate=True', 512, Client.CurrentView);

// restore the original row & column counts.
    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        RC := RowCnt[I]; CC := ColCnt[I];
        RestoreEmbeddedBoard(EMB, RC, CC);
    end;

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?
    PcbServer.RefreshDocumentView(Board.FileName);

    ShowMessage('restored ');

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    Report.Add(' Panel pads      : ' + IntToStr(Board.GetPrimitiveCount(ePadObject, AllLayers, eIterateAllLevels)));

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\EmbeddedBrdObj.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

procedure EmbBrdCompPlacementReport;
var
    EmbeddedBoardList : TObjectList;
    EMB               : IPCB_EmbeddedBoard;
    BIterator         : IPCB_BoardIterator;
    BLayerSet         : TPCB_LayerSet;
    Comp              : IPCB_Component;
    Rotation          : float;
    RC, CC            : Integer;
    I                 : integer;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    BOrigin := Point(Board.XOrigin, Board.YOrigin);

// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    Report := TStringList.Create;

    BLayerSet := LayerSetUtils.EmptySet;
    BLayerSet.IncludeSignalLayers;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    Report.Add('EI |RI |CI |Designator|Footprint                               |   X   |   Y   |  Rot | Layer ');
    Comp := BIterator.FirstPCBObject;
    while (Comp <> Nil) do
    begin
        Rotation := Comp.Rotation;
        if Rotation = 360 then rotation := 0;

        Report.Add(Padright(IntToStr(0),3) + '|' + Padright(IntToStr(0),3) + '|' + PadRight(IntToStr(0),3) + '|' + PadRight(Comp.Name.Text,10) + '|' +
                            PadRight(Comp.Pattern,40) + '|' +
                            Padleft(FormatFloat('#0.000#', CoordToMMs(Comp.X - BOrigin.X)),7) + '|' +  Padleft(FormatFloat('#0.000#', CoordToMMs(Comp.Y - BOrigin.Y)),7) + '|' +
                            Padleft(FormatFloat('0.0#',Rotation),6) + '| ' + Layer2String(Comp.Layer) );

        Comp := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);

    EmbeddedBoardList := GetEmbeddedBoards(Board);

    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        EMB := EmbeddedBoardList.Items(I);
        GetEmbeddedBoardComps(I, EMB);
    end;

    EmbeddedBoardList.Destroy;   // does NOT own the objects !!

    Report.Add(' Panel pads            : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(ePadObject)));
    Report.Add(' Panel holes           : ' + IntToStr(Board.GetPrimitiveCounter.HoleCount(eRoundHole)));
    Report.Add(' Panel components      : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(eComponentObject)));
    Report.Add(' Panel embedded boards : ' + IntToStr(Board.GetPrimitiveCounter.GetObjectCount(eEmbeddedBoardObject)));
    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName) + '\EMBCompPlace.txt';
    Report.SaveToFile(FileName);
    Report.Free;
end;

function AddEmbeddedBoardObj(Board : IPCB_Board) : IPCB_Embedded;
begin
    Result := PCBServer.PCBObjectFactory(eEmbeddedBoardObject, eNoDimension, eCreate_Default);
//    Result.Name := 'script added';
    Result.RowCount := 3;
    Result.ColCount := 2;
    Result.ChildBoard.FileName := '';
    Board.AddPCBObject(Result);
end;

procedure AddEmbeddedBoard;
var
    EmbeddedBoardList : TObjectList;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    EmbeddedBoardList := GetEmbeddedBoards(Board);
    if EmbeddedBoardList.Count < 1 then
    begin
        AddEmbeddedBoardObj(Board);
    end
    else
        ShowMessage('non-zero EMB count ');
end;

function GetEmbeddedBoardComps(EMBI : integer; var EMB : IPCB_EmbeddedBoard) : boolean;
var
    CB        : IPCB_Board;
    PLBO      : IPCB_BoardOutline;
    CBBR      :  TCoordRect;    // child board bounding rect 
    BIterator : IPCB_BoardIterator;
    BLayerSet : IPCB_LayerSet;
    Comp      : IPCB_Component;
    NewComp   : IPCB_Component;
    Rotation  : float;
    EMBO     : TCoordPoint;
    CBO      : TCoordPoint;
    RowCnt   : integer;
    ColCnt   : integer;
    RI, CI   : integer;
    RS, CS   : TCoord;
    RM, CM   : TCoord;
    X, Y     : TCoord;

begin
    Result := 0;
    CB   := EMB.ChildBoard;
    PLBO := CB.BoardOutline;
    CBBR := PLBO.BoundingRectangle;
    CBO  := Point(CBBR.X1, CBBR.Y1);

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    RS := EMB.RowSpacing;
    CS := EMB.ColSpacing;

    if (EMB.Rotation = 90) or (EMB.Rotation = 270) then
    begin
        RowCnt := ColCnt;
        ColCnt := EMB.RowCount;
        RS := CS;
        CS := EMB.RowSpacing;
    end;

    if (EMB.Rotation = 90)  or (EMB.Rotation = 180) then CS := -CS;
    if (EMB.Rotation = 270) or (EMB.Rotation = 180) then RS := -RS;

    if (EMB.MirrorFlag) then
    begin
        if (EMB.Rotation = 0)  or (EMB.Rotation = 180)  or (EMB.Rotation = 360) then CS := -CS;
        if (EMB.Rotation = 90) or (EMB.Rotation = 270) then RS := -RS;
    end;

    BLayerSet := LayerSetUtils.EmptySet;
    BLayerSet.IncludeSignalLayers;
    BIterator := CB.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    for RI := 0 to (RowCnt - 1) do
        for CI := 0 to (ColCnt - 1) do
        begin
// origin of each individual piece.
            EMBO := Point(EMB.XLocation + CI * CS, EMB.YLocation + RI * RS);

            Comp := BIterator.FirstPCBObject;
            while (Comp <> Nil) do
            begin
                NewComp := Comp.Replicate;

                NewComp.MoveByXY(EMBO.X - CBO.X, EMBO.Y - CBO.Y);

                if (EMB.MirrorFlag) then
                begin
             //     NewComp.Mirror(EMBO.X, eHMirror);  // AD17 EMB wrong layer then wrong rotation
                    NewComp.FlipXY(EMBO.X, eHMirror);
                end;

                NewComp.RotateAroundXY(EMBO.X, EMBO.Y, EMB.Rotation);

                X := NewComp.x; Y := Newcomp.y;
                Rotation := NewComp.Rotation;
                if Rotation = 360 then rotation := 0;

                Report.Add(Padright(IntToStr(EMBI+1),3) + '|' + Padright(IntToStr(RI+1),3) + '|' + PadRight(IntToStr(CI+1),3) + '|' + PadRight(NewComp.SourceDesignator,10) + '|' +
                           PadRight(NewComp.Pattern,40) + '|' +
                           Padleft(FormatFloat('#0.000#', CoordToMMs(X - BOrigin.X)),7) + '|' + Padleft(FormatFloat('#0.000#', CoordToMMs(Y - BOrigin.Y)),7) + '|' +
                           Padleft(FormatFloat('0.0#',Rotation),6) + '|' + Layer2String(NewComp.Layer) );
                Comp := BIterator.NextPCBObject;
            end;
        end;

    CB.BoardIterator_Destroy(BIterator);
    PCBServer.DestroyPCBObject(NewComp);
end;

function ReportOnEmbeddedBoard (var EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean;
var
    BR : TCoordRect;
    EB : IPCB_Board;

begin
    BR := EMB.BoundingRectangle;
//    EMB.Index always =0
//    EMD.UniqueId = ''

    RowCnt := EMB.RowCount;
    ColCnt := EMB.ColCount;
    Report.Add('Panel ' + EMB.Board.FileName + '  child: ' + ExtractFileName(EMB.ChildBoard.FileName) + '  BId: ' + IntToStr(EMB.ChildBoard.BoardID));
    Report.Add('Origin (X,Y) : (' + CoordUnitToString(EMB.XLocation - BOrigin.X ,eMM) + ',' + CoordUnitToString(EMB.YLocation - BOrigin.Y ,eMM) + ')' );
    Report.Add('X1: ' + CoordUnitToString(BR.X1 - BOrigin.X ,eMM)   + ' Y1: '  + CoordUnitToString(BR.Y1 - BOrigin.Y, eMM) +
              ' X2: ' + CoordUnitToString(BR.X2 - BOrigin.X ,eMM)   + ' Y2: '  + CoordUnitToString(BR.Y2 - BOrigin.Y, eMM) );
    Report.Add('Layer: '  + IntToStr(EMB.Layer)   + '   Rotation: '  + FloatToStr(EMB.Rotation));
    Report.Add('RowCnt: '  + IntToStr(RowCnt)   + '   ColCnt: '  + IntToStr(ColCnt));
    Report.Add('RowSpc: ' + CoordUnitToString(EMB.RowSpacing, eMM)         + '   ColSpc: ' + CoordUnitToString(EMB.ColSpacing, eMM)+
            '   RowMar: ' + CoordUnitToString(EMB.GetState_RowMargin, eMM) + '   ColMar: ' + CoordUnitToString(EMB.GetState_ColMargin, eMM) );
    EB := EMB.ChildBoard;
    Report.Add(' child comp cnt    : ' + IntToStr(EB.PrimitiveCounter.GetObjectCount(eComponentObject)) );
    Report.Add(' child rnd hole cnt: ' + IntToStr(EB.PrimitiveCounter.HoleCount(eRoundHole)) );

    Report.Add('');
end;

function CollapseEmbeddedBoard (var EMB : IPCB_EmbeddedBoard) : boolean;
begin
    EMB.Setstate_RowCount(1);
    EMB.Setstate_ColCount(1);
end;

function RestoreEmbeddedBoard (var EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean;
begin
    EMB.Setstate_RowCount(RowCnt);
    EMB.Setstate_ColCount(ColCnt);
end;

function GetEmbeddedBoards(ABoard : IPCB_Board) : TObjectList;
Var
    EmbedObj   : IPCB_EmbeddedBoard;
    BIterator  : IPCB_BoardIterator;
    BLayerSet  : IPCB_LayerSet;
    Primitive  : IPCB_Primitive;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;      // critical!

    BLayerSet := LayerSetUtils.CreateLayerSet.IncludeAllLayers;
    BIterator := ABoard.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eEmbeddedBoardObject));
    BIterator.AddFilter_IPCB_LayerSet(BLayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    EmbedObj := BIterator.FirstPCBObject;
    while (EmbedObj <> Nil) do
    begin
        Result.Add(EmbedObj);
        EmbedObj := BIterator.NextPCBObject;
    end;
    ABoard.BoardIterator_Destroy(BIterator);
end;
