{ Split_CombineSchLib.pas

For SchLibs:
-  split into a folder of separate SchLib files.
For project or any focused doc
-  combine folder of SchLibs into one
-  if focused doc is SchLib then add to it.
-  creates new SchLib if there is a focused project

 The user has to handle the dummy Component_1 when combining SchLibs.

 Author B. Miller
 16/05/2021  v0.10  POC
 24/07/2022  v1.0   works okay.
 05/03/2023  v1.1   sort SchLib files by FileAge(), combine old --> new.

see MakeSchLib.pas

}
const
    cCSLFolder     = 'Combine';
    cSSLFolder     = 'SplitLibs';
    cCSLLibName    = 'NewCombined';
    cDummyCompName = 'Component_1';    // new schLib always has default dummy comp

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;

function CheckLibCompName(SchLib : ISch_Lib, const CompName : WideString) : WideString; forward;
function MakeValidFileName(const fileName : string) : WideString; forward;

function CheckAddSourceDocToProject(DocFullPath : WideString) : boolean;
begin
    Result := false;
    if Project.DM_IndexOfSourceDocument(DocFullPath) < 0 then
        Project.DM_AddSourceDocument(DocFullPath);
end;

function CheckCreateSourceDocInProject(DocName : WideString, const DocKind : TDocumentKind ) : IDocument;
var
   LibSerDoc    : IServerDocument;
   LibFullPath  : WideString;
   FileExten    : WideString;
   Success      : boolean;
begin
    Result := nil;
    FileExten := '.txt';
    FileExten := Client.GetDefaultExtensionForDocumentKind(DocKind);
    LibFullPath := ExtractFilePath(Project.DM_ProjectFullPath) + DocName + cDotChar + FileExten;

    if not FileExists(LibFullPath, false) then
    begin
//      default new name is SchLib1.SchLib
        LibSerDoc := CreateNewDocumentFromDocumentKind(DocKind);

// no other way to set ALWAYSSHOWCD=T
        Client.SendMessage('SCH:DocumentPreferences', 'Tab=Library Editor Options | Action=EditProperties', 512, Client.CurrentView);
        Success := LibSerDoc.DoSafeChangeFileNameAndSave(LibFullPath, DocKind);
    end;

    if Project.DM_IndexOfSourceDocument(LibFullPath) < 0 then
        Project.DM_AddSourceDocument(LibFullPath);

//    FileExists(LibFullPath, false);
    Result := GetWorkSpace.DM_GetDocumentFromPath(LibFullPath);   // IDocument
end;


procedure CombineSchLibFolder;
var
    LibDoc         : IDocument;
    AServerDoc     : IserverDocument;
    NewSchLib      : ISch_Lib;
    TargetLib      : ISch_Lib;
    TargetComp     : ISch_Component;
    NewComp        : ISch_Component;
    TargetCName    : Widestring;
    NewCompName    : WideString;
    SIterator      : ISch_Iterator;

    PrjPath        : WideString;
    BoardName      : WideString;
    ImportFolder   : WideString;
    ImportFiles    : TStringList;
    ImpFileDate    : TStringList;

    InpFilePath    : WideString;
    InpFileName    : WideString;
    FileDate       : WideString; //integer;
    FDateTime      : TDateTime;
    FileIndex      : integer;
    I, J           : integer;
    bCreateNewLib  : boolean;

begin
    Project := GetWorkSpace.DM_FocusedProject;
    Document := GetWorkSpace.DM_FocusedDocument;
    if (Project.DM_ObjectKindString = 'Free Documents') and (Document = nil) then
    begin
         ShowMessage('No focused document or no project ');
         Exit;
    end;

    if Project <> nil then
        PrjPath   := ExtractFilePath(Project.DM_ProjectFullPath);
    if (PrjPath = 'Free Documents)') or (PrjPath = '') then
        PrjPath   := ExtractFilePath(Document.DM_FullPath);

    if SchServer = Nil then Client.StartServer('SCH');
    NewSchLib := SchServer.GetCurrentSchDocument;

    bCreateNewLib := true;
    if NewSchLib <> nil then
    If (NewSchLib.ObjectID = eSchLib) Then
        bCreateNewLib := false;

    if (bCreateNewLib) then
    begin
        LibDoc := CheckCreateSourceDocInProject(cCSLLibName, cDocKind_Schlib);
//    SchLib := SchServer.CreateSchLibrary;
        NewSchLib := SchServer.GetSchDocumentByPath(LibDoc.DM_FullPath);
        if NewSchLib = Nil then
            NewSchLib := SchServer.LoadSchDocumentByPath(LibDoc.DM_FullPath);
    end;

    if not DirectoryExists(PrjPath + cCSLFolder, false) then
    begin
        ShowMessage('no Combine subfolder not found ' + PrjPath + cSXFolder);
        exit;
    end;

    Rpt := TStringList.Create;
    Rpt.Add('');
    Rpt.Add('Import ' + cCSLFolder + ' Folder Files into: ' + NewSchLib.DocumentName);

    ImportFiles := TStringList.Create;
    FindFiles(PrjPath + cCSLFolder, '*.' + Client.GetDefaultExtensionForDocumentKind(cDocKind_Schlib), faAnyFile, false, ImportFiles);

    ImpFileDate := TStringList.Create;
    ImpFileDate.NameValueSeparator := '=';


// get file age & sort old to new
    for I := 0 to (ImportFiles.Count - 1) do
    begin
        InpFilePath := ImportFiles.Strings(I);
        FDateTime := FileAge(InpFilePath);
        FileDate := PadLeftCh(IntToStr(FDateTime), '0', 16);
        ImpFileDate.Add(FileDate + '=' + IntToStr(I));
    end;
    ImpFileDate.Sort;

    for I := 0 to (ImportFiles.Count - 1) do
    begin
        FileIndex := ImpFileDate.ValueFromIndex(I);
        InpFilePath := ImportFiles.Strings(FileIndex);

        TargetLib := SchServer.GetSchDocumentByPath(InpFilePath);
        if TargetLib = Nil then
            TargetLib := SchServer.LoadSchDocumentByPath(InpFilePath);

        SIterator := TargetLib.SchLibIterator_Create;
        SIterator.SetState_FilterAll;
        SIterator.AddFilter_ObjectSet(MkSet(eSchComponent));
        TargetComp := SIterator.FirstSchObject;
        while (TargetComp <> Nil) Do
        begin
            NewComp := TargetComp.Replicate;
            TargetCName := TargetComp.LibReference;
            NewCompName := CheckLibCompName(NewSchLib, TargetCName);
            NewComp.LibReference := NewCompName;
            NewSchLib.AddSchComponent(NewComp);

            Rpt.Add('Comp ' + NewCompName + ' from ' + ExtractFileName(InpFilePath) + '|' + TargetCName );

            NewComp.SetState_SourceLibraryName(ExtractFileName(NewSchLib.DocumentName));
            NewComp.Librarypath := ExtractFilePath(NewSchLib.DocumentName);

            TargetComp := SIterator.NextSchObject;
        end;
        TargetLib.SchIterator_Destroy(SIterator);

//        AView := Client.GetCurrentView;
//        AServerDoc := Client.GetCurrentView.OwnerDocument;
//        Client.CloseDocument(AServerDoc);
    end;

    ImportFiles.Free;
    ImpFileDate.free;
    // Display the report
    FileName := ExtractFilePath(NewSchLib.DocumentName) + ChangefileExt(ExtractFileName(NewSchLib.DocumentName),'') + '_ImportSchLibRep.txt';
    Rpt.SaveToFile(Filename);
    Rpt.Free;

    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
end;

Procedure SplitSchLib;
var
    LibDoc         : IDocument;
    AServerDoc     : IserverDocument;
    NewSchLib      : ISch_Lib;
    TargetLib      : ISch_Lib;
    SIterator      : ISch_Iterator;
    Comp           : ISch_Component;
    TargetComp     : ISch_Component;
    NewComp        : ISch_Component;
    TargetCName    : Widestring;
    NewCompName    : WideString;

    PrjPath        : WideString;
    BoardName      : WideString;
    ImportFolder   : WideString;
    ImportFiles    : TStringList;

    OutFilePath    : WideString;
    InpFileName    : WideString;
    I, J           : integer;

begin
    Document := GetWorkSpace.DM_FocusedDocument;
    if  (Document = nil) then
    begin
         ShowMessage('No focused document ');
         Exit;
    end;
    if (Document.DM_DocumentKind <> cDocKind_Schlib) then
        exit;

    PrjPath   := ExtractFilePath(Document.DM_FullPath);

    if SchServer = Nil then Client.StartServer('SCH');
    TargetLib := SchServer.GetCurrentSchDocument;

    OutFilePath := ExtractFilePath(PrjPath) + cSSLFolder;

    Rpt := TStringList.Create;
    Rpt.Add('');
    Rpt.Add('Split to ' + OutFilePath + ' Folder for: ' + TargetLib.DocumentName);

    if not DirectoryExists(OutFilePath) then
    begin
        DirectoryCreate(OutFilePath);
        Rpt.Add('creating folder ' + OutFilePath);
    end;

    SIterator := TargetLib.SchLibIterator_Create;
    SIterator.SetState_FilterAll;
    SIterator.AddFilter_ObjectSet(MkSet(eSchComponent));
    TargetComp := SIterator.FirstSchObject;
    while (TargetComp <> Nil) Do
    begin
        TargetCName := TargetComp.LibReference;

        FileName :=  MakeValidFileName(TargetCName);
        FileName := FileName + '.' + Client.GetDefaultExtensionForDocumentKind(cDocKind_Schlib);

        AServerDoc := CreateNewFreeDocumentFromDocumentKind(cDocKind_Schlib, false);
        AServerDoc.DoSafeChangeFileNameAndSave(OutFilePath + PathDelim + Filename, cDocKind_SchLib);
        NewSchLib := SchServer.GetSchDocumentByPath(AServerDoc.FileName);
        if NewSchLib = Nil then
            NewSchLib := SchServer.LoadSchDocumentByPath(AServerDoc.FileName);

//        NewCompName := CheckLibCompName(NewSchLib, TargetCName);
//        NewComp.LibReference := NewCompName;
        NewComp := TargetComp.Replicate;
        NewSchLib.AddSchComponent(NewComp);

        Rpt.Add('Comp ' + TargetCName + ' to ' + ExtractFileName(NewSchLib.DocumentName) );

        NewComp.SetState_SourceLibraryName(ExtractFileName(NewSchLib.DocumentName));
        NewComp.Librarypath := ExtractFilePath(NewSchLib.DocumentName);

        NewComp := NewSchLib.GetState_SchComponentByLibRef(cDummyCompName);
        if NewComp <> nil then
            NewSchLib.RemoveSchComponent(NewComp);

        AServerDoc.DoFileSave('');
        Client.CloseDocument(AServerDoc);

        TargetComp := SIterator.NextSchObject;
    end;
    TargetLib.SchIterator_Destroy(SIterator);

    // Display the report
    if DirectoryExists(OutFilePath) then
        FileName := OutFilePath + '\' + ExtractFileName(TargetLib.DocumentName) + '-SplitLibReport.txt';

    Rpt.SaveToFile(Filename);
    Rpt.Free;

    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
end;

function CheckLibCompName(SchLib : ISch_Lib, const CompName : WideString) : WideString;
var
    CompLoc     : WideString;
    NewCompName : Widestring;
    Iterator    : ISch_Iterator;
    Comp        : ISch_Component;
    found       : boolean;
    Cnt : integer;
begin
    Result := CompName;
    Cnt := 1;
    NewCompName := CompName;

    repeat
        found := false;

        if SchLib.GetState_SchComponentByLibRef(NewCompName) <> nil then
            found := true;
        if found then
            NewCompName := CompName + '_' + IntToStr(Cnt); // IncrementStringasText('a_1', '1');

        inc(Cnt);
    until (Cnt > 10) or (not found);

    Result := NewCompName;
end;

function MakeValidFileName(const fileName : string) : WideString;
var
    InvalidFileChars : WideString;
    i : integer;
    c : WideString;
begin
// cInvalidWindowsFileNameChars
    InvalidFileChars := '\' + '/' + ':' + '*' + '?' + '"' + #39 + '|';

    Result := '';

    for i := 1 to Strlen(fileName) do
    begin
       c := fileName[i];
       if ansipos(c, InvalidFileChars) = 0 then
           Result := Result + c
       else
           Result := Result + '_';

    end;
    if Result = '' then Result := 'dummyfilename';
end; (* IsValidFileName *)
