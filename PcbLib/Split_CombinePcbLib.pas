{ Split-CombinePcbLib.pas

For PcbLibs:
-  split into separate files.
-  combine folder of PcbLibs (& all child FPs) into one new PcbLib
   if PcbLib is focused then add to it.


 Author B. Miller
 26/11/2021  v0.10 POC works.
 08/06/2022  v0.11 remove duplicate registeration? add comments.
 18/06/2022  v0.12 allow for combining into a focused existing PcbLib or create new..
 10/07/2022  v0.13  avoid FP iterator in PcbLib.
 04/02/2023  v0.14 add PlaceAllFPInPCB fn()

see MakeSchLib.pas

tbd: make Combine work with PcbDoc input files.

}
const
    cExportFolder   = 'SplitLibOut';
    cImportFolder   = 'Combine';
    cTargetSplitPrj = 'Split-PcbLibs';            // not-used
    cTargetPcbLib   = 'NewCombinedLib.PcbLib';    // not used...
    cDummyEmptyFP   = 'PCBCOMPONENT_1';

    cAX = 4000;
    cAY = 2000;

var
    Project   : IProject;
    Document  : IDocument;
    Rpt       : TStringList;
    FileName  : WideString;
    IsLib     : boolean;


function CheckCreateSourceDocInProject(Prj : IProject; DocName : WideString, const DocKind : TDocumentKind, const Overwrite : boolean) : IDocument;
var
   LibSerDoc    : IServerDocument;
   LibFullPath  : WideString;
   FileExten    : WideString;
   Success      : boolean;
begin
    Result := nil;
    FileExten := '.txt';
    FileExten := Client.GetDefaultExtensionForDocumentKind(DocKind);
    LibFullPath := ExtractFilePath(Prj.DM_ProjectFullPath) + DocName + cDotChar + FileExten;

    if not FileExists(LibFullPath, false) then
    begin
        if Overwrite then DeleteFile(LibFullPath);
//      default new name is SchLib1.SchLib or similar
        LibSerDoc := CreateNewDocumentFromDocumentKind(DocKind);

// no other way to set ALWAYSSHOWCD=T
//        Client.SendMessage('SCH:DocumentPreferences', 'Tab=Library Editor Options | Action=EditProperties', 512, Client.CurrentView);
        Success := LibSerDoc.DoSafeChangeFileNameAndSave(LibFullPath, DocKind);
    end;

    if Prj.DM_IndexOfSourceDocument(LibFullPath) < 0 then
        Prj.DM_AddSourceDocument(LibFullPath);

    Result := GetWorkSpace.DM_GetDocumentFromPath(LibFullPath);   // IDocument
end;


function CreateFreeSourceDoc(DocPath : WideString, DocName : WideString, const DocKind : TDocumentKind) : IServerDocument;
var
   LibFullPath  : WideString;
   FileExten    : WideString;
   Success      : boolean;
begin
    Result := nil;
    FileExten := '.txt';
    FileExten := Client.GetDefaultExtensionForDocumentKind(DocKind);
    LibFullPath := DocPath + '\' + DocName + cDotChar + FileExten;

    if FileExists(LibFullPath, false) then
        DeleteFile(LibFullPath);

//  an example default new name is SchLib1.SchLib
    Result := CreateNewFreeDocumentFromDocumentKind(DocKind, true);
    Success := Result.DoSafeChangeFileNameAndSave(LibFullPath, DocKind);

//    Result := GetWorkSpace.DM_GetDocumentFromPath(LibFullPath);   // IDocument
end;

procedure CombinePcbLibFolder;
var
    ServerDoc        : IServerDocument;
    SourceLib        : IPCB_Library;
    NewPcbLib        : IPCB_Library;
//    PrjPath        : WideString;
    Board            : IPCB_Board;
    Footprint        : IPCB_Component;        // IPcb_LibComponent;
    NewFP            : IPCB_Component;        // IPcb_LibComponent;

    PcbLibFiles      : TStringList;
    FolderPath       : WideString;
    FileExten        : WideString;
    FileName         : WideString;

    OffsetFile     : WideString;


    InpFilePath    : WideString;
    InpFileName    : WideString;
    I, J           : integer;
    UsedPaths      : TStringList;
    bCreateLib     : boolean;

begin
    FolderPath := SpecialFolder_Temporary;
    FileName   := cTargetPcbLib;

    Project := GetWorkSpace.DM_FocusedProject;
    If Project <> Nil Then
        FolderPath := ExtractFilePath(Project.DM_ProjectFullPath);

    IsLib  := false;

    Document := GetWorkSpace.DM_FocusedDocument;
    if Document <> Nil then
    begin
        FolderPath := ExtractFilePath(GetWorkSpace.DM_FocusedDocument.DM_FullPath);
        FileName   := ExtractFileName(GetWorkSpace.DM_FocusedDocument.DM_FullPath);

        if (Document.DM_DocumentKind = cDocKind_PcbLib) then
        begin
            NewPcbLib := PCBServer.GetCurrentPCBLibrary;
            Board := NewPcbLib.Board;
            IsLib := true;
        end;
    end;

    if (Project = nil) and (Document = nil) then
    begin
        ShowError('Failed to find a path from any focused doc/prj ');
        exit;
    end;

    if not DirectoryExists(FolderPath + cImportFolder, false) then
    begin
        ShowMessage('PcbLib file import subfolder not found ' + FolderPath + cImportFolder);
        exit;
    end;

    bCreateLib := false;
    if not IsLib then
    begin
        UsedPaths := TStringList.Create;
        FindFiles(FolderPath, '*.' + cDocKind_PcbLib, faAnyFile, false, UsedPaths);
        FileName := FolderPath + cTargetPcbLib;
        FileName := ExtractFileName(GetNextUniqueFileName(FileName,UsedPaths));
        UsedPaths.Free;
        ServerDoc := CreateFreeSourceDoc(FolderPath, ChangefileExt(FileName,''), cDocKind_PcbLib);
        NewPcbLib := PcbServer.LoadPCBLibraryByPath(ServerDoc.FileName);
        bCreateLib := true;
    end;

    Rpt := TStringList.Create;
    Rpt.Add('');
    Rpt.Add('Import Folder PcbLib/PcbDoc Files:');

    PcbLibFiles := TStringList.Create;
//   POS returns all uppercase.
    FindFiles(FolderPath + cImportFolder, '*.' + cDocKind_PcbLib, faAnyFile, false, PcbLibFiles);

    if PcbLibFiles.Count =0 then
        ShowMessage('No PcbLib files found in ' + cImportFolder);
    Rpt.Add(' import folder files : ' + FolderPath + cImportFolder + '  files ' + IntToStr(PcbLibFiles.Count+1));


    for i := 0 to (PcbLibFiles.Count - 1) do
    begin
        InpFilePath := PcbLibFiles.Strings(i);
        SourceLib := PcbServer.GetPCBLibraryByPath(InpFilePath);
        if SourceLib = Nil then
            SourceLib := PcbServer.LoadPCBLibraryByPath(InpFilePath);

        Rpt.Add(' file ' + IntToStr(i+1) + ' import file : ' + ExtractFileName(InpFilePath));

        PCBServer.PreProcess;

        for j := 0 to (SourceLib.ComponentCount - 1)  do
        begin
            Footprint := SourceLib.GetComponent(j);
            NewFP := NewPcbLib.GetComponentByName(Footprint.Name);

// overwrite pre-existing FP of the same name.
            if NewFP = nil then
            begin
                NewFP := NewPcbLib.CreateNewComponent;
//        this is probably redundant as NewFP must be nil..
                NewFP.Name := NewPcbLib.GetUniqueCompName(Footprint.Name);
            end;

            Footprint.CopyTo(NewFP, eFullCopy);
            NewPcbLib.RegisterComponent(NewFP);

// duplicate call ?
//            PCBServer.SendMessageToRobots(NewPcbLib.Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, NewFP.I_ObjectAddress);

            Rpt.Add('   ' +   IntToStr(i+1) + '.' + IntToStr(j+1) + '  footprint : ' + NewFP.Name);

        end;
       PCBServer.PostProcess;
    end;

    PcbLibFiles.Free;

    if (bCreateLib) then
    begin
        NewFP := NewPcbLib.GetComponentByName(cDummyEmptyFP);
        if NewFP <> nil then
        begin
            NewPcbLib.DeRegisterComponent(NewFP);
            NewPcbLib.RemoveComponent(NewFP);
        end;
        ServerDoc.DoFileSave('');
        Client.CloseDocument(ServerDoc);
    end else
    begin
        NewPcbLib.Board.ViewManager_FullUpdate;
        NewPcbLib.Board.GraphicalView_ZoomRedraw;
        NewPcbLib.RefreshView;
    end;

// if new PcbLib was created by user then may not be saved so path = blank
    if FolderPath = '' then
        FolderPath := SpecialFolder_Temporary;

    // Display the report
    Rpt.Insert(0, 'New PcbLib: ' + FileName);
    FileName := FolderPath + ChangefileExt(FileName,'') + '_CombinedPcbLibRep.txt';
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

Procedure SplitPcbLib;
var
    NewPrj           : IProject;
    SourceLib        : IPCB_Library;
    NewPcbLib        : IPCB_Library;
    Board            : IPCB_Board;
    FIterator        : IPCB_BoardIterator;

    Footprint        : IPCB_Component;        // IPcb_LibComponent;
    FPPattern        : TPCB_String;
    FPName           : IPCB_Text;
    FilePath         : WideString;
    FileExten        : WideString;
    FileSubPath      : WideString;
    ServerDoc        : IServerDocument;
    Doc              : IDocument;
    Success          : boolean;
    J                : integer;
    
begin
    Document := GetWorkSpace.DM_FocusedDocument;
//    if not ((Document.DM_DocumentKind = cDocKind_PcbLib) or (Document.DM_DocumentKind = cDocKind_Pcb)) Then
    if not (Document.DM_DocumentKind = cDocKind_PcbLib) Then
    begin
         ShowMessage('No PcbLib selected. ');
         Exit;
    end;
    IsLib  := false;
    if (Document.DM_DocumentKind = cDocKind_PcbLib) then
    begin
        SourceLib := PCBServer.GetCurrentPCBLibrary;
        Board := SourceLib.Board;
        IsLib := true;
    end else
        Board  := PCBServer.GetCurrentPCBBoard;

    if (Board = nil) and (SourceLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    Rpt := TStringList.Create;
    Rpt.Add('');
    Rpt.Add('Split PcbLib to folder :');

    FilePath := ExtractFilePath(Board.FileName) + cExportFolder;
    if not DirectoryExists(FilePath) then
    begin
        DirectoryCreate(FilePath);
        Rpt.Add('creating folder ' + FilePath);
    end;

    FilePath := ExtractFilePath(Board.FileName) + cExportFolder;
    Rpt.Add('Splitting/exporting to  ' + FilePath + '    ' + FilePath);

    if not IsLib then
    begin
        FIterator := Board.BoardIterator_Create;
        FIterator.AddFilter_ObjectSet(MkSet(eComponentObject));
        FIterator.AddFilter_IPCB_LayerSet(LayerSetUtils.SignalLayers);
        FIterator.AddFilter_Method(eProcessAll);   // TIterationMethod  [eProcessAll, eProcessFree, eProcessComponents ]

        Footprint := FIterator.FirstPCBObject;
        while Footprint <> Nil Do
        begin
            Footprint := SourceLib.GetComponent(j);
            FPName    := Footprint.Name.Text;
            FPPattern := Footprint.Pattern;

            FileSubPath := 'subfolder';
            FileSubPath :=  GetWindowsFileName(FPPattern);

            Footprint.SaveModelToFileAsPart(Filepath + '\' + FileSubPath + cDotChar + cDocKind_PcbLib);
 
            Rpt.Add('FP ' + FPName + '  ' + FPPattern + '  split/exported to  ' + FileSubPath);

            Footprint := FIterator.NextPCBObject;
        end;
        Board.BoardIterator_Destroy(FIterator);

    end else
    begin
        for j := 0 to (SourceLib.ComponentCount - 1)  do
        begin
            Footprint := SourceLib.GetComponent(j);
            FPName    := Footprint.Name;
            FPPattern := FPName;

            FileSubPath := 'subfolder';
            FileSubPath :=  GetWindowsFileName(FPPattern);

            Footprint.SaveToFile(Filepath + '\' + FileSubPath + cDotChar + cDocKind_PcbLib);

            Rpt.Add('FP ' + FPName + '  ' + FPPattern + '  split/exported to  ' + FileSubPath);
        end;
    end;
    Rpt.Insert(0, 'Split Footprints for ' + ExtractFileName(Board.FileName) );
    Rpt.Insert(1, '----------------------------------------------------------');

    // Display the report
    FilePath := ExtractFilePath(Board.FileName) + cExportFolder;
    if DirectoryExists(FilePath) then
        FileName := FilePath                  + '\' + ExtractFileName(Board.FileName) + '-FPModelExportReport.txt'
    else                                                  // ChangefileExt(ExtractFileName(Board.FileName),'')
        FileName := ExtractFilePath(Board.FileName) + ExtractFileName(Board.FileName) + '-FPModelExportReport.txt';

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

procedure PlaceAllFPInPCB;
var
    SourceLib        : IPCB_Library;
    Board            : IPCB_Board;
    TargetBoard      : IPCB_Board;
    FIterator        : IPCB_BoardIterator;

    Footprint        : IPCB_LIBComponent;
    FPPattern        : String;
    FPName           : String;
    ServerDoc        : IServerDocument;
    Doc              : IDocument;
    Comp             : IPCB_Component;
    J                : integer;

begin
    ServerDoc := Client.LastActiveDocumentOfType(cDocKind_Pcb);   // TPCBDocument
    TargetBoard := PCBServer.GetPCBBoardByPath(ServerDoc.FileName);

    SourceLib   := PCBServer.GetCurrentPCBLibrary;
    Board := SourceLib.Board;
    IsLib := true;

    if (Board = nil) and (SourceLib = nil) then
    begin
        ShowError('Failed to find PcbDoc or PcbLib.. ');
        exit;
    end;

    if TargetBoard = nil then
    begin
        ShowError('no current PcbDoc');
        exit;
    end;


    PCBServer.PreProcess;
    TargetBoard.BeginModify;

    for j := 0 to (SourceLib.ComponentCount - 1)  do
    begin
        Footprint := SourceLib.GetComponent(j);
        FPName    := Footprint.Name;
        FPPattern := FPName;

//        Comp := PCBServer. LoadCompFromLibrary(FPName, Board.FileName);  // IPCB_LibComponent

//    Client.SendMessage('PCB:PlaceComponent', 'Footprint=' + FPName, 255, Client.CurrentView);
//   Parameters : Footprint = RES10.55-7X2.8 | CommentAutoPosition = 6 | NameOn = False | Designator.Text = DesignatorText |Comment.Text = Commentary

//   current selected LibComp
//        Footprint.Selected := true;
//        Client.SendMessage('PCB:PlaceComponentFromLibraryEditor', '', 255, Client.CurrentView);

        Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
        Comp.SetState_Pattern(FPName);
//        Comp.SourceComponentLibrary := Board.Filename;
        Comp.SetState_SourceFootprintLibrary(Board.Filename);

// reference point of the Component FP
        Comp.X         := MilsToCoord(cAX);
        Comp.Y         := MilsToCoord(cAY) + (J * MilsToCoord(150));
        Comp.Layer     := eTopLayer;

// designator visible;
        Comp.NameOn         := True;
        Comp.Name.Text      := 'Custom' + IntToStr(j);
        Comp.Name.XLocation := MilsToCoord(cAX) + MilsToCoord(100);
        Comp.Name.YLocation := MilsToCoord(cAY) + (J * MilsToCoord(150));

// comment visible;
        Comp.CommentOn         := true;
        Comp.Comment.Text      := Footprint.Description;
        Comp.Comment.XLocation := MilsToCoord(cAX) + MilsToCoord(100);
        Comp.Comment.YLocation := MilsToCoord(cAY) + (J * MilsToCoord(150) - MilsToCoord(40));

        TargetBoard.AddPCBObject(Comp);
        PCBServer.SendMessageToRobots(TargetBoard.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);

        Comp.LoadCompFromLibrary;     // seems does nothing.
        Comp.SetState_XSizeYSize;
        Comp.GraphicallyInvalidate;
    end;
    TargetBoard.EndModify;
    PCBServer.PostProcess;

    Client.SendMessage('PCB:UpdateFootprints', 'Mode=All', 255, Client.CurrentView);
    TargetBoard.GraphicallyInvalidate;
    TargetBoard.ViewManager_FullUpdate;

end;

{---------------------------------------------------------------------------------------------------------------------------}

{
function IsValidFileName(const fileName : string) : boolean;
var
   InvalidFileChars : TSet;
   c : WideString;
begin
   InvalidFileChars := MkSet('\', '/', ':', '*', '?', '"', '', '|');

   Result := fileName  '';

   if result then
   begin
     for c in fileName do
     begin
       result := NOT InSet(c, InvalidCharacters);
       if NOT result then break;
     end;
   end;
end; (* IsValidFileName *)
}
{ eof }

