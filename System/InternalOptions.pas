{ InternalOptions.pas

 List all Internal Options for each/all installed AD...
  Internal Options == System Advanced Preferences settings.

 Reports all system Internal Options that are NOT set default.

 Creates an INI file per AD install with ALL Internal Options (System Advanced)


BL Miller
2024-06-07  v0.10  POC from 2020 OptionIO & InstallSummary

TBD:
  No 32 - 64 bit cross support..
  If run from AD17 then ONLY 32bit registry is checked.
  If run from AD18+ then only 64bit installs are found.

HKey_Local_Machine  HKey_Current_User
Registry.RootKey := HKEY_CURRENT_USER;

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

    cRegistrySubPath  = '\Software\Altium\Builds';        // Machine installs
    cRegistrySubPath2 = '\Software\Altium';               // User prefs
    cRegistrySubPath3 = '\DesignExplorer\Preferences';    // User prefs

// paralist of ItemKeys to report from Software\Altium\Builds\SpecialKey\..
    csItemKeys    = 'Application|Build|Display Name|ProgramsInstallPath|FullBuild|ReleaseDate|DocumentsInstallPath|Security|UniqueID|Version|Win64';
    csReportPaths = 'ProgramsInstallPath|DocumentsInstallPath|Template Path|InstalledRelativePath';

// specific keys ..Software\Altium\SpecialKey\DesignExplorer\Preferences\
    csItemKeys3   = 'InternalOptions';

// export 
    cFilterFile    = '_SysIntOpts.ini';
   
var
    Registry         : TRegistry;
    RegDataInfo      : TRegDataInfo;
    SectKeyList      : TStringlist;
    SubSectList      : TStringlist;
    ItemKeyList      : TStringList;
    Report           : TStringList;
    Project          : IProject;
    FilePath         : WideString;
    ReportDocument   : IServerDocument;

function RegistryReadString(const SKey : WideString, const IKey : Widestring) : WideString;       forward;
function RegistryReadInteger(const SKey : WideString, const IKey : Widestring) : WideString;      forward;
function RegistryReadSectKeys(const SKey : WideString, const ValueNName : boolean) : TStringList; forward;
function RegistryReadKeyType(const SKey : WideString, const IKey : Widestring) : TRegDataInfo;    forward;

procedure ItemPathToSection (var SPath, var KPath : WideString);
var
    pos : integer;
begin
    SPath := SPath + '\' + ExtractFilePath(KPath);
    SPath := RemovePathSeparator(SPath);
    KPath := ExtractFileName(KPath);
end;

procedure ListInternalOptions;
Var
    SectKey    : WideString;
    SectKey2   : WideString;
    ItemKey    : WideSting;
    ItemKey2   : WideSting;
    KeyValue   : WideString;
    DirExists  : WideString;
    IniFile    : TIniFile;            // do NOT use TIniFile for READING as strips quotes at each end!
    S, I, J    : integer;
    Desc         : WideString;
    Value        : WideString;
    DefaultValue : WideString;

begin

    Project := GetWorkSpace.DM_FocusedProject;
    FilePath := ExtractFilePath(Project.DM_ProjectFullPath);
    if (Project.DM_ProjectFullPath = 'Free Documents') or (FilePath = '') then
        FilePath :=  SpecialFolder_AllUserDocuments;   // GetCurrentDir;

    Report := TStringList.Create;

    Registry := TRegistry.Create;   // TRegistry.Create(KEY_WRITE OR KEY_WOW64_64KEY);  KEY_SET_VALUE

    ItemKeyList := TStringList.Create;
    ItemKeyList.Delimiter := '|';
    ItemKeyList.StrictDelimiter := true;
    ItemKeyList.DelimitedText := csItemKeys;

    Registry.RootKey := HKEY_LOCAL_MACHINE;
//    Registry.CurrentPath := HKEY_Root;           // read only

//  do NOT include the RootKey Path
    SectKey := cRegistrySubPath;
    SectKeyList := RegistryReadSectKeys(SectKey, false);

    for S := 0 to (SectKeyList.Count - 1) do
    begin
        SectKey := SectkeyList.Strings(S);
        Report.Add('Section : ' + IntToStr(S) + ' ' + SectKey);
        for I := 0 to (ItemKeyList.Count - 1) do
        begin
            ItemKey := ItemKeyList.Strings(I);

//   don't forget the damn separator '\'
            RegDataInfo := RegistryReadKeyType(cRegistrySubPath + '\' + SectKey, ItemKey);
// should check & handle other datatypes..
            KeyValue    := RegistryReadString(cRegistrySubPath + '\' + SectKey, ItemKey);

            DirExists := '';
            if (ansipos(ItemKey, csReportpaths) > 0) then
            begin
                DirExists := 'path: NOT found';
                if DirectoryExists(KeyValue) then
                    DirExists := 'path: good';
            end;

            Report.Add(PadRight(IntToStr(S) + '.' + IntToStr(I),4) + ' ' + PadRight(ItemKey,30) + ' = ' + PadRight(KeyValue,60) + ' datatype : ' +IntToStr(RegDataInfo) + '  ' + DirExists);
        end;
        Report.Add('');
    end;

    ItemKeyList.Clear;

// export the selected options from each install
    SubSectList := TStringList.Create;

    Registry.RootKey := HKEY_CURRENT_USER;

    for S := 0 to (SectKeyList.Count - 1) do
    begin
        SectKey := SectKeyList.Strings(S);
        Report.Add('Install Section : ' + IntToStr(S) + ' ' + SectKey);


//  get section keys (folders) for this install
        SectKey2 := cRegistrySubPath2 + '\' + SectKey + cRegistrySubPath3 + '\' +  csItemKeys3;
        SubSectList := RegistryReadSectKeys(SectKey2, false);

        IniFile := TIniFile.Create(FilePath + '\' + SectKey + cFilterFile);


        for I := 0 to (SubSectList.Count - 1) do    // ItemKeyList.Count - 1) do
        begin
//   don't forget the damn separator '\'
            SectKey2 := cRegistrySubPath2 + '\' + SectKey + cRegistrySubPath3 + '\' + csItemKeys3 + '\' + SubSectList.Strings(I);

            ItemKeyList := RegistryReadSectKeys(SectKey2, true);

            for J := 0 to (ItemKeyList.Count - 1) do
            begin
                ItemKey2 := Trim(ItemKeyList.Strings(J));
                ItemPathToSection (SectKey2, ItemKey2);
                RegDataInfo := RegistryReadKeyType(SectKey2, ItemKey2);

                if RegDataInfo = rdInteger then
                    KeyValue := RegistryReadInteger(SectKey2, ItemKey2)
                else
                    KeyValue := RegistryReadString(SectKey2, ItemKey2);

                IniFile.WriteString(SubSectList.Strings(I), ItemKey2, KeyValue);
            end;

            RegDataInfo := RegistryReadKeyType(SectKey2, 'DefaultValue');
            if RegDataInfo = rdInteger then
                DefaultValue := IntToStr(RegistryReadInteger(SectKey2, 'DefaultValue'))
            else
                DefaultValue := RegistryReadString(SectKey2, 'DefaultValue');
            RegDataInfo := RegistryReadKeyType(SectKey2, 'Value');
            if RegDataInfo = rdInteger then
                Value := IntToStr(RegistryReadInteger(SectKey2, 'Value'))
            else
                Value := RegistryReadString(SectKey2, 'Value');

            Desc     := RegistryReadString(SectKey2,  'Description');

            if Value <> DefaultValue then
                Report.Add( SubSectList.Strings(I) + '  value:' + Value + '   desc:' +Desc);

        end;

        Report.Add('');
        IniFile.UpdateFile;
        IniFile.Free;
    end;

    ItemKeyList.Free;

//    SectKeyList.Delimiter := #13;
//    SectKeyList.Insert(0,'List of installs : ');
//    ShowMessage(SectKeyList.DelimitedText);

    if Registry <> nil then Registry.Free;
    SectKeyList.Free;

    FilePath := FilePath + '\AD_SysIntOpts_Rep1.Txt';
    Report.Insert(0, 'Report Altium System Internal Options (Advanced Prefs) in Registry');
    Report.SaveToFile(FilePath);
    Report.Free;

    //Prj.DM_AddSourceDocument(FilePath);
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
    Registry.HasSubKeys;
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

