{ EmbeddedBoardPnPX.pas

  report Embedded Boards
  generate PnP for single Row & single column of all embedded board objects.

  Author BL Miller
20220503  0.1  POC adapted from EmbeddedObjects.pas.
}

var
    Board     : IPCB_Board;
    Borigin   : TPoint;
    Report    : TStringList;
    FileName  : WideString;
    LayerSet  : IPCB_LayerSet;

function ReportOnEmbeddedBoard (EMB : IPCB_EmbeddedBoard, Var RowCnt : integer, Var ColCnt : integer) : boolean;
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
    Report.Add('X1: ' + CoordUnitToString(BR.X1 - BOrigin.X ,eMM)   + ' Y1: '  + CoordUnitToString(BR.Y1 - BOrigin.Y, eMM) +
              ' X2: ' + CoordUnitToString(BR.X2 - BOrigin.X ,eMM)   + ' Y2: '  + CoordUnitToString(BR.Y2 - BOrigin.Y, eMM) );
    Report.Add('Layer: '  + IntToStr(EMB.Layer)   + '   Rotation: '  + FloatToStr(EMB.Rotation));
    Report.Add('RowCnt: '  + IntToStr(RowCnt)   + '   ColCnt: '  + IntToStr(ColCnt));
    Report.Add('RowSpc: '  + CoordUnitToString(EMB.RowSpacing, eMM) + '   ColSpc: '  + CoordUnitToString(EMB.ColSpacing, eMM) );
    EB := EMB.ChildBoard;
    Report.Add(' child comp cnt    : ' + IntToStr(EB.PrimitiveCounter.GetObjectCount(eComponentObject)) );
    Report.Add(' child rnd hole cnt: ' + IntToStr(EB.PrimitiveCounter.HoleCount(eRoundHole)) );

    Report.Add('');
end;

function CollapseEmbeddedBoard (EMB : IPCB_EmbeddedBoard) : boolean;
begin
    EMB.Setstate_RowCount(1);
    EMB.Setstate_ColCount(1);
end;

function RestoreEmbeddedBoard (EMB : IPCB_EmbeddedBoard, RowCnt : integer, ColCnt : integer) : boolean;
begin
    EMB.Setstate_RowCount(RowCnt);
    EMB.Setstate_ColCount(ColCnt);
end;

function GetEmbeddedBoards(const dummy : boolean) : TObjectList;
Var
    EmbedObj   : IPCB_EmbeddedBoard;
    BIterator  : IPCB_BoardIterator;
    Primitive  : IPCB_Primitive;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;      // critical!
    LayerSet := LayerSetUtils.CreateLayerSet.IncludeAllLayers;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eEmbeddedBoardObject));
    BIterator.AddFilter_IPCB_LayerSet(LayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    EmbedObj := BIterator.FirstPCBObject;
    while (EmbedObj <> Nil) do
    begin
        Result.Add(EmbedObj);
        EmbedObj := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);
end;

procedure ReportEmbeddedBoardObjs;
var
    EmbeddedBoardList : TObjectList;
    RowCnt            : Array [0..100];
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

    EmbeddedBoardList := GetEmbeddedBoards(true);
    ShowMessage('embedded board count : ' + IntTostr(EmbeddedBoardList.Count));
    for I := 0 to (EmbeddedBoardList.Count - 1) do
    begin
        RC := 1; CC := 1;
        ReportOnEmbeddedBoard(EmbeddedBoardList.Items(I), RC, CC);
        RowCnt[I] := RC; ColCnt[I] := CC;
    end;

// set row & column counts to 1 for all EBO
    for I := 0 to (EmbeddedBoardList.Count - 1) do
        CollapseEmbeddedBoard(EmbeddedBoardList.Items(I));

    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);
    ShowMessage('single ');

// Output PnP etc
    Client.SendMessage('WorkspaceManager:GenerateReport', 'ObjectKind=Assembly|Index=2|DoEditProperties=False|DefaultCaption=True|DoGenerate=True', 512, Client.CurrentView);

// restore the original row & column counts.
    for I := 0 to (EmbeddedBoardList.Count - 1) do
        RestoreEmbeddedBoard(EmbeddedBoardList.Items(I), RowCnt[I], ColCnt[I]);

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
    EmbeddedBoardList := GetEmbeddedBoards(true);
    if EmbeddedBoardList.Count < 1 then
    begin
        AddEmbeddedBoardObj(Board);
    end;
end;

