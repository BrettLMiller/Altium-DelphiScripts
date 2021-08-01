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

..................................................................................}

{..............................................................................}

Var
    Modelslist  : TStringList;
    IntMan      : IIntegratedLibraryManager;
    WS          : IWorkspace;
    Prj         : IProject;
    Doc         : IDocument;
    dConfirm    : boolean;

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

{..............................................................................}
Procedure RemoveLibraryPathFromSchComps;
Var
    CurrentSheet       : ISch_Document;
    Iterator           : ISch_Iterator;
    Component          : ISch_Component;
    ImplIterator       : ISch_Iterator;
    SchImplementation  : ISch_Implementation;
    MatchFPMImpl       : ISch_Implementation;
    ModelDataFile      : ISch_ModelDatafileLink;
    CompSrcLibName     : WideString;
    CompDBTable        : WideString;
    CompDesignId       : WideString;
    CompLibRef         : WideString;
    CompSymRef         : WideString;

    FPCount            : Integer;
    FLinkCount         : Integer;
    FPDeleted          : Boolean;

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
    ModelsList.Add    (' Matching All Existing FP : ' + '  for libpath removal/deleting. ');
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

                        ModelsList.Add    ('     Deleted FP model lib path link for : ' + SchImplementation.ModelName);

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
    MatchFPMImpl       : ISch_Implementation;
    ModelDataFile      : ISch_ModelDatafileLink;
    MatchOldFP         : Boolean;
    FPCount            : Integer;
    FLinkCount         : Integer;
    FPDeleted          : Boolean;

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
    dConfirm := ConfirmNoYesWithCaption('Remove ALL footprint models from components ','Very sure ? ');
    if not dconfirm then exit;

    Modelslist := TStringList.Create;
    ModelsList.Add    (' Matching All Existing FP : ' + '  for datafile like removal/deleting. ');
    ModelsList.Add('');
    
    Try
        Component := Iterator.FirstSchObject;

        While Component <> Nil Do
        Begin
            ModelsList.Add (' Comp LibRef : ' + Component.LibReference);
            MatchOldFP := False;
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
                        MatchFPMImpl := SchImplementation;
                        MatchFPMImpl.ClearAllDatafileLinks;
                        ModelsList.Add    ('     Deleted Existing model datafile link : ' + MatchFPMImpl.ModelName);

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


