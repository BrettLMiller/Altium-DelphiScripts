{.............................................................................
 CompRename2.pas   SchLib or SchDoc
   rename component using the "Comment" parameter text.
   Check for a unique name in SchLib is made..
   Breaks the component (symbol) vault connection to allow renaming

 Saves the original comp name to component parameter: "cCompNameParameter"
 Maybe useful for components from A365 (Vault) that originated in local file based libraries..

 Does NOT remove the Model vault links.

 see Sch/CompVaultState.pas for disconnecting Comp & FP models from vault.

 from Altium Summary Demo how to iterate through a schematic library.


Author BL Miller
02/09/2021  v1.0  POC
08/08/2022  v1.1  minor tweak around changing parameter.
09/08/2022  v1.11 support SchDoc & break comp symbol vault link

Note: current focused component (in SchLib) can NOT have its designator properties changed
      using Comp.Designator method. MUST use ISch_Parameter
      Maybe try .SetState_Designator('text')

..............................................................................}
const
    cCompNameParameter  = 'A365_CompLibName';

{..............................................................................}
var
    Document    : IDocument;
    CurrentLib  : ISch_Lib;
    IsLib       : boolean;

Function SchParameterFind( Component : ISch_Component, ParamName : String ) : ISch_Parameter;         forward;
Function SchParameterAdd( Component : ISch_Component, ParamName : String, Value : String ) : Boolean; forward;
Function SchParameterSet( Component : ISch_Component, ParamName : String, Value : String ) : Boolean; forward;
function CheckLibCompName(SchLib : ISch_Lib, const CompName : WideString) : WideString;               forward;
Procedure GenerateReport(Report : TStringList); forward;
{..............................................................................}

{..............................................................................}
Procedure ReNameSchLibPartWithComment;
Var
    LibraryIterator : ISch_Iterator;
    Designator      : ISch_Designator;
    i, j            : integer;
    LibComp         : ISch_Component;
    ReportInfo      : TStringList;
    CompName        : TString;
    DesignItemId    : WideString;
    NewCompName     : TString;
    Comment         : TString;
    NameSuffix      : WideString;

Begin
    If SchServer = Nil Then Exit;

    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    if not ((CurrentLib.ObjectID = eSheet) or (CurrentLib.ObjectID = eSchLib)) Then
    begin
         ShowMessage('No SchDoc or SchLib selected. ');
         Exit;
    end;
    IsLib := false;
    if (CurrentLib.ObjectID = eSchLib) then
        IsLib := true;

    // Create a TStringList object to store data
    ReportInfo := TStringList.Create;
    ReportInfo.Add('');

    i := 1; j := 0;

    if IsLib then
        LibraryIterator := CurrentLib.SchLibIterator_Create
    else
        LibraryIterator := CurrentLib.SchIterator_Create;
    LibraryIterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    LibComp := LibraryIterator.FirstSchObject;
    While LibComp <> Nil Do
    Begin
        DesignItemId := Libcomp.DesignItemId;
        CompName     := DesignItemId;
        if (IsLib) then
            CompName := LibComp.LibReference;

        Designator   := LibComp.GetState_SchDesignator;
        Comment      := LibComp.Comment.Text;

// if from Vault then must break to rename.
        if LibComp.VaultGUID <> '' then
        begin
            LibComp.SetState_VaultGUID('');
            LibComp.Setstate_SourceLibraryName('');
            LibComp.UseLibraryName := false;
        end;

// backup the exisitng Name as a parameter
        SchParameterSet( LibComp, cCompNameParameter, CompName );

        NewCompName := CompName;

// rename compoment with Comment
// blank comments are useless
        if Comment <> '' then
            NewCompName := Comment;

// check new name is unique in SchLib
        NameSuffix := '';
        if IsLib then
        begin
            NewCompName := CheckLibCompName(CurrentLib, NewCompName);
        end;

        if (NewCompName <> CompName) then
        begin
            LibComp.UpdatePart_PreProcess;
            LibComp.SetState_LibReference(NewCompName);
            LibComp.SetState_DesignItemId(NewCompName);
            LibComp.UpdatePart_PostProcess;

            ReportInfo.Add(PadRight(IntToStr(i),3) + ' Existing Name, Ref.Des and Comment : ' + CompName + ' | ' + Designator.Text + ' | ' + Comment + '    New Name :     ' + LibComp.LibReference );
        end
        else
            ReportInfo.Add(PadRight(IntToStr(i),3) + ' Existing Name, Ref.Des and Comment : ' + CompName + ' | ' + Designator.Text + ' | ' + Comment + '    NO Name change ');

        inc(i);
        LibComp := LibraryIterator.NextSchObject;
    End;

    LibComp := LibraryIterator.FirstSchObject;

    CurrentLib.SchIterator_Destroy(LibraryIterator);

    CurrentLib.GraphicallyInvalidate;
    // Set the document dirty.
    Client.GetCurrentView.OwnerDocument.Modified := True;

    if IsLib then
        CurrentLib.UpdateDisplayForCurrentSheet;

    GenerateReport(ReportInfo);
    ReportInfo.Free;
End;
{..............................................................................}
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

Procedure GenerateReport(Report : TStringList);
Var
    Document : IServerDocument;
Begin
    Report.Insert(0,'Schematic Library Part (Re)Name Report  ' + CurrentLib.DocumentName);
    Report.Insert(1,'------------------------------');
    
{    
     FileName := Doc.DM_FileName + '_' + ReportFileSuffix;
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
    Report.SaveToFile(FilePath);
}   
    
    Report.SaveToFile('C:\temp\LibraryPartNameReport.txt');

    Document := Client.OpenDocument('Text','C:\temp\LibraryPartNameReport.txt');
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;

End;
{..............................................................................}
Function SchParameterFind( Component : ISch_Component, ParamName : String ) : ISch_Parameter;
Var
   PIterator : ISch_Iterator;
   Parameter : ISch_Parameter;
Begin
    Result := Nil;
    Try
        // Go through list of parameters
        PIterator := Component.SchIterator_Create;
        PIterator.AddFilter_ObjectSet( MkSet( eParameter ) );

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
    Finally
        Component.SchIterator_Destroy( PIterator );
    End;
End;
{..............................................................................}
// this should work for SchLib & SchDoc.
Function SchParameterAdd( Component : ISch_Component, ParamName : String, Value : String ) : Boolean;
Var
    Parameter : ISch_Parameter;

Begin
    Result := False;
     
//    Parameter      := SchServer.SchObjectFactory( eParameter, eCreate_Default );
    Component.UpdatePart_PreProcess;

    Parameter      := Component.AddSchParameter;
    Parameter.Name := ParamName;
    Parameter.SetState_Text(Value);
    Parameter.OwnerPartId := Component.CurrentPartID;
    Parameter.OwnerPartDisplayMode := Component.DisplayMode;

    if (not IsLib) then
    begin
//        Component.AddSchObject( Parameter );
        SchServer.RobotManager.SendMessage( Component.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, Parameter.I_ObjectAddress );
    end;
    Component.UpdatePart_PostProcess;

    Result := True;
End;

Function SchParameterSet( Component : ISch_Component, ParamName : String, Value : String ) : Boolean;
Var
    Parameter : ISch_Parameter;
Begin
    Result    := False;
    Parameter := SchParameterFind( Component, ParamName );
    if Parameter <> Nil Then
    begin
        Component.UpdatePart_PreProcess;
//        SchServer.RobotManager.SendMessage( Parameter.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData );
        Parameter.SetState_Text(Value);
        Parameter.OwnerPartId := Component.CurrentPartID;
        Parameter.OwnerPartDisplayMode := Component.DisplayMode;
        Component.UpdatePart_PostProcess;
//        SchServer.RobotManager.SendMessage( Parameter.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData );
        Result := True;
    end else
    begin
        Result := SchParameterAdd( Component, ParamName, Value );
    end;
    if Parameter <> Nil Then
    begin
        Parameter.ShowName := False;
        Parameter.IsHidden := false;
        Component.SetState_xSizeySize;
        Component.GraphicallyInvalidate;
    end;    
End;
{..............................................................................}
