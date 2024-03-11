{ ReportComp3DModels.pas

 PcbDoc PcbLib
 from CompModelHeights.pas & LoadModels.pas

 Report all comp body models:
    Iterate all footprints within the current doc.

 FixId replaces the blank Extruded model name with the footprint name.


27/06/2022  v0.01 POC cut out of other script & rejigged designator pattern reporting.
03/07/2022  v0.10 refactor PcbLib loop, faster & fix delete extruded models
2024-03-11  v0.12 report Overall Height


Model Get XYZ is broken
PcbLib Component origin is a mess. The focused comp has a different origin??

}
const
    cModel3DGeneric   = 'Generic Model';
    cModel3DExtruded  = 'Extruded';

    cReport = 0
    cFix    = 1;
    cStrip  = 2;

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;
    Board     : IPCB_Board;
    PcbLib    : IPCB_Library;
    IsLib     : boolean;
    Units     : TUnit;
    BOrigin   : TCoordPoint;

function GetCompBodies(Footprint : IPCB_Component, const BodyID : WideString , const ModType : T3DModelType, const Exclude : boolean) : TObjectList; forward;
procedure SaveReportLog(FileExt : WideString, const display : boolean);                                 forward;
function ModelTypeToStr (ModType : T3DModelType) : WideString;                                          forward;
procedure ReportTheBodies(const fix : boolean);                                                         forward;
function ProcessReportBodies(Footprint : IPCB_Component, Islib : boolean, fix : integer) : TObjectList; forward;

procedure ReportCompBodies;
begin
    ReportTheBodies(cReport);
end;

procedure FixIdAndReportCompBodies;
begin
    ReportTheBodies(cFix);
end;

procedure ReportTheBodies(const fix : integer);
var
    PcbLib       : IPCB_Library;
    FPIterator   : IPCB_BoardIterator;
    Footprint    : IPCB_Component;
    CompBody     : IPCB_ComponentBody;
    PLayerSet    : IPCB_LayerSet;

    CBList       : TObjectList;
    i, j         : integer;

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
        PcbLib := PCBServer.GetCurrentPCBLibrary;
        Board := PcbLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (PcbLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    BeginHourGlass(crHourGlass);
// PcbLib origin is (0,0) if FP is not selected
    if IsLib then BOrigin := Point(0, 0)
    else          BOrigin := Point(Board.XOrigin, Board.YOrigin);  // abs Tcoord
    Units := Board.DisplayUnit;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.Include(eTopLayer);
    PLayerSet.Include(eBottomLayer);

    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('');
    Rpt.Add('');
    Rpt.Add(PadRight('n',2) + '|' + PadRight('Desgr', 6) + '|' + PadRight('Footprint', 20) + '|' + PadRight('Identifier', 20) + '|' + PadRight('ModelName', 24) + ' | ' + PadRight('ModelType',12)
            + ' | ' + PadLeft('X',10) + ' | ' + PadLeft('Y',10) + ' | Ang    |  Area   |  OverallHeight' );
    Rpt.Add('');

    if IsLib then
    begin

        for i := 0 to (PcbLib.ComponentCount - 1) do
        begin
            Footprint := PcbLib.GetComponent(i);

            CBList := ProcessReportBodies(Footprint, Islib, fix);
            CBList.Clear;
        end;

// PcbDoc
    end else
    begin
        FPIterator := Board.BoardIterator_Create;
        FPIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
        FPIterator.AddFilter_IPCB_LayerSet(PLayerSet);
        FPIterator.AddFilter_Method(eProcessAll);   // TIterationMethod { eProcessAll, eProcessFree, eProcessComponents }

        Footprint := FPIterator.FirstPCBObject;
        while Footprint <> Nil Do
        begin
            CBList := ProcessReportBodies(Footprint, Islib, fix);

            Footprint := FPIterator.NextPCBObject;

            Rpt.Add('');
            CBList.Clear;
        end;

        Board.BoardIterator_Destroy(FPIterator);
        Board.GraphicalView_ZoomRedraw;
    end;

    EndHourGlass;

    SaveReportLog('FPBodyReport.txt', true);
    Rpt.Free;
end;

// returns the non-generic bodies
function ProcessReportBodies(Footprint : IPCB_Component, Islib : boolean, fix : integer) : TObjectList;
var
    CompBody     : IPCB_ComponentBody;
    CompModel    : IPCB_Model;
    ModType      : T3DModelType;
    FPName       : WideString;
    FPPattern    : WideString;
    CBodyName    : WideString;
    CompModelId  : WideString;
    CompArea     : WideString;
    CBOverallHeight : TCoord;
    ModName      : WideString;
    MOrigin      : TCoordPoint;
    ModRot       : TAngle;
    NoOfPrims    : Integer;
    FoundGeneric : boolean;
    CBList       : TObjectList;
    i            : integer;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    if IsLib then
    begin
        FPName    := 'FP';
        FPPattern := Footprint.Name;
//        CurrentLib.SetState_CurrentComponent (Footprint)      // to make origin correct.
    end else
    begin
//        FPDes     := Footprint.SourceDesignator;
        FPName    := Footprint.Name.Text;
        FPPattern := Footprint.Pattern;
    end;

    if Footprint.ItemGUID <> '' then
        Rpt.Add('ItemGUID : ' + Footprint.ItemGUID + '  ItemRevGUID : ' + Footprint.ItemRevisionGUID + '  VGUID : ' + Footprint.VaultGUID);

    NoOfPrims := 0;
    FoundGeneric := false;

    CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, false);
    if CBList.Count > 0 then FoundGeneric := true;
    
    for i := 0 to (CBList.Count - 1) do
    begin
        CompBody := CBList.Items(i);

        CompBody.ShapeSegmentCount;
        CompBody.HoleCount;

        CBodyName       := CompBody.Name;                   // ='' for all 3d comp body
        CompModelId     := CompBody.Identifier;
        CBOverallHeight := CompBody.OverallHeight;
        CompArea        := SqrCoordToUnitString_i(CompBody.Area, Units, 3);

        CompModel := CompBody.Model;
        if CompModel <> nil then
        begin
                Inc(NoOfPrims);
                ModName := CompModel.FileName;
                ModType := CompModel.ModelType;
                MOrigin := CompModel.Origin;
                ModRot  := CompModel.Rotation;

                Rpt.Add(PadRight(IntToStr(NoOfPrims),2) + '|' + PadRight(FPName, 6) + '|' + PadRight(FPPattern, 20) + '|' + PadRight(CompModelId, 20) + '|' + PadRight(ModName, 24) + ' | ' + PadRight(ModelTypeToStr(ModType), 12)
                        + ' | ' + PadLeft(IntToStr(MOrigin.X-BOrigin.X),10) + ' | ' + PadLeft(IntToStr(MOrigin.Y-BOrigin.Y),10) + ' | ' + FloatToStr(ModRot)  + ' | ' + CompArea
                        + ' | ' + CoordUnitToStringWithAccuracy(CBOverallHeight, eMM, 4, 3) );

        end;
    end;

// generics
    CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, true);

    for i := 0 to (CBList.Count - 1) do
    begin
        CompBody        := CBList.Items(i);
        CBodyName       := CompBody.Name;                      // ='' for all 3d comp body
        CompModelId     := CompBody.Identifier;
        CBOverallHeight := CompBody.OverallHeight;
        CompBody.ShapeSegmentCount;
        CompBody.HoleCount;
        ModName := CBodyName;
        CompArea  := SqrCoordToUnitString_i(CompBody.Area, Units, 3);

// name the blank models with designator & footprint pattern
        if (Fix = cFix) then
        if (CompModelId = '') then
            CompBody.SetState_Identifier(FPName + '_' + FPPattern);

        CompModelId := CompBody.Identifier;

        CompModel := CompBody.Model;
        if CompModel <> nil then
        begin
            Inc(NoOfPrims);
            ModType     := CompModel.ModelType;
            MOrigin     := CompModel.Origin;
            ModRot      := CompModel.Rotation;

            Rpt.Add(PadRight(IntToStr(NoOfPrims),2) + '|' + PadRight(FPName, 6) + '|' + PadRight(FPPattern, 20) + '|' + PadRight(CompModelId, 20) + '|' + PadRight(ModName, 24) + ' | ' + PadRight(ModelTypeToStr(ModType), 12)
                    + ' | ' + PadLeft(IntToStr(MOrigin.X-BOrigin.X),10) + ' | ' + PadLeft(IntToStr(MOrigin.Y-BOrigin.Y),10) + ' | ' + FloatToStr(ModRot)  + ' | ' + CompArea
                    + ' | ' + CoordUnitToStringWithAccuracy(CBOverallHeight, eMM, 4, 3) );
        end;
    end;

//  return non-generics if any generic was found
    if FoundGeneric then
    for i := 0 to (CBList.Count - 1) do
    begin
        CompBody := CBList.Items(i);
        Result.Add(CompBody);
    end;
    CBList.Clear;
end;
{---------------------------------------------------------------------------------------------------------------------------}
function GetCompBodies(Footprint : IPCB_Component, const BodyID : WideString , const ModType : T3DModelType, const Exclude : boolean) : TObjectList;
var
    GIterator        : IPCB_GroupIterator;
    CompBody         : IPCB_ComponentBody;
    CompModel        : IPCB_Model;
    ModelFileName    : WideString;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    GIterator := Footprint.GroupIterator_Create;
    GIterator.Addfilter_ObjectSet(MkSet(eComponentBodyObject));
    CompBody := GIterator.FirstPCBObject;

    while CompBody <> Nil do
    begin
        CompModel := CompBody.Model;
        if CompModel <> nil then
        begin
            if Exclude xor (ModType = CompModel.ModelType) then  //  cModel3DGeneric
            begin
//                ModDefName  := CompModel.Name;    //  DefaultPCB3DModel;
                ModelFileName := CompModel.FileName;
                if SameString(BodyId, ExtractFileName(ModelFileName), false) then
                    Result.Add(CompBody);
                if SameString(BodyId, '*', false) then
                    Result.Add(CompBody);
            end;
        end;
        CompBody := GIterator.NextPCBObject;
    end;
    Footprint.GroupIterator_Destroy(GIterator);
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

