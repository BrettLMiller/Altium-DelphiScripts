{ ListLibraries2.pas gitclean.
  from  ListLibraries2.pas

Report from all Installed IntLib libraries.
Create three formatted text files using preset parameter name headings.
  
BL Miller
01/05/2020  v0.10 POC demo
---
2024-03-09  v0.31 git cleaned strip out non-IntLib.
2024-03-12  v0.32 add OverallHeight to Model report.

PcbLib 3D model reporting does slow down this script by 2 - 4 x !!

Not supported:
Source libs.
Vault CmpLibs: need to be installed like File-Based libs but "from server" : not a viable long term solution.
DBLib: need libADO.pas (+glue) to make useful.
}

const
//  used to report CMP parameters / column headings for report.
    ReportParameters = 'FUNCTION|Description|Value|Tolerance|Voltage|Current|Power|Dielectric|TCR|MFR|MPN|PLMPartStatus|SAP P/N|Notes|Component Kind|Part Description 1|Footprint|Pin Count|SMD Marking|Comment|Designator';
    RepFPParameters  = 'Description|Height|Pad Count';    // std. fixed FP internal parameter names

    IgnoreLibName   = 'Simulation';    // ignore AD Sim IntLib.
    cTableRowOffset = 24;
    bRep3DModels    = true;            // loads each FP model into PCBEditor so much slower.

var
    Report         : TStringList;                // for comps & para
    MReport        : TStringList;                // for PCB models
    PReport        : TStringList;                // for PCB models
    RepParaList    : TStringList;
    RepFPParaList  : TStringList;
    IntLibMan      : IIntegratedLibraryManager;

procedure IntegLibrary(FullPath : WideString, LibType : integer); forward;
function GetImplementation (Component : ISCh_Component, ModelName : WideString, ModelType : WideString) : ISch_Implementation; forward;
function LibraryType (LibPath : WideString) : ILibraryType; forward;

Procedure ListTheLibraries;
var
    WS             : IWorkspace;
    Prj            : IProject;

    FilePath       : WideString;
    FileName       : WideString;
    ReportDocument : IServerDocument;
    Doc            : IDocument;
    I, J           : Integer;
    LibCount       : integer;
    CompCount      : integer;
    SubCmpCount    : integer;
    SMess          : WideString;
    FolderList     : WideString;
    ReportIndex    : integer;

Begin
    WS  := GetWorkspace;
    If WS = Nil Then Exit;

    Prj := WS.DM_FocusedProject;
//    If Prj = Nil Then Exit;

    IntLibMan := IntegratedLibraryManager;
    If IntLibMan = Nil Then Exit;

    if PCBServer = Nil then Client.StartServer('PCB');
    if SchServer = Nil then Client.StartServer('SCH');

    RepParaList := TStringlist.Create;
    RepParaList.Delimiter := '|';
    RepParaList.StrictDelimiter := true;
    RepParaList.DelimitedText := ReportParameters;
// footprint
    RepFPParaList := TStringlist.Create;
    RepFPParaList.Delimiter := '|';
    RepFPParaList.StrictDelimiter := true;
    RepFPParaList.DelimitedText := RepFPParameters;

    Report    := TStringList.Create;
    MReport   := TStringList.Create;
    PReport   := TStringList.Create;

    Report.Add(GetRunningScriptProjectName + ' ' + GetCurrentDocumentFileName);
    Report.Add('Library Interface information:');
    Report.Add('');
    Report.Add('Usable File-Based Libraries:|Idx | LibType | FullPath | | CompCount');

    LibCount := 0;
    for I := 0 to (IntLibMan.InstalledLibraryCount - 1) Do
    begin
        FilePath  := IntLibMan.InstalledLibraryPath(I);
        if ansipos(IgnoreLibName, ExtractFileNameFromPath(FilePath)) = 1 then
            continue;

        ReportIndex := Report.Count;
        inc(LibCount);
        CompCount := IntLibMan.GetComponentCount(FilePath);

// TLibraryType = (eLibIntegrated, eLibSource, eLibDatafile, eLibDatabase, eLibNone, eLibQuery, eLibDesignItems);
        case LibraryType(Filepath) of     // fn from common libIntLibMan.pas
            eLibIntegrated : SMess := 'IntLib   : ' + '|' +  PadRight(FilePath,30);
            else
                SMess              := 'unusable : ' + '|' +  PadRight(FilePath,30);

        end;
        Report.Insert(ReportIndex, '|' + PadRight(IntToStr(LibCount),2) + ' | ' + SMess + '||' + IntToStr(CompCount) );

    end;

    Report.Add('avail libs count ' + IntToStr(IntLibMan.AvailableLibraryCount));

    Report.Add('');
    for I := 0 to (cTableRowOffset - LibCount) do
        Report.Add('');

    MReport.DelimitedText := Report.DelimitedText;
    PReport.DelimitedText := Report.DelimitedText;

    Report.Add( 'LibId                          | Idx | ' + PadRight('CompName', 50) + ' | ' + PadRight('Desc',50) + ' |MIdx| ' + PadRight('Model',40) + ' | Current');
    MReport.Add('LibId                          | Idx | ' + PadRight('ModelName',50) + ' | ' + PadRight('Description', 50) + ' | Height (mil) | PadCount | SourcePcbLib | 3D Model  |  FileName          |  OvlHeight (mm)');
    PReport.Add('LibId                          | Idx | ' + PadRight('CompName', 50) + ' |PCnt| ' + ReportParameters );

    for I := 0 to (IntLibMan.InstalledLibraryCount - 1) Do
    begin
        FilePath := IntLibMan.InstalledLibraryPath(I);
        if ansipos(IgnoreLibName, ExtractFileNameFromPath(FilePath)) = 1 then
            continue;

        if (LibraryType(FilePath) = eLibIntegrated) then
        begin
            IntegLibrary(FilePath, eLibIntegrated);
        end;
    end;

    RepParaList.Free;
    RepFPParaList.Free;

    FilePath := Prj.DM_ProjectFullPath;
    if (FilePath = '') or (FilePath = 'Free Documents') then
        FilePath := SpecialFolder_MyDocuments;

    FileName := FilePath + '\LibraryList_Report.Txt';
//    FileName := 'C:\temp' + '\LibraryList_Report.Txt';
    Report.SaveToFile(FileName);
    Report.Free;
    ReportDocument := Client.OpenDocument('Text', FileName);

    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;

// Comp paras
    FileName := FilePath + '\LibListParas_Report.Txt';
    PReport.SaveToFile(FileName);
    PReport.Free;

    ReportDocument := Client.OpenDocument('Text', FileName);

    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;

// FP models
    FileName := FilePath + '\LibListModel_Report.Txt';
    MReport.SaveToFile(FileName);
    MReport.Free;

    ReportDocument := Client.OpenDocument('Text', FileName);

    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;
end;

procedure IntegLibrary(FullPath : WideString, LibType : integer);
var
    CompName    : WideString;
    CompDesc    : WideString;
    CompModel   : WideString;
    LibComp     : ISch_Component;
    SchImpl     : ISch_Implementation;
    LibIdKind   : ILibIdentifierKind;
    LibId       : Widestring;
    SourceLib   : WideString;
    FolderPathList  : WideString;
    FolderGUIDList  : WideString;
    VaultGUID       : WideString;

    FoundLoc    : WideString;
    CompLoc     : WideString;
    CompCount   : integer;
    Model       : IModel;
    ModelCount  : integer;
    ModelName   : WideString;
    ModelPath   : WideString;
    ModelType   : IModelType;
    ModDesc     : WideString;
    ModHeight   : WideString;
    PadCount    : WideString;
// 3D
    PLComp      : IPCB_LibComponent;
    LC3DBody    : IPCB_ComponentBody;
    LC3DModel   : IPCB_Model;
    LC3DModName : WideString;
    LC3DModFN   : WideString;
    LC3DOvlHeight : TCoord;

    LibParaList : TStringList;
    ParaCount   : integer;
    ParaName    : WideString;
    ParaValue   : WideString;

    Parameters  : WideString;
    ModelList   : TStringList;
    ModelDesc   : TStringList;
    ParseLine   : TStringList;
    I, J, K, L  : integer;
    Current     : boolean;
    ModelOkay   : boolean;

begin
    LibParaList := TStringlist.Create;
    LibParaList.StrictDelimiter := true;
    LibParaList.NameValueSeparator := '=';
    LibParaList.Delimiter := '|';

    ModelDesc := TStringList.Create;
    ModelDesc.StrictDelimiter := true;
    ModelDesc.NameValueSeparator := #02;      // char never present in normal text
    ParseLine := TStringList.Create;
    ParseLine.StrictDelimiter := true;
    ParseLine.Delimiter := #03;               // char never present in normal text

    ModelList := TStringList.Create;
    ModelList.Sorted          := true;
    ModelList.Duplicates      := dupIgnore;

    CompCount := IntLibMan.GetComponentCount(FullPath);
    LibId := ExtractFileName(FullPath);

    for I := 0 to (CompCount -1) do
    begin
        CompName   := IntLibMan.GetComponentName(FullPath,I);
        ParaCount  := IntLibMan.GetParameterCount(Fullpath, I);
        CompDesc := ''; CompModel := '';
        Parameters := '';
        LibParaList.Clear;

        LibComp := SchServer.LoadComponent(eLibIdentifierKind_FullPath, Fullpath, CompName);

        if LibComp <> nil then
            CompDesc := LibComp.ComponentDescription;

        for J := 0 to (ParaCount - 1) do
        begin
            ParaName  := Trim( IntLibMan.GetParameterName(FullPath, I, J) );
            ParaValue := Trim( IntLibMan.GetParameterValue(FullPath, I, J) );
// handle leading = for Excel.
            if ParaValue[1] = '=' then ParaValue := #39 + ParaValue;

            LibParaList.Add(ParaName + '=' + ParaValue);
            if ParaName = 'Description' then
                if CompDesc = '' then
                    CompDesc := ParaValue;
            if ParaName = 'Footprint' then
                CompModel := ParaValue;
        end;

        for J := 0  to (RepParaList.Count - 1) do
        begin
            ParaName := RepParaList.Strings(J);
            K := LibParaList.IndexOfName(ParaName);
            if (K > -1) then
                Parameters := Parameters + '|' + PadRight(LibParaList.ValueFromIndex(K),20)
            else
                Parameters := Parameters + '|                    ';
        end;
        PReport.Add(PadRight(LibId,30) + ' | ' + PadLeft(IntToStr(I+1),3) + ' | ' + PadRight(CompName, 50) + ' | ' + PadLeft(IntToStr(ParaCount+1),3) + Parameters);

// get modellist.
        ModelCount := IntLibMan.GetModelCount(Fullpath, I);
        for J := 0 to (ModelCount - 1) do
        begin
            Model     := IntLibMan.GetModel(FullPath, I, J);
            ModelName := IntLibMan.GetModelName(FullPath, I, J);
            if LibType = eLibIntegrated then
                ModelType := IntLibMan.GetModelType(FullPath, I, J);

//            Model.GetModelParameterByName('Height');

            Current := false;
            if SameString(CompModel, ModelName, false) then Current := true;

            Report.Add(PadRight(LibId,30) + ' | ' + PadLeft(IntToStr(I+1),3) + ' | ' + PadRight(CompName, 50) + ' | ' + PadRight(CompDesc,50) + ' | ' + PadRight(IntToStr(J+1),2)  + ' | ' + PadRight(ModelName,40) + ' | ' + IntToStr(Current) );

            ModelOkay := false;
            If (ModelType.Name = cModelType_PCB) then ModelOkay := true;

            if ModelOkay then
            begin
                if (ModelList.IndexOf(ModelName) < 0) then
                begin
// find the original source PcbLib filename.
                    SourceLib := '';
                    if LibComp <> nil then
                    begin
                        SchImpl := GetImplementation (LibComp, ModelName, cModelType_PCB);
                        if SchImpl <> nil then
                            if SchImpl.DatafileLinkCount > 0 then
                                SourceLib := SchImpl.DatafileLink(0).Location;
                    end;

                    LC3DModName   := 'no generic model';
                    LC3DModFN     := '';
                    LC3DOvlHeight := 0;
                    PLComp        := nil;

                    ModelPath := IntLibMan.FindModelLibraryPath (eLibIdentifierKind_FullPath, Fullpath, CompName, ModelName, cModelType_PCB);
                    if (bRep3DModels) then
                        PLComp := PCBServer.LoadCompFromLibrary (ModelName, Modelpath);   // LibID);

                    if PLComp <> nil then
                    for L := 1 to PLComp.GetPrimitiveCount(MkSet(eComponentBodyObject)) do
                    begin
                        LC3DBody      := PLComp.GetPrimitiveAt(L, eComponentBodyObject);
                        LC3DOvlHeight :=  LC3DBody.OverallHeight;
                        LC3DModName   := LC3DBody.Identifier;
                        LC3DModel     := LC3DBody.Model;
                        if  LC3DModel <> nil then
                        if  (LC3DModel.ModelType = e3DModelType_Generic) then
                            LC3DModFN := ExtractfileName(LC3DModel.FileName);
                    end;

// there are only 3 FP model parameters.
                    Parameters :=  ModelName + #02;
                    for K := 0  to (RepFPParaList.Count - 1) do
                    begin
                        ParaName := RepFPParaList.Strings(K);
                        ModDesc  := Model.GetModelParameterValueByName(ParaName);
                        if ModDesc = 'Footprint not found'  then
                            ModDesc := '<blank>';
                        Parameters := Parameters + ModDesc + #03;
                    end;

                    ModelList.Add(ModelName);
                    ModelDesc.Add(Parameters + SourceLib + #03 + LC3DModName + #03 + LC3DModFN + #03 + CoordUnitToStringWithAccuracy(LC3DOvlHeight, eMM, 4, 3) );  // Model.ModelDescription);
                end;
            end;
        end;

    end;

    for J := 0 to (ModelList.Count - 1) do
    begin
        ModelName := ModelList.Strings(J);

        ParseLine.Clear;
        ParseLine.Add(' ' + #03 + ' ' + #03 + ' ' + #03 + ' ');
        Parameters := '';

        K := ModelDesc.IndexOfName(ModelName);
        if K >= 0 then
            ParseLine.DelimitedText := ModelDesc.ValueFromIndex(K);

        for K := 0 to (ParseLine.Count - 1) do
        begin
            L := 50;
            if K > 0 then L := 13;
            ParaValue  := PadRight(ParseLine.Strings(K), L);
            Parameters := Parameters + ' | '  + ParaValue;
        end;
        MReport.Add(PadRight(LibId,30) + ' | ' + PadRight(IntToStr(J+1), 3) + ' | ' + PadRight(ModelName, 50) + Parameters );
    end;

    ModelList.Clear;
    ModelDesc.Clear;
    ParseLine.Clear;
end;

function GetImplementation (Component : ISch_Component, ModelName : WideString, const ModelType : WideString) : ISch_Implementation;
var
    SchImpl         : ISch_Implementation;
    ImplIterator    : ISch_Iterator;
    ImpList         : TInterfaceList;
begin
    Result := nil;
    if Component = nil then exit;

//    ImpList := GetState_AllImplementations(Component);

    ImplIterator := Component.SchIterator_Create;
    ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation));
    SchImpl := ImplIterator.FirstSchObject;

    While SchImpl <> Nil Do
    Begin
       If SchImpl.ModelType = ModelType Then
       if SchImpl.ModelName = ModelName then
           Result := SchImpl;

       SchImpl := ImplIterator.NextSchObject;
    end;
    Component.SchIterator_Destroy(ImplIterator);
end;

Function LibraryType (LibPath : WideString) : ILibraryType;
// LibPath is the full path & name.
var
    I        : Integer;
    LibCount : Integer;

begin
    Result := -1;
    IntLibMan := IntegratedLibraryManager;
    LibCount := IntLibMan.AvailableLibraryCount;   // zero based totals !

    I :=0;
    While (Result < 0) and (I < LibCount) Do           //.Available...  <--> .Installed...
    Begin
        if IntLibMan.AvailableLibraryPath(I) = LibPath then
            Result := IntLibMan.AvailableLibraryType(I);
        Inc(I);
    end;
End;
