{.............................................................................
 SchLib CompRename2.pas
   rename component using the "Comment" parameter text.
   Simple check for a unique name is made..

 Saves the original comp name to component parameter: "cCompNameParameter"
 Maybe useful for components from A365 (Vault) that originated in local file based libraries..

 see Sch/CompVaultState.pas for disconnecting Comp & FP models from vault.

 from Altium Summary Demo how to iterate through a schematic library.


Author BL Miller
02/09/2021  v1.0 POC
08/08/2022  v1.1 minor tweak around changing parameter.

Note: current focused component (in SchLib) can NOT have its designator properties changed
      using Comp.Designator method. MUST use ISch_Parameter
      Maybe try .SetState_Designator('text')

..............................................................................}
const
    cCompNameParameter  = 'A365_CompLibName';

{..............................................................................}
var
    CurrentLib      : ISch_Lib;

Function SchParameterFind( Component : ISch_Component, ParamName : String ) : ISch_Parameter;         forward;
Function SchParameterAdd( Component : ISch_Component, ParamName : String, Value : String ) : Boolean; forward;
Function SchParameterSet( Component : ISch_Component, ParamName : String, Value : String ) : Boolean; forward;
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
    NewCompName     : TString;
    Comment         : TString;
    NameList        : TStringList;
    NameSuffix      : WideString;
    
Begin
    If SchServer = Nil Then Exit;
    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    // check if the document is a schematic library and if not exit.
    If CurrentLib.ObjectID <> eSchLib Then
    Begin
         ShowError('Please open a schematic library.');
         Exit;
    End;

    // Create a TStringList object to store data
    ReportInfo := TStringList.Create;
    ReportInfo.Add('');
    
    NameList := TStringList.Create;
        
    i := 1; j := 0;

    LibraryIterator := CurrentLib.SchLibIterator_Create;
    LibraryIterator.AddFilter_ObjectSet(MkSet(eSchComponent));
    LibComp := LibraryIterator.FirstSchObject;

    While LibComp <> Nil Do
    Begin
        CompName   := LibComp.LibReference;
        Designator := LibComp.GetState_SchDesignator;
        Comment    := LibComp.Comment.Text;
        
// backup the exisitng Name as a parameter
        SchParameterSet( LibComp, cCompNameParameter, CompName );

// rename compoment with Comment
        NewCompName := Comment;
        
// blank comments are useless
        if NewCompName = '' then
            NewCompName := CompName;   

// check new name is unique        
        NameSuffix := '';
        while (NameList.IndexOf(NewCompName + NameSuffix) > -1) do
        begin
            inc(j);
            NameSuffix := '_' + IntToStr(j);
            if J > 100 then break;
        end;

        NewCompName := NewCompName + NameSuffix;
        NameList.Add(NewCompName);

        if (NewCompName <> CompName) then
        begin
            SchServer.RobotManager.SendMessage(LibComp.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);
            LibComp.SetState_LibReference(NewCompName);
            LibComp.SetState_DesignItemId(NewCompName);
            ReportInfo.Add(PadRight(IntToStr(i),3) + ' Existing Name, Ref.Des and Comment : ' + CompName + ' | ' + Designator.Text + ' | ' + Comment + '    New Name (unique):     ' + LibComp.LibReference );
         // Send a system notification that component change in the library.
            SchServer.RobotManager.SendMessage(LibComp.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
        end
        else    
            ReportInfo.Add(PadRight(IntToStr(i),3) + ' Existing Name, Ref.Des and Comment : ' + CompName + ' | ' + Designator.Text + ' | ' + Comment + '    NO Name change '); 

        inc(i);
        LibComp := LibraryIterator.NextSchObject;
    End;

    // we are finished fetching symbols of the current library.
    CurrentLib.SchIterator_Destroy(LibraryIterator);

    CurrentLib.UpdateDisplayForCurrentSheet;
    CurrentLib.GraphicallyInvalidate;
    // Set the document dirty.
    Client.GetCurrentView.OwnerDocument.Modified := True;

    NameList.Clear;

    GenerateReport(ReportInfo);
    ReportInfo.Free;
End;
{..............................................................................}
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

//  if in SchDoc
//    Component.AddSchObject( Parameter );
//    SchServer.RobotManager.SendMessage( Component.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, Parameter.I_ObjectAddress );

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
