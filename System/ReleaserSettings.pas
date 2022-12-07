{ ReleaserSettings.pas ..

 HKey_Local_Machine  HKey_Current_User
 Registry.RootKey := HKEY_CURRENT_USER;

 The .ini import uses registry datatype check before writing.

BL Miller
06/12/2022  v0.10  POC Export Import Releaser Settings registry entries..
07/12/2022  v0.11  Store RegDataInfo in the export ini file & use for import if missing in Registry. 

AD23 is planning to move/store Releaser Settings info inside each Project.

TBD:
  No 32 - 64 bit cross support..
  If run from AD17 then ONLY 32bit registry is checked.
  If run from AD18+ then only 64bit installs are found.

//                                            vv  SpecialKey_SoftwareAltiumApp  vv
// HKEY_LOCAL_MACHINE/Software/Altium/Builds/Altium Designer {Fxxxxxxx-xxxxxxxxxxxxx}/*items
// HKEY_CURRENT_USER/Software/Altium/Altium Designer {Fxxxxxxx-xxxxxxxxxxxxx}/DesignExplorer/Preferences
}

const
{ Reserved Key Handles. missing in DelphiScript}
    HKEY_CLASSES_ROOT     = $80000000;
    HKEY_CURRENT_USER     = $80000001;
    HKEY_LOCAL_MACHINE    = $80000002;
    HKEY_USERS            = $80000003;
    HKEY_PERFORMANCE_DATA = $80000004;
    HKEY_CURRENT_CONFIG   = $80000005;
    HKEY_DYN_DATA         = $80000006;

    cRegistrySubPath3 = 'Project Release';            

// specific keys ..Software\Altium\\SpecialKey\Project Release\
    csItemKeys2    = 'Release Settings';

// export sections
    csSectKeys3    = 'Naming Template';
    csExportPrefix = 'EXP_';
    cFilterFile    = 'ReleaserSettings.ini';
    csRegDataInfo  = '_RegDataInfo';


// Root keynameN to import from ini & writing to registry.
   cStringKeyRoots = 'Naming Template';   // this version only supports a single entry


var
    Registry         : TRegistry;
    RegDataInfo      : TRegDataInfo;
    SectKeyList      : TStringlist;
    SectDataInfo     : TStringList;
    SubSectList      : TStringlist;
    ItemKeyList      : TStringList;
    Report           : TStringList;
    Project          : IProject;
    FilePath         : WideString;
    IniFileName      : WideString;
    Flag             : Integer;
    ReportDocument   : IServerDocument;

function  RegistryReadString  (const SKey : WideString, const IKey : Widestring) : WideString;      forward;
function  RegistryReadInteger (const SKey : WideString, const IKey : Widestring) : WideString;      forward;
function  RegistryReadSectKeys(const SKey : WideString, const ValueNName : boolean) : TStringList;  forward;
function  RegistryReadKeyType (const SKey : WideString, const IKey : Widestring) : TRegDataInfo;    forward;
function  RegistryWriteInteger(const SKey : Widestring, const IKey : WideString, const IVal : Integer) : boolean;    forward;
function  RegistryWriteString (const SKey : Widestring, const IKey : WideString, const IVal : WideString) : boolean; forward;
procedure ItemPathToSection   (var SPath, var KPath : WideString); forward;

procedure ImportReleaserSettings;
Var
    OpenDialog   : TOpenDialog;
    IniFile      : TMemIniFile;            // do NOT use TIniFile for READING as strips quotes at each end!
    I            : integer;
    SectName     : WideString;
    KeyName      : WideString;
    KeyValue     : WideString;
    intValue     : Integer;
    RegSectKey   : WideString;
    RegItemKey   : WideString;
    bSuccess     : boolean;

Begin
    Project := GetWorkSpace.DM_FocusedProject;
    FilePath := ExtractFilePath(Project.DM_ProjectFullPath);
    if (Project.DM_ProjectFullPath = 'Free Documents') or (FilePath = '') then
        FilePath :=  SpecialFolder_MyDocuments;      // SpecialFolder_AllUserDocuments;   // GetCurrentDir;

    OpenDialog            := TOpenDialog.Create(Application);
    OpenDialog.FileName   := cFilterFile;
    OpenDialog.Title      := 'Import ' + cFilterFile + ' file';
    OpenDialog.Filter     := 'INI file (*.ini)|*.ini';
    OpenDialog.InitialDir := FilePath;

    Flag := OpenDialog.Execute;
    if (not Flag ) then exit;
    IniFileName := OpenDialog.FileName;

    IniFile  := TMemIniFile.Create(IniFileName);
    Registry := TRegistry.Create;   // TRegistry.Create(KEY_WRITE OR KEY_WOW64_64KEY);  KEY_SET_VALUE

    SectName := cRegistrySubPath3 + '\' + csItemKeys2 + '\' + cStringKeyRoots;

    SectKeyList := TStringList.Create;
    SectKeyList.Delimiter := '=';
    SectKeyList.StrictDelimiter := true;
//    SectKeyList.NameValueSeparator := '=';

    if IniFile.SectionExists(SectName) then
    begin

        IniFile.ReadSectionValues(SectName, SectKeyList);

        for I := 0 to (SectKeyList.Count - 1) do
        begin
            KeyName  := SectKeyList.Names(I);
            KeyValue := SectKeyList.ValueFromIndex(I);

            RegSectKey := SpecialKey_SoftwareAltiumApp + '\' + SectName;
// determine key type registry
            RegDataInfo := RegistryReadKeyType(RegSectKey, KeyName);

// determine unknown key type from inifile
            if (RegDataInfo = rdUnknown) then
                RegDataInfo := IniFile.ReadInteger(SectName + csRegdataInfo, KeyName, rdUnknown);

// write to Registry
            if (RegDataInfo = rdInteger) then
            begin
                intValue := StrToInt(KeyValue);
                bSuccess := RegistryWriteInteger(RegSectKey, KeyName, IntValue);
            end;
            if (RegDataInfo = rdString) then
                bSuccess := RegistryWriteString(RegSectKey, KeyName, KeyValue);
         end;
    end
    else
        ShowMessage('IniFile does not have this section ' + SectName);

    SectKeyList.Clear;
    if Registry <> nil then Registry.Free;
    IniFile.Free;
End;

procedure ExportReleaserSettings;
Var
    SectKey    : WideString;
    ItemKey    : WideSting;
    KeyValue   : WideString;
    IniFile    : TIniFile;            // do NOT use TIniFile for READING as strips quotes at each end!
    I, J       : integer;

begin

    Project := GetWorkSpace.DM_FocusedProject;
    FilePath := ExtractFilePath(Project.DM_ProjectFullPath);
    if (Project.DM_ProjectFullPath = 'Free Documents') or (FilePath = '') then
        FilePath :=  SpecialFolder_MyDocuments;

    Report := TStringList.Create;
    Registry := TRegistry.Create;   // TRegistry.Create(KEY_WRITE OR KEY_WOW64_64KEY);  KEY_SET_VALUE

    SubSectList := TStringList.Create;
    SubSectList.Delimiter := '|';
    SubSectList.StrictDelimiter := true;
    SubSectList.DelimitedText := csSectKeys3;

    I := 1;
    IniFileName := FilePath + '\' + csExportPrefix + cFilterFile;
    While FileExists(IniFileName) do
    begin
        inc(I);                           //                                                                          incl. '.'
        IniFileName := FilePath + '\' + ExtractFileNameFromPath(csExportPrefix + cFilterFile) + IntToStr(I) + ExtractFileExt(cFilterFile);
    end;

    IniFile := TIniFile.Create(IniFileName);

    SectKey := SpecialKey_SoftwareAltiumApp;
    Report.Add('Export to  : ' + IniFileName);
    Report.Add('Section    : ' + SectKey);

    for I := 0 to (SubSectList.Count - 1) do
    begin
//   don't forget the damn separator '\'
        SectKey := '\' + SpecialKey_SoftwareAltiumApp + '\' + cRegistrySubPath3 + '\' + csItemKeys2 +  '\' + SubSectList.Strings(I);

        ItemKeyList := RegistryReadSectKeys(SectKey, true);

        for J := 0 to (ItemKeyList.Count - 1) do
        begin
            ItemKey := Trim(ItemKeyList.Strings(J));
            ItemPathToSection (SectKey, ItemKey);
            RegDataInfo := RegistryReadKeyType(SectKey, ItemKey);

            if (RegDataInfo = rdInteger) then
            begin
                KeyValue := RegistryReadInteger(SectKey, ItemKey);
                Report.Add('Section : ' + csItemKeys2 + '\' + SubSectList.Strings(I) + ' ' + ItemKey + ' ' + IntToStr(KeyValue) );
            end else
            begin
                KeyValue := RegistryReadString(SectKey, ItemKey);
                Report.Add('Section : ' + csItemKeys2 + '\' + SubSectList.Strings(I) + ' ' + ItemKey + ' ' + KeyValue);
            end;

            IniFile.WriteString(cRegistrySubPath3 + '\' + csItemKeys2 + '\' + SubSectList.Strings(I), ItemKey, KeyValue);
            IniFile.WriteString(cRegistrySubPath3 + '\' + csItemKeys2 + '\' + SubSectList.Strings(I) + csRegDataInfo, ItemKey, RegDataInfo);
        end;
    end;

    ItemKeyList.Free;
    IniFile.Free;

    if Registry <> nil then Registry.Free;

    FilePath := FilePath + '\ReleaserSettings_Report.Txt';
    Report.Insert(0, 'Report Releaser Settings in Registry');
    Report.SaveToFile(FilePath);
    Report.Free;

    ReportDocument := Client.OpenDocument('Text', FilePath);

    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;
end;

function RegistryReadSectKeys(const SKey : WideString, const ValueNName : boolean) : TStringList;
var
    sTemp : TString;
Begin
    sTemp := '';
    Result   := TStringList.Create;
    Registry.OpenKeyReadOnly( SKey );

    if not ValueNName then
        Registry.GetKeyNames( Result )
    else
        Registry.GetValueNames( Result );
//    Result.Delimitedtext := sTemp;
//    libRegistryCKey  := Registry.CurrentKey;
//    libRegistrySPath := Registry.CurrentPath;
//    Registry.HasSubKeys;
    Registry.Closekey;
end;

function RegistryReadString(const SKey : WideString, const IKey : Widestring) : WideString;
Begin
    Result := '';
    Registry.OpenKey(SKey, false);
    if Registry.ValueExists(IKey) then
    begin
        RegDataInfo := Registry.GetDataType(IKey);
        Result := Registry.ReadString(IKey);
    end;
    Registry.CloseKey;
End;

function RegistryReadInteger(const SKey : WideString, const IKey : Widestring) : WideString;
Begin
    Result := 0;
    Registry.OpenKey(SKey, false);
    if Registry.ValueExists(IKey) then
    begin
        RegDataInfo := Registry.GetDataType(IKey);
        Result := Registry.ReadInteger(IKey);
    end;
    Registry.CloseKey;
End;

function RegistryWriteString(const SKey : Widestring, const IKey : WideString, const IVal : WideString) : boolean;
Begin
    Result := false;
    Registry.OpenKey(SKey, true);
    if Registry.ValueExists(IKey) then
        Result := true;
// potentially create Key
    Registry.WriteString(IKey, IVal);
    Registry.CloseKey;
End;

function RegistryWriteInteger(const SKey : Widestring, const IKey : WideString, const IVal : Integer) : boolean;
Begin
    Result := false;
    Registry.OpenKey(SKey, true);
    if Registry.ValueExists(IKey) then
    begin
        Registry.WriteInteger(IKey, IVal);
        Result := true;
    end;
    Registry.CloseKey;
End;

function RegistryReadKeyType(const SKey : WideString, const IKey : Widestring) : TRegDataInfo;
Begin
    Result := rdUnknown;
    Registry.OpenKey(SKey, false);
    if Registry.ValueExists(IKey) then
    begin
        Result := Registry.GetDataType(IKey);
    end;
    Registry.CloseKey;
End;

procedure ItemPathToSection (var SPath, var KPath : WideString);
begin
    SPath := SPath + '\' + ExtractFilePath(KPath);
    SPath := RemovePathSeparator(SPath);
    KPath := ExtractFileName(KPath);
end;


