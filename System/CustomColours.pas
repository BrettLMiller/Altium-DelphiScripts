{ CustomColours.pas

 3x 8bit colour BGR format

 Works on current running Altium Registry path.
 Export Custom colours from Registry to an ini-file  BGR format.
 Import from an user ini-file to the server preferences in Registry.
 Have to close & re-open Altium to refresh internal Custom Colours.

 User can edit ini file directly to add new colours BGR format.
 Colours stored in ini file as BGR value (3 bytes unsigned) of value: min=0 & max=0xFFFFFF
 Value can be represented as integer or hex string (requires "$" prefix)
 It might support hexstring prefix "0x"

 can use IOptionsReader/Writer or IRegistry interfaces to R/W the registry.
 Both work, both appear to do same thing.
 IRegistry interface not fully utilised.

Note:
 Import loading to server seems pointless as servers can not be made to refresh.

B.L Miller
11/08/2022  v0.11  POC
12/08/2022  v0.12  use hex in inifile to ease RGB readability. Sanitise input values from inifile.
14/08/2022  v0.13  pop up the Colour form dialog
18/08/2022  v0.14  registry path was missing server name.

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

IRegistry              // many parallel functions to OptionReader/Writer but more flexible.
IDocumentOptionsSet    // interesting, but does not seem useful.
}

// Registry paths & special keys.
//                                     vv  SpecialKey_SoftwareAltiumApp  vv
// HKEY_CURRENT_USER/Software/Altium/Altium Designer {FB13163A-xxxxxxxxxxxxx}/DesignExplorer/Preferences

const
    cRegistrySubPath = '\DesignExplorer\Preferences\';            // registry path to prefs from AD-install root.

    cNameOfServer = 'Client';
//    cSectionNamesExport = 'Access|Client Preferences|Options Pages|Custom Colors'; 
    cSectionNamesExport = 'Custom Colors';
    cSectionNamesImport = 'Custom Colors';

var
    SectionNames : TStringList;
    SectKeys     : TStringList;

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

procedure ImportCustomColours;
Var
    OpenDialog : TOpenDialog;
    Reader     : IoptionsReader;
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
                if (IntValue > $FFFFFF) then IntValue := $FFFFFF;

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
    ResetParameters;
    AddStringParameter('Dialog','Color');
//   AddStringParameter('Color', '0');
    RunProcess('Client:RunCommonDialog');
    
// non blocking & no return value then causes DLL crash ???
//    Client.SendMessage('Client:RunCommonDialog', 'Dialog=Color', 512, Client.CurrentView);
// DNW
//    Server.CommandLauncher.LaunchCommand('Client:RunCommonDialog', 'Dialog=Color', 512,Client.CurrentView);

    GetStringParameter('Result', Button);
    if (Button = 'True') then
    begin
        bSuccess := true;
        GetStringParameter('Color',KeyValue);
//        ShowInfo('New color is ' + KeyValue);
    End;
    if not bSuccess then
        ShowMessage('Close & reopen Altium to get new colours, sorry..');
End;

procedure ExportCustomColours;
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

                intValue := 0;
                if Reader.ValueExists(SectName, KeyName) then
                begin
//    registry key value is DWord integer
                    intValue := Reader.ReadInteger(SectName, KeyName, -999991);

//  store with hex prefix to allow storage of hex & decimal integer.
                    AValue := '$' + IntToHex(intValue, 6);  // 6 char = 3x 2 (2 char/byte) unsigned

                    IniFile.WriteString(SectName, KeyName, AValue);
                end;

                Report.Add(IntToStr(I) + ' ' + PadRight(KeyName, 45) + ' = ' + IntToStr(intValue) + ' BGR ' + AValue);
            end;

            IniFile.WriteString('Comment', 'DataFormat', 'BGR 3x 8bit: $hex or int');
            Report.Add('');

    end else
        ShowMessage('section ' + SectName + ' not found');

    Report.Add('Colours stored as 3 bytes BGR');

    Filename := SpecialFolder_TemporarySlash + cNameOfServer + '-CustomColours-ExportReport.txt';
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
