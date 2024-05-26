{ UpdateSheetSymbolFN.pas

  iterate active Prj sheets & find matching SheetSymbol source filenames.
  Replace source filename  Old --> New

  POC: Sheet4.Schdoc --> Sheet5.SchDoc

Author BL Miller
2024-05-27  0.10 POC.
2024-05-27  0.11 Open all Prj SchDocs with sheet symbols first

}

const
    OldSheetName = 'Sheet4.SchDoc';

procedure UpdateSheetSymbolFileName(SchematicDoc : IDocument, const FileNameUpdate : string); forward;

var
    Prj            : IProject;

procedure main;
var
    NewFilePath    : WideString;
    NewFileName    : WideString;
    Doc            : IDocument;
    I              : Integer;

begin
    Prj := GetWorkSpace.DM_FocusedProject;
    If Prj = Nil Then Exit;

    NewFileName := 'Sheet5.SchDoc';

// Compile the project to fetch the connectivity information for the design.
    Prj.DM_Compile;

// open all SchDoc with sheet symbols else ParentSheetSymbolCount is wrong!

    For I := 0 to (Prj.DM_LogicalDocumentCount - 1) Do
    Begin
        Doc := Prj.DM_LogicalDocuments(I);
        If Doc.DM_DocumentKind = cDocKind_Sch Then
        If Doc.DM_SheetSymbolCount > 0 Then
        Begin
            Client.OpenDocumentShowOrHide(cDocKind_Sch, Doc.DM_FullPath , True);
        End;
    End;

    For I := 0 to (Prj.DM_LogicalDocumentCount - 1) Do
    Begin
        Doc := Prj.DM_LogicalDocuments(I);
        If Doc.DM_DocumentKind = cDocKind_Sch Then
        Begin
            If Doc.DM_PartCount = 0 Then
            Begin
                 ShowWarning('This SchDoc: ' + Doc.DM_FileName + ' has no components(Parts)');
                 // continue;
            End;

            NewFilePath := ExtractFilePath(Doc.DM_FullPath) + NewFileName;

            if SameString(Doc.DM_FileName, OldSheetName, false) then
                UpdateSheetSymbolFileName(Doc, NewFileName);   // not Path

        end;
    end;

// rebuild project tree with new SSym file links.
    Prj.DM_Compile;
end;

procedure UpdateSheetSymbolFileName(SchematicDoc : IDocument, const FileNameUpdate : string);
Var
    SchDocFilename    : WideString;
    I,J,ParentSheetCount : Integer;
    FilePath          : Widestring;
    Filename          : WideString;
    ParentDoc         : IDocument;
    ParentSheet       : ISch_Document;
    DMOSheetSYM       : ISheetSymbol;
    SheetSymbol       : ISch_SheetSymbol;
    SSFN              : ISch_SheetFileName;
    ParentIterator    : ISch_Iterator;
    ParentSheetList   : TStringList;

Begin
    ParentSheetCount := SchematicDoc.DM_ParentSheetSymbolCount;
    SchematicDoc.DM_SheetSymbolCount;
    SchDocFilename := SchematicDoc.DM_FileName;

    If (ParentSheetCount = 0) Then exit;

    ParentSheetList := TStringList.Create;
    For I := 0 To (ParentSheetCount - 1) Do
    begin
        DMOSheetSYM := SchematicDoc.DM_ParentSheetSymbols(I);
        FileName := DMOSheetSYM.DM_OwnerDocumentName;
        ParentSheetList.Add(FileName);
    end;

    For I := 0 To (ParentSheetList.Count - 1) Do
    Begin
        FileName  := ParentSheetList[I];
        FilePath  := ExtractFilePath(Prj.DM_ProjectFullPath) + FileName;
        ParentDoc := Prj.DM_GetDocumentFromPath(FilePath);

        ParentSheet := SchServer.GetSchDocumentByPath(FilePath);
        if ParentSheet = Nil then
            ParentSheet := SchServer.LoadSchDocumentByPath(FilePath);
        If ParentSheet = Nil Then continue;

        SchServer.ProcessControl.PreProcess(ParentSheet, '');

        ParentIterator := ParentSheet.SchIterator_Create;
        ParentIterator.AddFilter_ObjectSet(MkSet(eSheetSymbol));
        SheetSymbol := ParentIterator.FirstSchObject;
        While SheetSymbol <> Nil Do
        Begin
//            SheetSymbol.SheetFileName.Text;
//            SheetSymbol.SheetName.Text;
            SSFN := SheetSymbol.GetState_SchSheetFileName;
            If (SchDocFilename = SSFN.Text) Then
                SSFN.SetState_Text(FileNameUpdate);

            SheetSymbol.GraphicallyInvalidate;
            SheetSymbol := ParentIterator.NextSchObject;
        End;

        ParentSheet.SchIterator_Destroy(ParentIterator);
        SchServer.ProcessControl.PostProcess(ParentSheet, '');

        ParentDoc.DM_Compile;

        for J := 0 to (ParentDoc.DM_SheetSymbolCount - 1) do
        begin
            DMOSheetSYM := ParentDoc.DM_SheetSymbols(J);

            If (SchDocFilename = DMOSheetSYM.DM_SheetSymbolFileName) Then
                ShowWarning('new filename did not stick ! ');
//                DMOSheetSYM.DM_SheetSymbolFileName := FileNameUpdate;
        end;

    End;

    ParentSheetList.Free;
    SchematicDoc.DM_Compile;
End;
