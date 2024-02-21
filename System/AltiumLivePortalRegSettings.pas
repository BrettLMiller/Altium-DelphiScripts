{ AltiumLivePortalRegSeyttings.pas

 Works on current running Altium Registry path.

B.L Miller
2024-02-22  v0.10  POC

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

}

const
    cRegistrySubPath = '\DesignExplorer\Preferences\';            // registry path to prefs from AD-install root.

    cNameOfServer = 'AltiumPortal';
//    cSectionNamesExport = 'Access|Client Preferences|Options Pages|Custom Colors';
    cSectionNamesExport = 'Account';
    cSectionNamesImport = 'Account';

// only supports string!
    cImportKeys = 'Username=Mickey Mouse';  // |RememberUsername=1';

var
    OptionsMan   : IOptionsManager;
    SectionNames : TStringList;
    SectKeys     : TStringList;
    Report       : TStringList;
    ReportDoc    : IServerDocument;
    AValue       : WideString;
    Flag         : Integer;
    Filename     : WideString;
    ViewState    : WideString;

function RegistryWriteString(const SKey : Widestring, const IKey : WideString, const IVal : WideString) : boolean; forward;

procedure ReportRegistrySettings;
Var
    Reader     : IOptionsReader;
    SectName   : WideString;
    I, J       : integer;
    KeyName    : WideString;
    strValue   : WideString;

Begin
    OptionsMan := Client.OptionsManager;
    if OptionsMan = nil then exit;
    Reader := OptionsMan.GetOptionsReader(cNameOfServer, '');

    If Reader = Nil Then
    begin
        ShowMessage('no options found ');
        Exit;
    end;

    Report   := TStringList.Create;

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

                strValue := '';
                if Reader.ValueExists(SectName, KeyName) then
                begin
                    strValue := Reader.ReadString(SectName, KeyName, '');
                end;

                Report.Add(IntToStr(I) + ' ' + PadRight(KeyName, 45) + ' = ' + strValue );
            end;
            Report.Add('');

    end else
        ShowMessage('section ' + SectName + ' not found');

    Report.Add('');

    Filename := SpecialFolder_TemporarySlash + cNameOfServer + '-RegRpt.txt';
    Report.SaveToFile(Filename);

    SectKeys.Free;
    Report.Free;

    if FileName <> '' then
        ReportDoc := Client.OpenDocument('Text', FileName);
    If ReportDoc <> Nil Then
    begin
        Client.ShowDocument(ReportDoc);
        if (ReportDoc.GetIsShown <> 0 ) then
            ReportDoc.DoFileLoad;
    end;
end;

procedure WriteRegistrySetting;
var
    Writer     : IOptionsWriter;
    Reader     : IOptionsReader;
    SectName   : WideString;
    RegSectKey : WideString;
    I          : integer;
    KeyName    : WideString;
    KeyValue   : WideString;
    strValue   : WideString;
    bSuccess   : boolean;

begin
    OptionsMan := Client.OptionsManager;
    if OptionsMan = nil then exit;
    Reader := OptionsMan.GetOptionsReader(cNameOfServer, '');
    Writer := OptionsMan.GetOptionsWriter(cNameOfServer);

    If (Writer = nil) or (Reader = nil) Then
    begin
//        ShowMessage('no options found ');
        Exit;
    end;


    SectName := cSectionNamesImport;

    SectKeys := TStringList.Create;
    SectKeys.Delimiter := '|';
    SectKeys.StrictDelimiter := true;
    SectKeys.NameValueSeparator := '=';
    SectKeys.DelimitedText := cImportKeys;

    if OptionsMan.OptionsExist(cNameOfServer,'') then
    begin
        Client.ArePreferencesReadOnly(cNameOfserver, SectName);

        if Reader.SectionExists(SectName) then
        begin
//            IniFile.ReadSectionValues(SectName, SectKeys);

            for I := 0 to (SectKeys.Count - 1) do
            begin
                KeyName := SectKeys.Names(I);
                KeyValue := SectKeys.ValueFromIndex(I);

                strValue := Reader.ReadString(SectName, KeyName, '');

// write to Server Options
                Writer.WriteString(SectName, KeyName, KeyValue);
// write to Registry
                RegSectKey := SpecialKey_SoftwareAltiumApp + cRegistrySubPath + cNameOfServer + '\' + SectName;
                bSuccess := RegistryWriteString(RegSectKey, KeyName, KeyValue);

                if bSuccess then
                if KeyValue <> strValue then
                    Showmessage('changed ' + KeyName + ' from: ' + strValue +'  to: ' + KeyValue);
            end;
        end
        else
            ShowMessage('server does not have this section ' + SectName);

        SectKeys.Clear;
    end;

    Reader := nil;
    Writer := nil;
//    IniFile.Free;

    client.SetPreferencesChanged(true);
end;

function RegistryWriteString(const SKey : Widestring, const IKey : WideString, const IVal : WideString) : boolean;
var
    Registry    : TRegistry;
    RegDataInfo : TRegDataInfo;
Begin
    Result := false;
    Registry := TRegistry.Create;

    Registry.OpenKey(SKey, true);
    if Registry.ValueExists(IKey) then
    begin
        RegDataInfo := Registry.GetDataType(IKey);
        if RegDataInfo = rdString then
        begin
            Result := true;
            Registry.WriteString(IKey, IVal);
        end;
    end;
    Registry.CloseKey;
    Registry.Free;
End;

