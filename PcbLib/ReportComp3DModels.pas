{ ReportComp3DModels.pas

 PcbDoc PcbLib
 from CompModelHeights.pas & LoadModels.pas

 Report all comp body models:
    Iterate all footprint & free models within the current doc.

 ResetOverallHeight()
    Iterate over all FP & free models & refresh CompBody Overall height & Area

 FixId
    replaces the blank Extruded model name with the footprint name.


27/06/2022  v0.01 POC cut out of other script & rejigged designator pattern reporting.
03/07/2022  v0.10 refactor PcbLib loop, faster & fix delete extruded models
2024-03-11  v0.12 report Overall Height
2024-03-11  v0.13 fix PcbLib origin refresh issue.
2024-03-11  v0.14 add Reset Overall Height & Area
2024-03-12  v0.15 adjust mixed up BUnit, refactor reporting-fixing
2024-03-13  v0.16 support PcbDoc ResetOverallHeight() & free models
2024-03-14  v0.17 report any area change, add change total at top report.

Model Get XYZ is broken, could use OverallHeight & Standoff to calculate z
PcbLib Component origin is a mess. The focused comp has a different origin.
}

const
    cReport = 0
    cFix    = 1;
    cStrip  = 2;
    cIgnoreSize = 1;  // sq Coord area

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;
    Board     : IPCB_Board;
    PcbLib    : IPCB_Library;
    IsLib     : boolean;
    BUnit     : TUnit;
    NBUnit    : TUnit;
    BOrigin   : TCoordPoint;

function  GetCompBodies(Footprint : IPCB_Component, const BodyID : WideString , const ModType : T3DModelType, const Exclude : boolean) : TObjectList; forward;
procedure SaveReportLog(FileExt : WideString, const display : boolean);                                             forward;
function  ModelTypeToStr(ModType : T3DModelType) : WideString;                                                      forward;
procedure ReportTheBodies(const fix : boolean);                                                                     forward;
function  ProcessReportBodies(CBList : TObjectList, const fix : integer, const NewName : WideString;) : integer;    forward;
function  ProcessFootprintBodies(Footprint : IPCB_Component, const Idx : integer; const IsLib : boolean) : integer; forward;
function  ProcessCompBody(CompBody : IPCB_ComponentBody) : WideString; forward;

procedure ReportCompBodies;
begin
    ReportTheBodies(cReport);
end;

procedure FixIdAndReportCompBodies;
begin
    ReportTheBodies(cFix);
end;

procedure ResetOverallHeight;     // trigger recalc OverallHeight & area
var
    Footprint    : IPCB_Component;
    FPIterator   : IPCB_BoardIterator;
    CompBody     : IPCB_ComponentBody;
    PLayerSet    : IPCB_LayerSet;
    CBList       : TObjectList;
    IsLib        : boolean;
    RptLine      : WideString;
    FPCount      : integer;
    FPTotCount   : integer;
    i            : integer;

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
    BUnit  := Board.DisplayUnit;
    NBUnit := eMetric;
    if BUnit = eMetric then NBunit :=  eImperial;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.Include(eTopLayer);
    PLayerSet.Include(eBottomLayer);

    Rpt := TStringList.Create;
    Rpt.Add('FileName: ' + ExtractFileName(Board.FileName));
    Rpt.Add('');
    Rpt.Add('3D Model Overall Height &/or Area corrected');
    Rpt.Add(PadRight('n:m',3) + '|  Des   | ' + PadRight('Footprint', 20) + '|' + PadRight('Identifier', 20) + '|' + PadRight('ModelType',12)
            + ' |  Area   |  OverallHeight' ) ;
    Rpt.Add('');
    FPTotCount := 0;
    if IsLib then
    begin
        for i := 0 to (PcbLib.ComponentCount - 1) do
        begin
            Footprint := PcbLib.GetComponent(i);
            PcbLib.SetState_CurrentComponent(Footprint);   // correct origin

            FPCount := ProcessFootprintBodies(Footprint, i, true);
            FPTotCount := FPTotCount + FPCount;
            Rpt.Add('');
        end; //i
// PcbDoc
    end else
    begin
        FPIterator := Board.BoardIterator_Create;
        FPIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
        FPIterator.AddFilter_IPCB_LayerSet(PLayerSet);
        FPIterator.AddFilter_Method(eProcessAll);   // TIterationMethod { eProcessAll, eProcessFree, eProcessComponents }
        i := 0;
        Footprint := FPIterator.FirstPCBObject;
        while Footprint <> Nil Do
        begin
            FPCount := ProcessFootprintBodies(Footprint, i, false);
            FPTotCount := FPTotCount + FPCount;

            Rpt.Add('');
            inc(i);
            Footprint := FPIterator.NextPCBObject;
        end;

// free bodies
        Rpt.Add('Board Free Bodies/Models');
        FPIterator.AddFilter_ObjectSet(MkSet(eComponentBodyObject));
        FPIterator.AddFilter_IPCB_LayerSet(LayerSetUtils.MechanicalLayers);
        FPIterator.AddFilter_Method(eProcessFree);
        CompBody := FPIterator.FirstPCBObject;
        while CompBody <> Nil Do
        begin
            if CompBody.IsFreePrimitive then
            begin
                Rpt.Add(IntToStr(i+1) + '       |' + PadRight('free', 6) + '|' + PadRight(CompBody.Identifier, 20) );
                RptLine := ProcessCompBody(CompBody);

                if RptLine <> '' then
                begin
                    Rpt.Add(IntToStr(i+1) + ':' + IntToStr(1) + ' | ' + RptLine);
                    inc(FPTotCount);
                end;
                inc(i);
            end;
            CompBody := FPIterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(FPIterator);
        Board.GraphicalView_ZoomRedraw;
    end;

    Rpt.Insert(1, 'Total Footprints corrected ' + IntToStr(FPTotCount));
    SaveReportLog('FPBodyOvlHeightRep.txt', true);
    Rpt.Free;
end;

function ProcessCompBody(CompBody : IPCB_ComponentBody) : WideString;
var
    CompModel    : IPCB_Model;
    ModType      : T3DModelType;
    OvlHeight1   : TCoord;
    OvlHeight2   : TCoord;
    CBArea1      : integer;
    CBArea2      : integer;
    Sign         : WideString;

begin
    Result := '';
    OvlHeight1 := CompBody.OverallHeight;
    CBArea1    := CompBody.Area / k1MilSq;         // force float/extended (need Int64)

    CompBody.BeginModify;
    CompBody.SetState_FromModel;
    CompBody.ModelHasChanged;
    CompBody.EndModify;
    CompBody.GraphicallyInvalidate;

    OvlHeight2 := CompBody.OverallHeight;
    CBArea2    := CompBody.Area / k1MilSq;
    CBArea1    := (CBArea2 - CBArea1) * k1MilSq;    // diff sq Coord Real
    CBArea2 := CBArea2 * k1MilSq;
    Sign := '+';
    if CBArea1 < 0 then Sign := '-';
    if CBArea1 = 0 then Sign := ' ';
    CBArea1 := abs(CBArea1);

    CompModel := CompBody.Model;
    ModType   := -1;
    if CompModel <> nil then
        ModType := CompModel.ModelType;

    if (OvlHeight1 <> OvlHeight2) or (CBArea1 > cIgnoreSize) then
        Result := PadRight(CompBody.Identifier, 20) + ' | ' + ModelTypeToStr(ModType)
                  + ' | ' + SqrCoordToUnitString(CBArea2, BUnit, 3) + ' diff ' + Sign + SqrCoordToUnitString(CBArea1, BUnit, 4)
                  + ' | ' + CoordUnitToStringWithAccuracy(OvlHeight2, NBUnit, 4, 3)
                  + '  diff ' + CoordUnitToStringWithAccuracy(OvlHeight2-OvlHeight1, NBUnit, 4, 3);
end;

function ProcessFootprintBodies(Footprint : IPCB_Component, const Idx : integer; const IsLib : boolean) : integer;
var
    CompBody     : IPCB_ComponentBody;
    FPName       : WideString;
    FPPattern    : WideString;
    RptLine      : WideString;
    i            : integer;

begin
    Result := 0;
    if IsLib then
    begin
        FPName    := 'FP';
        FPPattern := Footprint.Name;
    end else
    begin
        FPName    := Footprint.Name.Text;
        FPPattern := Footprint.Pattern;
    end;

    Rpt.Add(IntToStr(Idx+1) + '       |' + PadRight(FPName, 6) + '|' + PadRight(FPPattern, 20) );
    Footprint.BeginModify;

    for i := 1 to Footprint.GetPrimitiveCount(MkSet(eComponentBodyObject)) do
    begin
        CompBody := Footprint.GetPrimitiveAt(i, eComponentBodyObject);
        RptLine  := ProcessCompBody(CompBody);

        if RptLine <> '' then
        begin
            Rpt.Add(IntToStr(Idx+1) + ':' + IntToStr(i) + ' | ' + RptLine);
            inc(Result);
        end;
    end;
    Footprint.EndModify;
    Footprint.GraphicallyInvalidate;
end;

procedure ReportTheBodies(const fix : integer);
var
    PcbLib       : IPCB_Library;
    FPIterator   : IPCB_BoardIterator;
    Footprint    : IPCB_Component;
    CompBody     : IPCB_ComponentBody;
    FPName       : WideString;
    FPPattern    : WideString;
    PLayerSet    : IPCB_LayerSet;
    CBList       : TObjectList;
    RptLine      : WideString;
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
    BOrigin := Point(Board.XOrigin, Board.YOrigin);  // abs Tcoord
    BUnit := Board.DisplayUnit;
    NBUnit := eMetric;
    if BUnit = eMetric then NBunit :=  eImperial;

    PLayerSet := LayerSetUtils.EmptySet;
    PLayerSet.Include(eTopLayer);
    PLayerSet.Include(eBottomLayer);

    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('');
    Rpt.Add('');
    Rpt.Add(PadRight('n',2) + '|' + PadRight('Desgr', 6) + '|' + PadRight('Footprint', 20) );
    Rpt.Add(' idx |' + PadRight('Identifier', 20) + '|' + PadRight('ModelName', 24) + ' | ' + PadRight('ModelType',12)
            + ' | ' + PadLeft('X',10) + ' | ' + PadLeft('Y',10) + ' | Ang    |  Area   |  OverallHeight' );
    Rpt.Add('');

    if IsLib then
    begin

        for i := 0 to (PcbLib.ComponentCount - 1) do
        begin
            Footprint := PcbLib.GetComponent(i);
            PcbLib.SetState_CurrentComponent(Footprint);   // correct origin

            FPName    := 'FP';
            FPPattern := Footprint.Name;

            Rpt.Add(PadRight(IntToStr(i),3) + '|' + PadRight(FPName, 6) + '|' + PadRight(FPPattern, 20));
            if Footprint.ItemGUID <> '' then
                Rpt.Add('ItemGUID : ' + Footprint.ItemGUID + '  ItemRevGUID : ' + Footprint.ItemRevisionGUID + '  VGUID : ' + Footprint.VaultGUID);

            CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, false);
            ProcessReportBodies(CBList, cReport, '');

//  fix extruded model names
//  rename the blank model names with footprint pattern
            CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, true);
            ProcessReportBodies(CBList, fix, FPPattern);               // fix extruded model names

            Rpt.Add('');
            CBList.Clear;
        end;

// PcbDoc
    end else
    begin
        FPIterator := Board.BoardIterator_Create;
        FPIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
        FPIterator.AddFilter_IPCB_LayerSet(PLayerSet);
        FPIterator.AddFilter_Method(eProcessAll);   // TIterationMethod { eProcessAll, eProcessFree, eProcessComponent }
        i := 0;
        Footprint := FPIterator.FirstPCBObject;
        while Footprint <> Nil Do
        begin
            FPName    := Footprint.Name.Text;
            FPPattern := Footprint.Pattern;

            CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, false);
            ProcessReportBodies(CBList, cReport, '');

            CBList := GetCompBodies(Footprint, '*', e3DModelType_Generic, true);
            ProcessReportBodies(CBList, fix, FPName + '_' + FPPattern);               // fix extruded model names

            Footprint := FPIterator.NextPCBObject;

            Rpt.Add('');
            CBList.Clear;
            inc(i);
        end;

// free bodies
        Rpt.Add('Board Free Bodies/Models');
        FPIterator.AddFilter_ObjectSet(MkSet(eComponentBodyObject));
        FPIterator.AddFilter_IPCB_LayerSet(LayerSetUtils.MechanicalLayers);
        FPIterator.AddFilter_Method(eProcessFree);
        CompBody := FPIterator.FirstPCBObject;
        while CompBody <> Nil Do
        begin
            if CompBody.IsFreePrimitive then
            begin
                CBList.Add(CompBody);
                ProcessReportBodies(CBList, fix, FPName + '_' + FPPattern);
                CBList.Clear;
                inc(i);
            end;
            CompBody := FPIterator.NextPCBObject;
        end;

        Board.BoardIterator_Destroy(FPIterator);
        Board.GraphicalView_ZoomRedraw;
    end;

    EndHourGlass;

    SaveReportLog('FPBodyReport.txt', true);
    Rpt.Free;
end;

function ProcessReportBodies(CBList : TObjectList, const fix : integer, const NewName : WideString;) : integer;
var
    CompBody     : IPCB_ComponentBody;
    CompModel    : IPCB_Model;
    ModType      : T3DModelType;
    CBodyName    : WideString;
    CompModelId  : WideString;
    CompArea     : WideString;
    CBOverallHeight : TCoord;
    ModName      : WideString;
    MOrigin      : TCoordPoint;
    ModRot       : TAngle;
    FoundGeneric : boolean;
    i            : integer;

begin
    Result := 0;
    FoundGeneric := false;

    for i := 0 to (CBList.Count - 1) do
    begin
        CompBody  := CBList.Items(i);
        CompModel := CompBody.Model;
        if CompModel = nil then continue;

        ModType   := CompModel.ModelType;

        CBodyName       := CompBody.Name;                   // ='' for all 3d comp body
        CompModelId     := CompBody.Identifier;
        CBOverallHeight := CompBody.OverallHeight;
        CompArea        := SqrCoordToUnitString_i(CompBody.Area, BUnit, 3);

        ModName := CompModel.FileName;
        ModType := CompModel.ModelType;
        MOrigin := CompModel.Origin;
        ModRot  := CompModel.Rotation;

        if ModType = e3DModelType_Generic then
        begin
            Inc(Result);
            FoundGeneric    := true;

            Rpt.Add('   ' + PadRight(IntToStr(Result),2) + '|' + PadRight(CompModelId, 20) + '|' + PadRight(ModName, 24) + ' | ' + PadRight(ModelTypeToStr(ModType), 12)
                    + ' | ' + PadLeft(IntToStr(MOrigin.X-BOrigin.X),10) + ' | ' + PadLeft(IntToStr(MOrigin.Y-BOrigin.Y),10) + ' | ' + FloatToStr(ModRot)  + ' | ' + CompArea
                    + ' | ' + CoordUnitToStringWithAccuracy(CBOverallHeight, NBUnit, 4, 3) );

//  vault stuff
//            if CompModel.ItemGUID <> '' then
//            Rpt.Add('ItemGUID : ' + CompModel.ItemGUID + '  ItemRevGUID : ' + CompModel.ItemRevisionGUID + '  VGUID : ' + CompModel.VaultGUID);

        end;
// generics
        if ModType <> e3DModelType_Generic then
        begin
            ModName := CBodyName;

// name the blank models with designator & footprint pattern
            if (Fix = cFix) then
            if (CompModelId = '') then
                CompBody.SetState_Identifier(NewName);
            CompModelId := CompBody.Identifier;

            Inc(Result);

            Rpt.Add('   ' + PadRight(IntToStr(Result),2) + '|' + PadRight(CompModelId, 20) + '|' + PadRight(ModName, 24) + ' | ' + PadRight(ModelTypeToStr(ModType), 12)
                    + ' | ' + PadLeft(IntToStr(MOrigin.X-BOrigin.X),10) + ' | ' + PadLeft(IntToStr(MOrigin.Y-BOrigin.Y),10) + ' | ' + FloatToStr(ModRot)  + ' | ' + CompArea
                    + ' | ' + CoordUnitToStringWithAccuracy(CBOverallHeight, NBUnit, 4, 3) );
        end;
    end;
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

