{ ProjectReLinker.pas

  A Wrapper for (requires) CompSourceLibReLinker.pas
  that iterates over all project files:-
- 1. linking SchLibs to PcbLibs
- 2. linking SchDocs to SchLib & SchImpl-models to PcbLib
- 3. linking PcbDocs to PcbLib FP.
- 4. make summary report

2 direct call entry points. Calls procedures in another script unit.

Focus any project file (SchLib, SchDoc PcbDoc PcbLib) & will process
in correct order to relink all components & comp models & footprints to Prj source libraries.

BLM
11/05/2020  0.10 POC initial project wrapper
12/05/2020  0.11 unbreak the lib find method.
31/05/2020  0.12 support LibPkg projects; remove the installed lib reporting
05/05/2020  0.13 SerDoc methods to overcome Server open but not loaded & not updating serverview of doc.

Requires a project "holder" so procedures & functions can be found/shared.
..............................................................................}
const
    ReportFileSuffix    = '_LibLinkSummary';
    ReportFileExtension = '.txt';
    ReportFolder        = 'Reports';

Var
    WS        : IWorkspace;
    Prj       : IProject;
    IntLibMan : IIntegratedLibraryManager;
    Report    : TStringList;
    Summary   : TStringList;


{..............................................................................}
function SafeSaveDocument(Doc : IDocument, const ServerName : WideString) : boolean;
var
    SM          : IServerModule;
    ServerDoc   : IServerDocument;
    J           : Integer;

begin
    Result := false;
    SM := Client.ServerModuleByName(ServerName);
    for J := 0 to (SM.DocumentCount - 1) do
    begin
        ServerDoc := SM.Documents[J];
        if ExtractFilename(ServerDoc.FileName) = Doc.DM_Filename then
        begin
            Result := ServerDoc.DoSafeFileSave(Doc.DM_DocumentKind); // cDocKind_SchLib);
        end;
    end;
end;

function IterateTheDocs(DocKind : TDocumentKind, const Fix : Boolean, var TotSLinkCount, var TotFLinkCount : integer) : boolean;
var
    Doc            : IDocument;
    SerDoc         : IServerDocument;
    SLinkCount     : Integer;
    FLinkCount     : Integer;
    I              : Integer;
    bSuccess       : boolean;

Begin
    Result := false;

    For I := 0 to (Prj.DM_LogicalDocumentCount - 1) Do
    Begin
        Doc := Prj.DM_LogicalDocuments(I);
        If Doc.DM_DocumentKind = DocKind Then
        Begin
            Summary.Add('');
            Summary.Add('');
            Summary.Add('=============== New Doc ==============================');
            Summary.Add('  Doc    : ' + Doc.DM_FileName);
            Summary.Add('');


//            SerDoc := Client.OpenDocument('Sch', Doc.DM_FullPath);
            SerDoc  := Client.OpenDocumentShowOrHide(DocKind, Doc.DM_FullPath, true);      //TPCBLibDocument or TSCH ??
            if SerDoc <> nil then
                Client.ShowDocument(SerDoc);

            bSuccess := false;
            if (DocKind = cDocKind_SchLib) or (DocKind = cDocKind_Sch) then
                bSuccess := LinkSchCompsWrapped(Doc, Fix, SLinkCount, FLinkCount);

            if DocKind = cDocKind_Pcb then
                bSuccess := LinkFPModelsWrapped (Doc, Fix, SLinkCount, FLinkCount);

            if bSuccess then
                SerDoc.Modified := True;

            if (bSuccess and (DocKind = cDocKind_SchLib)) then
            begin
                bSuccess := SafeSaveDocument(Doc, 'SCH');
            end;

            Summary.Add('  Sheet  : ' + Doc.DM_FileName);
            Summary.Add('Sheet Missing Sch Symbol Link Count : ' + IntToStr(SLinkCount));
            Summary.Add('Sheet Missing Footprint Link Count  : ' + IntToStr(FLinkCount));
            Summary.Add(' ************** End Doc ******************************* ');

            TotSLinkCount := TotSLinkCount + SLinkCount;
            TotFLinkCount := TotFLinkCount + FLinkCount;
        End;
    End;

    Result := true;
end;


Procedure ReportWrapper(const Fix : boolean);
var
    FilePath       : WideString;
    FileName       : WideString;
    FileNumber     : integer;
    FileNumStr     : WideString;
    ReportDocument : IServerDocument;

    TotSLinkCount  : Integer;            // Total missing symbol link count
    TotFLinkCount  : Integer;            // Total missing footprint model link count
    SubTotSLinkCount  : Integer;         // Total missing symbol link count in same doc type
    SubTotFLinkCount  : Integer;         // Total missing footprint model link count  in same doc typr
    LibCount       : integer;
    SMess          : WideString;
    I              : integer;
    bSuccess       : boolean;

Begin
    Prj := GetWorkSpace.DM_FocusedProject;
    If Prj = Nil Then Exit;
// board or LibPkg(IntLib) projects
    if not ((Prj.DM_ObjectKindString = 'PCB Project') or
            (Prj.DM_ObjectKindString = 'Integrated Library')) then
    begin
        ShowMessage('not a PCB or LibPkg project ');
        exit;
    end;

    IntLibMan := IntegratedLibraryManager;
    If IntLibMan = Nil Then Exit;
    if PCBServer = Nil then Client.StartServer('PCB');
    if SchServer = Nil then Client.StartServer('SCH');


    Summary  := TStringList.Create;
    Summary.Add('Project Library Re-Linker');
    Summary.Add('  Project: ' + Prj.DM_ProjectFileName);
    Summary.Add('');

    TotSLinkCount :=0;
    TotFLinkCount :=0;
    SubTotSLinkCount :=0;
    SubTotFLinkCount :=0;

    bSuccess := IterateTheDocs(cDocKind_SchLib, Fix, SubTotSLinkCount, SubTotFLinkCount);
    if not bSuccess then
    begin
        ShowMessage('problem with SchLib(s) ');
        exit;
    end;
    Summary.Add('SubTot SchLib Missing Sch Symbol Link Count : ' + IntToStr(SubTotSLinkCount));
    Summary.Add('SubTot SchLib Missing Footprint Link Count  : ' + IntToStr(SubTotFLinkCount));

    TotSLinkCount := TotSLinkCount + SubTotSLinkCount;
    TotFLinkCount := TotFLinkCount + SubTotFLinkCount;
    SubTotSLinkCount :=0;
    SubTotFLinkCount :=0;

    bSuccess := IterateTheDocs(cDocKind_Sch, Fix, SubTotSLinkCount, SubTotFLinkCount);
    if not bSuccess then
    begin
        ShowMessage('problem with SchDoc(s) ');
        exit;
    end;
    Summary.Add('SubTot SchDoc Missing Sch Symbol Link Count : ' + IntToStr(SubTotSLinkCount));
    Summary.Add('SubTot SchDoc Missing Footprint Link Count  : ' + IntToStr(SubTotFLinkCount));

    TotSLinkCount := TotSLinkCount + SubTotSLinkCount;
    TotFLinkCount := TotFLinkCount + SubTotFLinkCount;
    SubTotSLinkCount :=0;
    SubTotFLinkCount :=0;

    bSuccess := IterateTheDocs(cDocKind_Pcb, Fix, SubTotSLinkCount, SubTotFLinkCount);
    if not bSuccess then
    begin
        ShowMessage('problem with PcbDoc(s) ');
    end;
    Summary.Add('SubTot PcbDoc Missing Footprint Link Count  : ' + IntToStr(SubTotFLinkCount));

    TotFLinkCount := TotFLinkCount + SubTotFLinkCount;

    Summary.Insert(LibCount + 6, 'Total Missing Sch Symbol Link Count : ' + IntToStr(TotSLinkCount));
    Summary.Insert(LibCount + 7, 'Total Missing Footprint Link Count  : ' + IntToStr(TotFLinkCount));
    Summary.Add('===========  EOF  ==================================');

    FilePath := Prj.DM_ProjectFullPath;
    FileName := ExtractFileName(FilePath) + '_' + ReportFileSuffix;
    FilePath := ExtractFilePath(FilePath) + ReportFolder;
    if not DirectoryExists(FilePath, false) then
        DirectoryCreate(FilePath);

    FileNumber := 1;
    FileNumStr := IntToStr(FileNumber);
    FilePath := FilePath + '\' + FileName;
    While FileExists(FilePath + FileNumStr + ReportFileExtension) do
    begin
        inc(FileNumber);
        FileNumStr := IntToStr(FileNumber)
    end;
    FilePath := FilePath + FileNumStr + ReportFileExtension;
    Summary.SaveToFile(FilePath);

    ReportDocument := Client.OpenDocument('Text', FilePath);
    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;
End;

Procedure FixCompLibraryLinks;
Begin
    ReportWrapper(true)
End;

Procedure ReportCompLibraryLinks;
begin
    ReportWrapper(false)
end;


