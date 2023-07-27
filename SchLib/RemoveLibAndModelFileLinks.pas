{ RemoveLibAndModelFileLinks.pas

  Operates on components of SchDoc & SchLib

Summary
  Removes Component library & Footprint Model Datafile Link, NOT the FP model entry

AD17: Comps in SchDoc sourced from DbLib (can) have .SymbolRef linked to shared symbol.
This causes problem making SchLib from these Comps.

           Look out for extra spaces in footprint names!! great time waster ..
 20180706 : BLM Version 1
 20180806 : BLM ver 1.1   moved new FPmodel load outside of loops!
 20190620 : minor error message improvements

 2019/09/20 : Delete Model Datafile links only
 2019/09/25 : Add new proc; less distructive just sets PcbLib = '*'
 2020/02/27 v1.0  Remove lib path for Sch component & FP models (set "Any").
 27/02/2020 v1.1  Diff report info for SchLib vs SchDoc & tweaks for SchLibs
                  No special treatment for DbLib sourced comps..
 28/02/2020 v1.2  Overwrite .SymbolReference so DBLib sourced comps can be made into SchLib.
 19/10/2020 v1.3  Added function to completely delete the model SchImp. to make Components into Symbols
 2023-07-27 v1.4  Full Wipeout: remove all Comp parameters & models. Set Comment & Desc.
 2023-07-27 v1.5  fix SchLib Cmp model & panel refreshing.
 2023-07-28 v1.6  exclude specific paramters from removal, better report footprint/model counts
..................................................................................}

{..............................................................................}
const
//   Symbol parameters still control font colour & position, for these just blank the value..
    IgnoreParas = 'Part Description|SAP P/N';    // list of do-not-remove parameter names "|" delimiter

Var
    Modelslist  : TStringList;
    XParaList   : TStringList;
    WS          : IWorkspace;
    Prj         : IProject;
    Doc         : IDocument;
    dConfirm    : boolean;

Function GetAllSchCompParameters(const Component : ISch_BasicContainer) : TList; forward;
Procedure TotalWipeoutComponentsToSymbols(const CurrentLib : ISch_Lib, var CmpCnt : integer); forward;
Procedure GenerateReport(Report : TStringList, Filename : WideString);  forward;
Procedure SetDocumentDirty (Dummy : Boolean); forward;

procedure WipeAllSchLibsInFolder();
var
    ServerDoc  : IServerDocument;
    LibList    : TStringList;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    TotCmpCnt  : integer; 
    CmpCnt     : integer;
    I          : integer;
begin
    LibList := TStringList.Create;
    ResetParameters;
    AddStringParameter('Dialog',    'FileOpenSave');
    AddStringParameter('Mode',      '0');
    AddStringParameter('FileType1', 'SchLib File (*.SchLib)|*.SchLib');
    AddStringParameter('Prompt',    'Select SchLib in target folder ');
    AddStringParameter('Path',      Path);
    RunProcess('Client:RunCommonDialog');

    GetStringParameter('Result', Path);
    if Path = 'True' then
    begin
        GetStringParameter('Path',   Path);
        Path     := ExtractFilePath(Path);
        FileName := ExtractFileName(Path);
// Dialog FileSaveOpen Mode 2 & 4 not supported
//        I := 1;
//        repeat
//            GetStringParameter('File'+IntToStr(I),  FileName);
//            LibList.Add(FileName);
//            inc(I);
//        until FileName = '';
    end;

    dConfirm := ConfirmNoYesWithCaption('Ready to Totally Remove ALL models in all SchLibs in Whole Folder ','Do you really want to do this ? ');
    if not dconfirm then exit;

// all stupid capitalised text
    FindFiles(Path, '*.SchLib',faAnyFile, false, LibList);

    dConfirm := ConfirmNoYesWithCaption('Totally Eliminate/Remove ALL models & paramters from all CMPs in All ' + IntToStr(LibList.Count) + ' SchLibs ','Very sure ? ');
    if not dconfirm then exit;

    Modelslist := TStringList.Create;
    ModelsList.Add    ('Remove All Existing Parameters/FP models in folder : ' + Path);
    ModelsList.Add('');

    for I := 0 to (LibList.Count - 1) do
    begin
        Filename := LibList.Strings(I);

// without this will process but not save back to filesystem!
        ServerDoc  := Client.OpenDocumentShowOrHide(cDocKind_Schlib, Filename, false);

        SchLib := SchServer.GetSchDocumentByPath(Filename);
        if SchLib = nil then
            SchLib := SchServer.LoadSchDocumentByPath(Filename);
        if SchLib <> nil then
        begin
            TotalWipeoutComponentsToSymbols(SchLib, CmpCnt);
            ServerDoc.DoSafeFileSave(cDocKind_Schlib);
            TotCmpCnt := TotCmpCnt + CmpCnt;
        end;
    end;

    ModelsList.Insert(0, 'Number processed of SchLibs : ' + IntToStr(LibList.Count) + '  Total Cmps : ' + IntToStr(TotCmpCnt) );
    GenerateReport(ModelsList, 'WipedCMPinSchLibFolder.txt');
    Modelslist.Free;
    LibList.Free;
end;

{..............................................................................}
Procedure RemoveLibraryPathFromSchComps;
Var
    CurrentSheet       : ISch_Document;
    Iterator           : ISch_Iterator;
    Component          : ISch_Component;
    ImplIterator       : ISch_Iterator;
    SchImplementation  : ISch_Implementation;
    ModelDataFile      : ISch_ModelDatafileLink;
    CompSrcLibName     : WideString;
    CompDBTable        : WideString;
    CompDesignId       : WideString;
    CompLibRef         : WideString;
    CompSymRef         : WideString;

    FPCount            : Integer;
    FLinkCount         : Integer;
    
Begin
 
    FLinkCount := 0;

    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
//    If PcbServer = Nil then Exit;

    If CurrentSheet.ObjectID = eSchLib Then
        Iterator := CurrentSheet.SchLibIterator_Create
    Else
        Iterator := CurrentSheet.SchIterator_Create;

    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    Modelslist := TStringList.Create;
    ModelsList.Add    (' All Existing FP models: ' + '  for libpath removal/deleting. ');
    ModelsList.Add('');

    Try
        Component := Iterator.FirstSchObject;

        While Component <> Nil Do
        Begin
            CompSrcLibName := Component.SourceLibraryName;
            CompDBTable    := Component.DatabaseTableName;
            CompDesignId   := Component.DesignItemId;
            CompLibRef     := Component.LibReference;
            CompSymRef     := Component.SymbolReference;

            SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

            if CurrentSheet.ObjectID = eSheet then
            begin
                Component.SetState_SourceLibraryName('*');
//   fix making SchLib from DbLib sourced components.
                Component.SymbolReference := CompDesignId;
            end;

            if CurrentSheet.ObjectID = eSchLib then
            begin
                Component.SetState_SourceLibraryName('');
//                                                     stop fixing things !
                Component.LibraryPath    := '';    //   := ExtractFileName(CurrentSheet.DocumentName);
                Component.DesignItemId   := CompLibRef;
            end;

            if CurrentSheet.ObjectID = eSheet then
                ModelsList.Add (Component.Designator.Text + ' Comp DesignID : ' + CompDesignId + '   ExCompSrcLib : ' + CompSrcLibName + '   ExSymRef : ' + CompSymRef)
            else
                ModelsList.Add (' Comp LibRef : ' + CompLibRef + '   ExCompSrcLib : ' + CompSrcLibName);

            FPCount := 0;

            ImplIterator := Component.SchIterator_Create;
            ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation));

            Try
                SchImplementation := ImplIterator.FirstSchObject;
                While SchImplementation <> Nil Do
                Begin
                    If SchImplementation.ModelType = cModelType_PCB then
                    Begin
                        Inc(FPCount);
                        SchImplementation.UseComponentLibrary := False;
//      replace libpath
                        ModelDataFile := SchImplementation.DatafileLink[0];
                        if ModelDataFile <> nil then
                            ModelDataFile.Location := '';       // == Any   in FP model dialog

                        ModelsList.Add    ('     Deleted FP model lib path for the link : ' + SchImplementation.ModelName);

                        Inc(FLinkCount);
                    end;
                    SchImplementation := ImplIterator.NextSchObject;
                End;

            Finally
                Component.SchIterator_Destroy(ImplIterator);
            End;

            ModelsList.Add('');
            SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

            Component := Iterator.NextSchObject;
        End;

    Finally
        // Refresh library.
        CurrentSheet.GraphicallyInvalidate;
        CurrentSheet.SchIterator_Destroy(Iterator)
    End;

    SetDocumentDirty(true);
    ModelsList.Insert(0, 'Count of FP Model lib paths removed/deleted : ' + IntToStr(FLinkCount));
    GenerateReport(ModelsList, 'LibPathRemovedFromComps.txt');
    Modelslist.Free;

End;

Procedure RemoveFPModelDataFileLinksFromLibComps;
Var
    CurrentLib         : ISch_Lib;
    Iterator           : ISch_Iterator;
    Component          : ISch_Component;
    ImplIterator       : ISch_Iterator;
    SchImplementation  : ISch_Implementation;
    FPCount            : Integer;
    FLinkCount         : Integer;
    
Begin
    FLinkCount := 0;

    If SchServer = Nil Then Exit;
    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    If (CurrentLib.ObjectID <> eSchLib) Then
    Begin
         ShowError('Operates on SchLib only.');
         Exit;
    End;
//    If PcbServer = Nil then Exit;

    Iterator := CurrentLib.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    dConfirm := ConfirmNoYesWithCaption('Ready to Remove ALL footprint models ','Do you really want to do this ? ');
    if not dconfirm then exit;
    dConfirm := ConfirmNoYesWithCaption('Remove ALL footprint model datafile links from components ','Very sure ? ');
    if not dconfirm then exit;

    Modelslist := TStringList.Create;
    ModelsList.Add    (' All Existing FP models : ' + '  for datafile like removal/deleting. ');
    ModelsList.Add('');

    Try
        Component := Iterator.FirstSchObject;

        While Component <> Nil Do
        Begin
            ModelsList.Add (' Comp LibRef : ' + Component.LibReference);
            FPCount := 0;

            ImplIterator := Component.SchIterator_Create;
            ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation));

            Try
                SchImplementation := ImplIterator.FirstSchObject;
                While SchImplementation <> Nil Do
                Begin
                    If SchImplementation.ModelType = cModelType_PCB then
                    Begin
                        Inc(FPCount);

//      remove all existing footprint models
                        SchImplementation.ClearAllDatafileLinks;
                        ModelsList.Add    ('     Deleted Existing model datafile link : ' + SchImplementation.ModelName);

                        Inc(FLinkCount);
                    End;

                    SchImplementation := ImplIterator.NextSchObject;
                End;
            Finally
                Component.SchIterator_Destroy(ImplIterator);
            End;

            ModelsList.Add('');
//            // Send a system notification that component change in the library.
//            SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

            Component := Iterator.NextSchObject;
        End;

    Finally
        // Refresh library.
        CurrentLib.GraphicallyInvalidate;
        CurrentLib.SchIterator_Destroy(Iterator)
    End;

    SetDocumentDirty(true);
    ModelsList.Insert(0, 'Count of FP Model datafile links removed/deleted : ' + IntToStr(FLinkCount));
    GenerateReport(ModelsList, 'DataFileLinksRemovedFromCompLib.txt');
    Modelslist.Free;

End;

Procedure TotallyWipeoutMyComponentsToSymbols;
var
    CurrentLib : ISch_Lib;
    CmpCnt     : integer;
begin
    If SchServer = Nil Then Exit;
    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    If (CurrentLib.ObjectID <> eSchLib) Then
    Begin
         ShowError('Operates on SchLib only.');
         Exit;
    End;

    dConfirm := ConfirmNoYesWithCaption('Ready to Totally Remove ALL models ','Do you really want to do this ? ');
    if not dconfirm then exit;
    dConfirm := ConfirmNoYesWithCaption('Totally Eliminate/Remove ALL models from components (make into symbols) ','Very sure ? ');
    if not dconfirm then exit;

    Modelslist := TStringList.Create;
    ModelsList.Add    (' All Existing FP : ' + '  for datafile like removal/deleting. ');
    ModelsList.Add('');

    TotalWipeoutComponentsToSymbols(CurrentLib, CmpCnt);

    ModelsList.Insert(0, 'Number processed Cmps : ' + IntToStr(CmpCnt) );
    GenerateReport(ModelsList, 'DataFileLinksRemovedFromCompLib.txt');
    Modelslist.Free;
end;

Procedure TotalWipeoutComponentsToSymbols(const CurrentLib : ISch_Lib,  var CmpCnt : integer);
Var
    Iterator           : ISch_Iterator;
    Component          : ISch_Component;
    ImplIterator       : ISch_Iterator;
    Parameter          : ISch_Parameter;
    ParasList          : TList;
    SchImplementation  : ISch_Implementation;
    OSchImplementation : ISch_Implementation;
    MCount            : Integer;
    FLinkCount         : Integer;
    I                  : integer;

Begin
    MCount    := 0;
    CmpCnt     := 0;
    FLinkCount := 0;

    ModelsList.Add(CurrentLib.DocumentName);

    XParaList := TStringList.Create;
    XParaList.Delimiter := '|';
    XParaList.StrictDelimiter := true;
    XParaList.DelimitedText := IgnoreParas;

    Iterator := CurrentLib.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    Component := Iterator.FirstSchObject;
    While Component <> Nil Do
    Begin
        inc(CmpCnt);
        ModelsList.Add (' Comp LibRef : ' + Component.LibReference);

        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

        Component.ComponentDescription := 'SYM';
        Component.Comment.Text := Component.LibReference;

        ParasList := GetAllSchCompParameters(Component);
        for i := 0 to (ParasList.Count - 1) do
        begin
            Parameter := ParasList.Items(i);
// soft footprint models are just a parameters.
            if Parameter.Name = 'Footprint' then
            if Parameter.Text <> '' then
                inc(MCount);

            if Parameter.Name <> 'Comment' then
            if XParaList.IndexOf(Parameter.Name) > -1 then
            begin
                Parameter.Text := '';
            end else
            begin
            Component.Remove_Parameter(Parameter);
            Component.RemoveSchObject(Parameter);
            CurrentLib.UnRegisterSchObjectFromContainer(Parameter);
            CurrentLib.RemoveSchObject(Parameter);
//            SchServer.DestroySchObject(Parameter);
            end;
        end;
        ParasList.Free;

        ImplIterator := Component.SchIterator_Create;
        ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation, eImplementationMap, eImplementationsList));

        SchImplementation := ImplIterator.FirstSchObject;
        While SchImplementation <> Nil Do
        Begin
            Inc(MCount);

            ParasList := GetAllSchCompParameters(SchImplementation);
            for i := 0 to (ParasList.Count - 1) do
            begin
                Parameter := ParasList.Items(i);
                Parameter.Name;

                SchImplementation.RemoveSchObject(Parameter);
                Component.Remove_Parameter(Parameter);
                CurrentLib.UnRegisterSchObjectFromContainer(Parameter);
                CurrentLib.RemoveSchObject(Parameter);
            end;
            ParasList.Free;

//      remove all existing footprint models
            if SchImplementation.ObjectID = eImplementation then
            begin
               ModelsList.Add    ('     Deleted Existing model datafile link : ' + SchImplementation.ModelName);
               SchImplementation.ClearAllDatafileLinks;
               inc(FLinkCount);
            end;

            OSchImplementation := SchImplementation;
            SchImplementation := ImplIterator.NextSchObject;

// danger this completely removes the models.
            Component.RemoveSchImplementation(OSchImplementation);
            Component.RemoveSchObject(OSchImplementation);
            CurrentLib.UnRegisterSchObjectFromContainer(OSchImplementation);
            CurrentLib.RemoveSchObject(OSchImplementation);
        End;

        OSchImplementation := nil;
        Component.SchIterator_Destroy(ImplIterator);

        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
        Component.GraphicallyInvalidate;
        Component := Iterator.NextSchObject;
    End;

    Component := Iterator.FirstSchObject;
    CurrentLib.SetState_Current_SchComponent(Component);

 //  Refresh library.
    CurrentLib.GraphicallyInvalidate;
    CurrentLib.SchIterator_Destroy(Iterator);
    CurrentLib.UpdateDisplayForCurrentSheet;

    SetDocumentDirty(true);
    ModelsList.Add('Count of FP Model links removed/deleted : ' + IntToStr(FLinkCount) + '   all models : ' + IntToStr(MCount));
    ModelsList.Add('');
    XParaList.Free;
End;

{..............................................................................}
Function GetAllSchCompParameters(const Component : ISch_BasicContainer) : TList;
Var
   PIterator : ISch_Iterator;
   Parameter : ISch_Parameter;
Begin
    Result := TList.Create;
//    Result.OwnsObjects := false;
    PIterator := Component.SchIterator_Create;
    PIterator.AddFilter_ObjectSet(MkSet(eParameter) );
    PIterator.SetState_IterationDepth(eIterateAllLevels);

    Parameter := PIterator.FirstSchObject;
    while Parameter <> Nil Do
    begin
        Result.Add(Parameter);
        Parameter := PIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy( PIterator );
End;
{..............................................................................}
Procedure GenerateReport(Report : TStringList, Filename : WideString);
Var

    ReportDocument : IServerDocument;
    Filepath       : WideString;

Begin
    WS  := GetWorkspace;
    If WS <> Nil Then
    begin
       Prj := WS.DM_FocusedProject;
       Doc := WS.DM_FocusedDocument;

       If Prj <> Nil Then
          Filepath := ExtractFilePath(Prj.DM_ProjectFullPath);   //  Doc.DM_FullPath

//  to get unique report file per SchLib doc..
    //   Filepath := ExtractFilePath(Doc.FullPath) + ChangefileExt(ExtractFileName(Doc.FullPath), '');
    end;

    If length(Filepath) < 5 then Filepath := ExtractFilePath(Doc.DM_FullPath);

    Filepath := Filepath + Filename;

    ModelsList.Insert(0, ExtractFilename(Prj.DM_ProjectFullPath));
    Report.SaveToFile(Filepath);

    ReportDocument := Client.OpenDocument('Text',Filepath);
    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;
end;

Procedure SetDocumentDirty (Dummy : Boolean);
Var
    AView           : IServerDocumentView;
    AServerDocument : IServerDocument;
Begin
    If Client = Nil Then Exit;
    AView := Client.GetCurrentView;
    AServerDocument := AView.OwnerDocument;
    AServerDocument.Modified := True;
End;
{..............................................................................}

