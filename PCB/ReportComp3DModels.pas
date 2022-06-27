{ ReportComp3DModels.pas

 PcbDoc PcbLib
 from CompModelHeights.pas & LoadModels.pas
 
 Report all comp body models:
    Iterate all footprints within the current doc.

 fixId replaces the blank Extrude model name with the footprint name.

27/06/2022  v0.01 POC cut out of other script & rejigged designator pattern reporting.

}
const
    cModel3DGeneric   = 'Generic Model';
    cModel3DExtruded  = 'Extruded';

    cReport = 0
    cFix    = 1;
    cStrip  = 2;

    ArcResolution     = 0.05;    // mils : impacts number of edges etc..

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;
    Board     : IPCB_Board;
    PcbLib    : IPCB_Library;
    IsLib     : boolean;
    BOrigin   : TCoordPoint;

procedure SaveReportLog(FileExt : WideString, const display : boolean); forward;
function ModelTypeToStr (ModType : T3DModelType) : WideString;          forward;
procedure ReportTheBodies(const fix : boolean);                         forward;

procedure ReportCompBodies;
begin
    ReportTheBodies(cReport);
end;
procedure FixIdAndReportCompBodies;
begin
    ReportTheBodies(cFix);
end;
procedure StripExtrudedAndReportCompBodies;
begin
    ReportTheBodies(cStrip);
end;

procedure ReportTheBodies(const fix : integer);
var
    CurrentLib   : IPCB_Library;
    FPIterator   : IPCB_BoardIterator;
    GIterator    : IPCB_GroupIterator;
    Footprint    : IPCB_Component;
    CompBody     : IPCB_ComponentBody;
    PLayerSet    : IPCB_LayerSet;
    CompModel    : IPCB_Model;
    ModType      : T3DModelType;
    FPName       : WideString;
    FPPattern    : WideString;
    ModName      : WideString;
    CBodyName    : WideString;
    CompModelId  : WideString;
    CompArea     : WideString;
    MOrigin      : TCoordPoint;
    ModRot       : TAngle;
    NoOfPrims    : Integer;
    Units        : TUnit;
    FoundGeneric : boolean;
    ExtrudedBDL  : TObjectList;
    i : integer;

begin
    Document := GetWorkSpace.DM_FocusedDocument;
    if not ((Document.DM_DocumentKind = cDocKind_PcbLib) or (Document.DM_DocumentKind = cDocKind_Pcb)) Then
    begin
         ShowMessage('No PcbDoc or PcbLib selected. ');
         Exit;
    end;
    IsLib  := false;
    if (Document.DM_DocumentKind = cDocKind_PcbLib) then
    begin
        CurrentLib := PCBServer.GetCurrentPCBLibrary;
        Board := CurrentLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (CurrentLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    BeginHourGlass(crHourGlass);
    BOrigin  := Point(Board.XOrigin, Board.YOrigin     );  // abs Tcoord
    Units := Board.DisplayUnit;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.Include(eTopLayer);
    PLayerSet.Include(eBottomLayer);

    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('');
    Rpt.Add('');
    Rpt.Add(PadRight('n',2) + '|' + PadRight('Desgr', 6) + '|' + PadRight('Footprint', 20) + '|' + PadRight('Identifier', 20) + '|' + PadRight('ModelName', 24) + ' | ' + PadRight('ModelType',12)
            + ' | ' + PadLeft('X',10) + ' | ' + PadLeft('Y',10) + ' | Ang ' );
    Rpt.Add('');

    // For each page of library is a footprint
    if IsLib then
        FPIterator := CurrentLib.LibraryIterator_Create
    else FPIterator := Board.BoardIterator_Create;
    FPIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    FPIterator.AddFilter_IPCB_LayerSet(PLayerSet);
    if IsLib then
        FPIterator.SetState_FilterAll
    else
        FPIterator.AddFilter_Method(eProcessAll);   // TIterationMethod { eProcessAll, eProcessFree, eProcessComponents }

    Footprint := FPIterator.FirstPCBObject;
    while Footprint <> Nil Do
    begin
       if IsLib then
        begin
            FPName    := Footprint.Name;
            FPPattern := Footprint.Name;
            CurrentLib.SetState_CurrentComponent (Footprint)      // to make origin correct.
        end else
        begin
//            FPDes     := Footprint.SourceDesignator;
            FPName    := Footprint.Name.Text;
            FPPattern := Footprint.Pattern;
        end;

        if Footprint.ItemGUID <> '' then
            Rpt.Add('ItemGUID : ' + Footprint.ItemGUID + '  ItemRevGUID : ' + Footprint.ItemRevisionGUID + '  VGUID : ' + Footprint.VaultGUID);

        GIterator := Footprint.GroupIterator_Create;
        GIterator.AddFilter_ObjectSet(MkSet(eComponentBodyObject));
        GIterator.AddFilter_IPCB_LayerSet(LayerSetUtils.AllLayers);

        NoOfPrims := 0;
        FoundGeneric := false;
        ExtrudedBDL := TObjectList.Create;
        ExtrudedBDL.OwnsObjects := false;

        CompBody := GIterator.FirstPCBObject;
        while (CompBody <> Nil) Do
        begin
            CompModel := CompBody.Model;

            CompBody.ShapeSegmentCount;
            CompBody.HoleCount;
            CBodyName := CompBody.Name;                      // ='' for all 3d comp body

            CompArea  := SqrCoordToUnitString_i(CompBody.Area, Units, 3);

            if CompModel <> nil then
            begin
                Inc(NoOfPrims);
                ModType     := CompModel.ModelType;
                MOrigin     := CompModel.Origin;
                ModRot      := CompModel.Rotation;
                CompModelId := CompBody.Identifier;

// name the blank models with designator & footprint pattern
                if (Fix = cFix) then
                if (CompModelId = '') then  CompBody.SetState_Identifier(FPName + '_' + FPPattern);

                CompModelId := CompBody.Identifier;
                ModName := CBodyName;
           //     CompModel.Name := FPName;
           //     CompBody.Name  := FPName;
                if (ModType = e3DModelType_Generic) then
                begin
                    ModName := CompModel.FileName;
                    FoundGeneric := true;
                end
                else
                    ExtrudedBDL.Add(CompBody);

                Rpt.Add(PadRight(IntToStr(NoOfPrims),2) + '|' + PadRight(FPName, 6) + '|' + PadRight(FPPattern, 20) + '|' + PadRight(CompModelId, 20) + '|' + PadRight(ModName, 24) + ' | ' + PadRight(ModelTypeToStr(ModType), 12)
                        + ' | ' + PadLeft(IntToStr(MOrigin.X-BOrigin.X),10) + ' | ' + PadLeft(IntToStr(MOrigin.Y-BOrigin.Y),10) + ' | ' + FloatToStr(ModRot)  + ' | ' + CompArea);

// vault stuff
//                if CompModel.ItemGUID <> '' then
//                    Rpt.Add('ItemGUID : ' + CompModel.ItemGUID + '  ItemRevGUID : ' + CompModel.ItemRevisionGUID + '  VGUID : ' + CompModel.VaultGUID);
            end;
            CompBody := GIterator.NextPCBObject;
        end;

        Rpt.Add('');

        Footprint.GroupIterator_Destroy(GIterator);

        if (FoundGeneric) and (Fix = cStrip) then
        begin
            for i := 0 to (ExtrudedBDL.Count -1) do
            begin
                CompBody := ExtrudedBDL.Items(i);
                Footprint.RemovePCBObject(CompBody);
                Board.RemovePCBObject(CompBody);
            end;
        end;
        ExtrudedBDL.Clear;

        Footprint := FPIterator.NextPCBObject;
    end;

    if IsLib then
        CurrentLib.LibraryIterator_Destroy(FPIterator)
    else Board.BoardIterator_Destroy(FPIterator);

    if IsLib then CurrentLib.Navigate_FirstComponent;
    Board.GraphicalView_ZoomRedraw;
    if IsLib then CurrentLib.RefreshView;

    EndHourGlass;

    SaveReportLog('FPBodyReport.txt', true);
    Rpt.Free;
end;
{---------------------------------------------------------------------------------------------------------------------------}
procedure SaveReportLog(FileExt : WideString, const display : boolean);
var
    FileName : TPCBString;
    SerDoc   : IServerDocument;
begin
//    FileName := ChangeFileExt(CBoard.FileName, FileExt);
    FileName := ExtractFilePath(Board.FileName) + ChangeFileExt(ExtractFileName(Board.FileName), FileExt);
    if ExtractFilePath(Board.FileName) = '' then
       FileName := 'c:\temp\' + FileName;
    Rpt.SaveToFile(Filename);
    SerDoc  := Client.OpenDocument('Text', FileName);
    If display and (SerDoc <> Nil) Then
    begin
        Client.ShowDocument(SerDoc);
        if (SerDoc.GetIsShown <> 0 ) then
            SerDoc.DoFileLoad;
    end;
end;
{..................................................................................................}
function ModelTypeToStr (ModType : T3DModelType) : WideString;
begin
    Case ModType of
        0                     : Result := 'Extruded';            // AD19 defines e3DModelType_Extrude but not work.
        e3DModelType_Generic  : Result := 'Generic';
        2                     : Result := 'Cylinder';
        3                     : Result := 'Sphere';
    else
        Result := 'unknown';
    end;
end;
{..................................................................................................}

