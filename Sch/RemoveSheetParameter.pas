{ RemoveSheetParameter.pas

  Can remove System parameters : need to save close & re-open SchDoc.

  Operates on Project logical documents of cDockind_Sch

  AD22.11 ?? AnnotateCompiled sheets (use of DeviceSheet??) add system para to each Sheet "SheetSymbolDesignator"
  This messes up the correct use & can NOIT be deleted without ascii file edit.

BLM
20240202  v0.10  POC
20240330  v0.11  old AD17 missing better parameter fns. Check for non-project SchDoc.
}
const
    cBadParameter = 'SheetSymbolDesignator';
    cLongBoolTrue = -1;
    cAD17         = 17;

var
    Report         : TStringList;
    VerMajor       : integer;

Function SchParameterGet(SGO : ISch_GraphicalObject, ParamName : String ) : ISch_Parameter; forward;
Function RemoveSheetParameter(CurrentSch : ISch_Sheet, const ParamName : WideString) : boolean; forward;

Procedure IterateTheSheets;
var
    WS             : IWorkspace;
    Prj            : IProject;
    FilePath       : WideString;
    FileName       : WideString;
    ReportDocument : IServerDocument;
    Doc            : IDocument;
    SerDoc         : IServerDocument;
    CurrentSch     : ISch_Document;
    I              : Integer;
    SMess          : WideString;
    bRemoved       : boolean;
    bPrjChange     : boolean;

Begin
    WS  := GetWorkspace;
    If WS = Nil Then Exit;

    Prj := WS.DM_FocusedProject;
    If Prj = Nil Then Exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Report  := TStringList.Create;
    Report.Add('Remove Bad Parameter from Prj SchDocs');
    Report.Add(' bad para: ' + cBadParameter);
    Report.Add('');
    Report.Add(' Project: ' + Prj.DM_ProjectFileName);
    Report.Add('');
    FilePath := ExtractFilePath(Prj.DM_ProjectFullPath);
    bPrjChange := false;

    For I := 0 to (Prj.DM_LogicalDocumentCount - 1) Do
    Begin
        Doc := Prj.DM_LogicalDocuments(I);

        If Doc.DM_DocumentKind = cDocKind_Sch Then
        Begin
            CurrentSch := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
            // if you have not double clicked on Doc/file it is open but not loaded.
            If CurrentSch = Nil Then
                CurrentSch := SchServer.LoadSchDocumentByPath(Doc.DM_FullPath);

            If CurrentSch <> Nil Then
            Begin
                Report.Add('');
                Report.Add('=== Sheet : ' + Doc.DM_FileName + '  =====');
                Report.Add('');

                bRemoved := RemoveSheetParameter(CurrentSch, cBadParameter);
                bPrjChange := bPrjChange or bRemoved;
                CurrentSch.GraphicallyInvalidate;

                if FilePath <> '' then
                if FilePath <> 'FreeDocuments' then
                begin
                    SerDoc := Doc.DM_ServerDocument;
                    if bRemoved then
                        SerDoc.Modified := cLongBoolTrue;
                end;

                Report.Add('');
                Report.Add(' ********** End Sheet ********************* ');

            End;
        End;
    End;

    if FilePath = '' then
    FilePath := ExtractFilePath(Doc.DM_FullPath);
    FileName := FilePath + '\RemoveSheetPara_Report.Txt';
    Report.SaveToFile(FileName);

    if bPrjChange then
        ShowMessage('need to Save, Close the SchDoc.');

    //Prj.DM_AddSourceDocument(FileName);
    ReportDocument := Client.OpenDocument('Text', FileName);
    If ReportDocument <> Nil Then
        Client.ShowDocument(ReportDocument);

End;

function RemoveSheetParameter(CurrentSch : ISch_Sheet, const ParamName : WideString) : boolean;
Var
   Parameter : ISch_Parameter;
Begin
    Result := False;

    if VerMajor > cAD17 then
        Parameter := CurrentSch.GetState_SchParameterByName(ParamName)
    else
        Parameter := SchParameterGet(CurrentSch, ParamName);

    if Parameter <> Nil Then
    Begin
        Result := True;
        Report.Add('IsSystemPara: ' + BoolToStr(Parameter.IsSystemParameter,true) + '   paraname: ' + Parameter.Name);
        if (Parameter.IsSystemParameter) then
        begin
            CurrentSch.RemoveSchObject( Parameter );
            SchServer.DestroySchObject( Parameter );
        end else
            CurrentSch.Remove_Parameter( Parameter );
    End;
end;

Function SchParameterGet(SGO : ISch_GraphicalObject, ParamName : String ) : ISch_Parameter;
Var
   PIterator : ISch_Iterator;
   Parameter : ISch_Parameter;
Begin
    Result := Nil;

    PIterator := SGO.SchIterator_Create;
    PIterator.AddFilter_ObjectSet( MkSet( eParameter ) );
    PIterator.SetState_IterationDepth(eIterateAllLevels);

    Parameter := PIterator.FirstSchObject;
    While Parameter <> Nil Do
    Begin
        If SameString( Parameter.Name, ParamName, False ) Then
        Begin
            Result := Parameter;
            Break;
        End;
        Parameter := PIterator.NextSchObject;
    End;
    SGO.SchIterator_Destroy( PIterator );
End;


