{ PCBLayerOrder.pas

 
 Works on current running Altium Registry path.
 Export AdvPCB server settings from Registry to an ini-file
 Import from an user ini-file to the server preferences in Registry.

 If this is run before opening ANY PcbDoc then do not have to restart. 

 May have to close & re-open Altium to refresh Layer drawing order.
 
 can use IOptionsReader/Writer or IRegistry interfaces to R/W the registry.
 Both work, both appear to do same thing.
 IRegistry interface not fully utilised.

Note:
 Import loading to server seems pointless as servers can not be made to refresh.

B.L Miller
19/08/2022  v0.11  POC

IOptionsWriter methods              IOptionsWriter properties
   EraseSection
   WriteBoolean
   WriteDouble
   WriteInteger
   WriteString

IOptionsReader methods              IOptionsReader properties
   ReadBoolean
   ReadDouble
   ReadInteger
   ReadString
   ReadSection
   SectionExists
   ValueExists

IOptionsManager methods             IOptionsManager properties
   GetOptionsReader
   GetOptionsWriter
   OptionsExist

MAJOR weakness with above is determining the correct data type. Big problem!

IRegistry              // many parallel functions to OptionReader/Writer but more flexible.
IDocumentOptionsSet    // interesting, but does not seem useful.
}

// Registry paths & special keys.
//                                     vv  SpecialKey_SoftwareAltiumApp  vv
// HKEY_CURRENT_USER/Software/Altium/Altium Designer {FB13163A-xxxxxxxxxxxxx}/DesignExplorer/Preferences

const
    cRegistrySubPath = '\DesignExplorer\Preferences\';            // registry path to prefs from AD-install root.

    cNameOfServer = 'AdvPCB';
//    cSectionNamesExport = 'SystemOptions|BoardReportOptions|ReportOptions'; 
    cSectionNamesExport = 'SystemOptions';
    cSectionNamesImport = 'SystemOptions';
    cKeyPatterns        = 'LayerDrawingOrder';     // subset of pattern matched Keys to process.  integer

var
    SectionNames : TStringList;
    SectKeys     : TStringList;
    KeyPatterns  : TStringList;

    Report       : TStringList;
    ReportDoc    : IServerDocument;
    AValue       : WideString;
    Flag         : Integer;
    Filename     : WideString;
    ViewState    : WideString;

function RegistryWriteString(const SKey : Widestring, const IKey : WideString, const IVal : WideString) : boolean;
var
    Registry : TRegistry;
Begin
    Result := false;
    Registry := TRegistry.Create;
    Try
        Registry.OpenKey(SKey, true);
        if Registry.ValueExists(IKey) then
            Result := true;   // Registry.ReadString(IKey);
        // rdString
        Registry.WriteString(IKey, IVal);
        Registry.CloseKey;

    Finally
        Registry.Free;
    End;
End;

function RegistryWriteInteger(const SKey : Widestring, const IKey : WideString, const IVal : Integer) : boolean;
var
    Registry    : TRegistry;
    RegDataInfo : TRegDataInfo;
Begin
    Result := false;
    Registry := TRegistry.Create;
    Try
        Registry.OpenKey(SKey, true);
        if Registry.ValueExists(IKey) then
        begin
            RegDataInfo := Registry.GetDataType(IKey);
            if RegDataInfo = rdInteger then   
            begin
                Registry.WriteInteger(IKey, IVal);
                Result := true;
            end;
        end;
        Registry.CloseKey;
    Finally
        Registry.Free;
    End;
End;

procedure ImportLayerOrder;
Var
    OpenDialog : TOpenDialog;
    Reader     : IOptionsReader;
    Writer     : IOptionsWriter;
    IniFile    : TMemIniFile;            // do NOT use TIniFile for READING as strips quotes at each end!
    I          : integer;
    OptionsMan     : IOptionsManager;
    SectName       : WideString;
    KeyName        : WideString;
    KeyValue       : WideString;
    intValue       : Integer;
    RegSectKey     : WideString;
    RegItemKey     : WideString;
    Button         : WideString;
    bSuccess       : boolean;

Begin
    OptionsMan := Client.OptionsManager;

    Writer := OptionsMan.GetOptionsWriter(cNameOfServer);
    Reader := OptionsMan.GetOptionsReader(cNameOfServer,'');

    If (Writer = nil) or (Reader = nil) Then
    begin
//        ShowMessage('no options found ');
        Exit;
    end;

    OpenDialog        := TOpenDialog.Create(Application);
    OpenDialog.Title  := 'Import ' + cNameOfServer + '_' + cSectionNamesImport + ' *.ini file';
    OpenDialog.Filter := 'INI file (*.ini)|*.ini';
//    OpenDialog.InitialDir := ExtractFilePath(Board.FileName);
    OpenDialog.FileName := cNameOfServer + '_' + cSectionNamesImport + '*.ini';
    Flag := OpenDialog.Execute;
    if (Flag = 0) then exit;
    FileName := OpenDialog.FileName;
    IniFile := TMemIniFile.Create(FileName);

    SectName := cSectionNamesImport;

    SectKeys := TStringList.Create;
    SectKeys.Delimiter := '=';
    SectKeys.StrictDelimiter := true;
//    SectKeys.NameValueSeparator := '=';

    if OptionsMan.OptionsExist(cNameOfServer,'') then
    begin
        Client.ArePreferencesReadOnly(cNameOfserver, SectName);

        if IniFile.SectionExists(SectName) then
        if Reader.SectionExists(SectName) then
        begin
            IniFile.ReadSectionValues(SectName, SectKeys);

            for I := 0 to (SectKeys.Count - 1) do
            begin
                KeyName := SectKeys.Names(I);
                KeyValue := SectKeys.ValueFromIndex(I);

// hex or int string to int & sanitise
                if KeyValue = ''        then KeyValue :='0';
                intValue := StrToInt(KeyValue);
                if (IntValue < 0)       then IntValue := 0;
//                if (IntValue > $FFFFFF) then IntValue := $FFFFFF;

// write to Server Options
                Writer.WriteInteger(SectName, KeyName, IntValue);
// write to Registry
                RegSectKey := SpecialKey_SoftwareAltiumApp + cRegistrySubPath + cNameOfServer + '\' + SectName;
                bSuccess := RegistryWriteInteger(RegSectKey, KeyName, IntValue);
            end;
        end
        else
            ShowMessage('server does not have this section ' + SectName);

        SectKeys.Clear;
    end;

    Reader := nil;
    Writer := nil;
    IniFile.Free;

    client.SetPreferencesChanged(true);
    Client.GUIManager.UpdateInterfaceState;

    bSuccess := false;
    if not bSuccess then
        ShowMessage('Close & reopen Altium to get layer order, sorry..');
End;

procedure ExportLayerOrder;
Var
//    FileName   : String;
    SaveDialog : TSaveDialog;
    Reader     : IOptionsReader;      // TRegistryReader
    Reader2    : IOptionsReader;
    IniFile    : TIniFile;            // do NOT use TIniFile for READING as strips quotes at each end!
    SectName   : WideString;
    I, J       : integer;
    KeyName    : WideString;
    dblValue   : TExtended;
    intValue   : Integer;
    Datatype   : Widestring;
    Match : boolean;

Begin
    Reader := Client.OptionsManager.GetOptionsReader(cNameOfServer, '');

    If Reader = Nil Then
    begin
        ShowMessage('no options found ');
        Exit;
    end;

    SaveDialog        := TSaveDialog.Create(Application);
    SaveDialog.Title  := 'Export ' + cNameOfServer + '_' + cSectionNamesExport + ' *.ini file';
    SaveDialog.Filter := 'INI file (*.ini)|*.ini';
    FileName := cNameOfServer + '_' + cSectionNamesExport + '.ini';
    SaveDialog.FileName := FileName;

    Flag := SaveDialog.Execute;
    if (Flag = 0) then exit;

    Report   := TStringList.Create;

    // Get file & set extension
    FileName := SaveDialog.FileName;
    FileName := ChangeFileExt(FileName, '.ini');
    IniFile := TIniFile.Create(FileName);

    SectName := cSectionNamesExport;     // load from const

    SectKeys := TStringList.Create;
    SectKeys.Delimiter := #13;
    SectKeys.StrictDelimiter := true;
//    SectKeys.NameValueSeparator := '=';

    KeyPatterns := TStringList.Create;
    KeyPatterns.Delimiter := '|';
    KeyPatterns.StrictDelimiter := true;
    KeyPatterns.DelimitedText := cKeyPatterns;

    Filename := '';
    ReportDoc := nil;
    Report.Add(SpecialKey_SoftwareAltiumApp);
    Report.Add(cNameOfServer);

    if Reader.SectionExists(SectName) then
    begin
            AValue := Reader.ReadSection(SectName);
            SectKeys.DelimitedText := AValue;
            Report.Add(SectName + '  option count : ' + IntToStr(SectKeys.Count));

            for I := 0 to (SectKeys.Count - 1) do
            begin
                KeyName := trim(SectKeys.Strings(I));     // need to trim to find it!

                Match := false;
                for J := 0 to (KeyPatterns.Count - 1) do
                begin
                    if (ansipos(KeyPatterns.Strings(J), KeyName) > 0) then
                        Match := true;
                end;
                if not Match then continue;

                intValue := 0;
                if Reader.ValueExists(SectName, KeyName) then
                begin
//    registry key value is DWord integer
                    intValue := Reader.ReadInteger(SectName, KeyName, 0);

                    IniFile.WriteInteger(SectName, KeyName, intValue);
                end;

                Report.Add(IntToStr(I) + ' ' + PadRight(KeyName, 45) + ' = ' + IntToStr(intValue) );
            end;

//            IniFile.WriteString('Comment', 'DataFormat', 'int');
            Report.Add('');

    end else
        ShowMessage('section ' + SectName + ' not found');

    Filename := SpecialFolder_TemporarySlash + cNameOfServer + '-PCBLayerOrder-ExportReport.txt';
    Report.SaveToFile(Filename);

    SectKeys.Free;
    Report.Free;
    IniFile.Free;

    if FileName <> '' then
        ReportDoc := Client.OpenDocument('Text', FileName);
    If ReportDoc <> Nil Then
    begin
        Client.ShowDocument(ReportDoc);
        if (ReportDoc.GetIsShown <> 0 ) then
            ReportDoc.DoFileLoad;
    end;
end;

