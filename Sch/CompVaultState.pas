{ CompVaultState.pas

   Reports the Vault & other revision status properties of Sch component
   If CMP is selected then display pop-up ShowMessage()

   Can blank the VaultGUID from component & the models;
   This disconnects the component from Vault

see SchLib/CompRename2.pas for using Comment as new Libreference

BL Miller.

20/08/2021  v0.10 from RevState.pas
21/08/2021  v0.11 Add DisconnectCompFromVault() strips VaultGUID from the comp & models
2023-06-17  v0.12 no code change, clean out private comments/notes.
}

const
    bDisplay      = true;
    cPopup        = false;

var
    WS            : IWorkspace;
    Prj           : IProject;
    CurrentSheet  : ISch_Document;
    ReportInfo    : TStringList;

Procedure GenerateReport(Filename : WideString); forward;

procedure RevisionStateSch;
var
    CurrentDoc    : IDocument;
    Document      : IServerDocument;
    FileName      : WideString;

    Component     : ISch_Component;
    SchImpl       : ISch_Implementation;
    Iterator      : ISch_Iterator;
    ImplIterator  : ISch_Iterator;
    PIterator     : ISch_Iterator;
    Parameter     : ISch_Parameter;

    CompName      : TString;
    Comment       : WideString;
    Designator    : ISch_Designator;
    SourceLibName : WideString;
    IsInteg       : boolean;
    IsVault       : boolean;
    UseLibName    : boolean;

    SymRef        : WideString;
    SymItemGUID   : WideString;
    SymRevGUID    : WideString;
    SymVaultGUID  : WideString;

    ItemGUID      : WideString;
    RevStatus     : WideString;
    RevState      : WideString;
    RevDetails    : WideString;
    RevGUID       : WideString;
    RevHRID       : WideString;

    VaultGUID     : WideString;
    VaultHRID     : WideString;

    ModelName      : WideString;
    ModelItemGUID  : WideString;
    ModelVaultGUID : Widestring;

    found         : boolean;
    Popup         : boolean;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;

    // check if the document is a schematic Doc and if not exit.
    If not( (CurrentSheet.ObjectID = eSchLib) or (CurrentSheet.ObjectID = eSheet) ) Then
    Begin
         ShowError('Please open a schematic SchDoc.');
         Exit;
    End;

    if CurrentSheet.ObjectID = eSheet then
        Iterator := CurrentSheet.SchIterator_Create;
    if CurrentSheet.ObjectID = eSchLib then
        Iterator := CurrentSheet.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    // Create a TStringList object to store data
    ReportInfo := TStringList.Create;
    ReportInfo.Add(CurrentSheet.DocumentName);
    ReportInfo.Add('');
    ReportInfo.Add( 'Comp Details    Designator   CompName   Comment    SourceLib    UseLibName?   Integ?= ');

    Component := Iterator.FirstSchObject;
    While Component <> Nil Do
    Begin
        Popup := cPopup;
        if (Component.Selection = true) then           ISCH_Designator.
            Popup := true;

        if CurrentSheet.ObjectID = eSchLib then
            CompName := Component.LibReference
        else
            CompName := Component.DesignItemId;

        Designator := Component.Designator;
        Comment := Component.Comment.Text;

        SourceLibName  := Component.SourceLibraryName;
//        IsVault := Component.IsVaultComponent;
        IsInteg    := Component.IsIntegratedComponent;
        UseLibName := Component.UseLibraryName;

    //    SourceDBLibName := Component.DatabaseLibraryName;
    //    DBTableName     := Component.DatabaseTableName;
    //    Component.UseDBTableName := True;

        ReportInfo.Add( 'Comp Details ' + Designator.Text + ' ' +  CompName + ' ' + Comment + '  SourceLib ' + SourceLibName + ' : UseLibName=' + IntToStr(UseLibName) + '  Integ?=' + IntToStr(IsInteg) + '  ' );

        SymRef       := Component.SymbolReference;
        SymItemGUID  := Component.SymbolItemGUID;
        SymRevGUID   := Component.SymbolRevisionGUID;
        SymVaultGUID := Component.SymbolVaultGUID;
        if (Popup) then
            ShowMessage('Symbol Details ' + SymRef + '  GUID=' + SymItemGUID + '  RevGUID=' + SymRevGUID + '  VGUID='  + SymVaultGUID);
        ReportInfo.Add( 'Symbol Details ' + SymRef + '  GUID=' + SymItemGUID + '  RevGUID=' + SymRevGUID + '  VGUID='  + SymVaultGUID);

        ItemGUID   := Component.ItemGUID;    // widestring
        RevDetails := Component.RevisionDetails;   // description
        RevStatus  := Component.RevisionStatus;
        RevState   := Component.RevisionState;     // as listed in Explorer
        RevHRID    := Component.RevisionHRID;      // library Revision ID
        RevGUID    := Component.RevisionGUID;      //
        if (Popup) then
            ShowMessage('Comp Details  ItemGUID=' + ItemGUID + '  Rev' + RevDetails + '  Sts' + RevStatus + '  State' + RevState + '  RevHRID='  + RevHRID + '  RevGUID=' + RevGUID );
        ReportInfo.Add( 'Comp Details  ItemGUID=' + ItemGUID + '  Rev' + RevDetails + '  Sts' + RevStatus + '  State' + RevState + '  RevHRID='  + RevHRID + '  RevGUID=' + RevGUID );

        VaultGUID  := Component.VaultGUID;
        VaultHRID  := Component.VaultHRID;
        if (Popup) then
            ShowMessage('Vault Details  GUID=' + VaultGUID + '   HRID=' + VaultHRID );
        ReportInfo.Add( 'Vault Details  GUID=' + VaultGUID + '   HRID=' + VaultHRID );


        ImplIterator := Component.SchIterator_Create;
        ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation));
        SchImpl := ImplIterator.FirstSchObject;

        While SchImpl <> Nil Do
        Begin
            ModelName      := SchImpl.ModelName;
            ModelItemGUID  := SchImpl.ModelItemGUID;
            ModelVaultGUID := SchImpl.ModelVaultGUID;

            SchImpl.GetState_DatabaseModel;
            SchImpl.GetState_IntegratedModel;

            ReportInfo.Add(' Model detail  Name: ' + SchImpl.ModelName + '   Type : ' + SchImpl.ModelType +  '  old VaultGUID=' + ModelVaultGUID);

            SchImpl := ImplIterator.NextSchObject;
        end;
        Component.SchIterator_Destroy(ImplIterator);

        Component := Iterator.NextSchObject;
        ReportInfo.Add('');
    End;

    CurrentSheet.SchIterator_Destroy(Iterator);
// bizzarely CurrentLib.SchLibIterator_Destroy(Iterator) does not exist.

    ReportInfo.Insert(0,'SchDoc/Lib Comp Revision GUID Report');
    ReportInfo.Insert(1,'------------------------------');
    GenerateReport('SchRevReport.txt');

    ReportInfo.Free;
end;

procedure DisconnectCompFromVault;
var
    Component     : ISch_Component;
    SchImpl       : ISch_Implementation;
    Iterator      : ISch_Iterator;
    ImplIterator  : ISch_Iterator;

    CompName      : TString;
    SourceLibName : WideString;

    ItemGUID      : WideString;
    VaultGUID     : WideString;
    VaultHRID     : WideString;

    ModelName      : WideString;
    ModelItemGUID  : WideString;
    ModelVaultGUID : Widestring;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    if CurrentSheet = Nil then exit;

    // check if the document is a schematic Doc and if not exit.
    If not( (CurrentSheet.ObjectID = eSchLib) or (CurrentSheet.ObjectID = eSheet) ) Then
    Begin
         ShowError('Please open a schematic SchDoc.');
         Exit;
    End;

    if CurrentSheet.ObjectID = eSheet then
        Iterator := CurrentSheet.SchIterator_Create;
    if CurrentSheet.ObjectID = eSchLib then
        Iterator := CurrentSheet.SchLibIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    // Create a TStringList object to store data
    ReportInfo := TStringList.Create;
    ReportInfo.Add(CurrentSheet.DocumentName);
    ReportInfo.Add('');

    Component := Iterator.FirstSchObject;
    While Component <> Nil Do
    Begin

        if CurrentSheet.ObjectID = eSchLib then
            CompName := Component.LibReference
        else
            CompName := Component.DesignItemId;

        ItemGUID   := Component.ItemGUID;
        VaultGUID  := Component.VaultGUID;
        VaultHRID  := Component.VaultHRID;

        ReportInfo.Add('Comp details '+ CompName + '  ItemGUID=' + ItemGUID + ' previous  VaultGUID=' + VaultGUID + '   HRID=' + VaultHRID );

        Component.SetState_VaultGUID('');
        Component.Setstate_SourceLibraryName('');

        ImplIterator := Component.SchIterator_Create;
        ImplIterator.AddFilter_ObjectSet(MkSet(eImplementation));
        SchImpl := ImplIterator.FirstSchObject;

        While SchImpl <> Nil Do
        Begin
            ModelName      := SchImpl.ModelName;
            ModelItemGUID  := SchImpl.ModelItemGUID;
            ModelVaultGUID := SchImpl.ModelVaultGUID;

            SchImpl.GetState_DatabaseModel;
            SchImpl.GetState_IntegratedModel;

            ReportInfo.Add(' Model detail  Name: ' + SchImpl.ModelName + '   Type : ' + SchImpl.ModelType +  '  old VaultGUID=' + ModelVaultGUID);

            SchImpl.SetState_ModelVaultGUID('');

            SchImpl := ImplIterator.NextSchObject;
        end;
        Component.SchIterator_Destroy(ImplIterator);

        Component := Iterator.NextSchObject;
        ReportInfo.Add('');
    End;
    CurrentSheet.SchIterator_Destroy(Iterator);

    ReportInfo.Insert(0,'SchDoc/Lib Comp Disconnect Vault Report');
    ReportInfo.Insert(1,'------------------------------');
    GenerateReport('SchCompVaultReport.txt');
    ReportInfo.Free;
end;

Procedure GenerateReport(Filename : WideString);
Var
    Document    : IServerDocument;
    Filepath    : WideString;
    UsedPaths   : TStringList;

Begin
    WS  := GetWorkspace;
    If WS <> Nil Then
    begin
       Filepath := ExtractFilePath(WS.DM_FocusedDocument.DM_FullPath);
       Prj := WS.DM_FocusedProject;
       If Prj <> Nil Then
          Filepath := ExtractFilePath(Prj.DM_ProjectFullPath);
    end;

    If length(Filepath) < 5 then Filepath := 'c:\temp\';

    UsedPaths := TStringList.Create;
    UsedPaths.Add(FilePath);

    Filepath := Filepath + Filename;
    
    GetNextUniqueFileName(FilePath,UsedPaths);

    ReportInfo.SaveToFile(Filepath);

    Document := Client.OpenDocument('Text',Filepath);
    if bDisplay and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

