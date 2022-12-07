{ List all installed AltiumDesigner ..

 HKey_Local_Machine  HKey_Current_User
 Registry.RootKey := HKEY_CURRENT_USER;


BL Miller
26/10/2020  v0.10  POC list Altium Install registry entries..
            v0.11  Added some install Preferences to report
27/10/2020  v0.12  Use Special folder if only project is Free Documents & blank path. CurrentDir is not reliable RW path.
14/08/2022  v0.13  Check paths/folders exist.


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

    cRegistrySubPath  = '\Software\Altium\Builds';        // Machine installs
    cRegistrySubPath2 = '\Software\Altium';               // User prefs
    cRegistrySubPath3 = '\DesignExplorer\Preferences';    // User prefs

// paralist of ItemKeys to report from Software\Altium\Builds\SpecialKey\..
    csItemKeys    = 'Application|Build|Display Name|ProgramsInstallPath|FullBuild|ReleaseDate|DocumentsInstallPath|Security|UniqueID|Version|Win64';
    csReportPaths = 'ProgramsInstallPath|DocumentsInstallPath|Template Path|InstalledRelativePath';
// ..Software\Altium\\SpecialKey\DesignExplorer\Preferences\
    csItemKeys2   = 'WorkspaceManager\Workspace Preferences\Template Path|PcbDrawing\PcbDrawing\DocumentTemplatesLocation|IntegratedLibrary\Add Remove\InstalledRelativePath'
                  + '|AltiumPortal\Account\Username';

var
    Registry         : TRegistry;
    RegDataInfo      : TRegDataInfo;
    SectKeyList      : TStringlist;
    ItemKeyList      : TStringList;
    Report           : TStringList;
    Project          : IProject;
    FilePath         : WideString;
    ReportDocument   : IServerDocument;

function RegistryReadString(const SKey : WideString, const IKey : Widestring) : WideString;    forward;
function RegistryReadSectKeys(const SKey : WideString) : TStringList;                          forward;
function RegistryReadKeyType(const SKey : WideString, const IKey : Widestring) : TRegDataInfo; forward;

procedure ItemPathToSection (var SPath, var KPath : WideString);
var
    pos : integer;
begin
    SPath := SPath + '\' + ExtractFilePath(KPath);
    SPath := RemovePathSeparator(SPath);
    KPath := ExtractFileName(KPath);
end;

procedure ListTheInstalls;
Var
    SectKey    : WideString;
    ItemKey    : WideSting;
    ItemKey2   : WideSting;
    KeyValue   : WideString;
    DirExists  : WideString;
    S, I       : integer;

begin
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
    SectKeyList := RegistryReadSectKeys(SectKey);

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
    ItemKeyList.DelimitedText := csItemKeys2;

    Registry.RootKey := HKEY_CURRENT_USER;

    for S := 0 to (SectKeyList.Count - 1) do
    begin
        SectKey := SectkeyList.Strings(S);
        Report.Add('Section : ' + IntToStr(S) + ' ' + SectKey);
        for I := 0 to (ItemKeyList.Count - 1) do
        begin
            ItemKey := ItemKeyList.Strings(I);
//   don't forget the damn separator '\'
            SectKey := cRegistrySubPath2 + '\' + SectkeyList.Strings(S) + cRegistrySubPath3;
            ItemKey2 := ItemKey;
            ItemPathToSection (SectKey, ItemKey2);
            RegDataInfo := RegistryReadKeyType(SectKey, ItemKey2);
            KeyValue    := RegistryReadString(SectKey, ItemKey2);

            DirExists := '';
            if (ansipos(ItemKey2, csReportpaths) > 0) then
            begin
                DirExists := 'path: NOT found';
                if DirectoryExists(KeyValue) then
                    DirExists := 'path: good';
            end;

            Report.Add(PadRight(IntToStr(S) + '.' + IntToStr(I),4) + ' ' +  ExtractFilePath(ItemKey));
            Report.Add(PadRight(IntToStr(S) + '.' + IntToStr(I),4) + ' ' + PadRight(ItemKey2,30) + ' = ' + PadRight(KeyValue,60) + ' datatype : ' +IntToStr(RegDataInfo) + '  ' + DirExists);
        end;
        Report.Add('');
    end;

    ItemKeyList.Free;

    SectKeyList.Delimiter := #13;
    SectKeyList.Insert(0,'List of installs : ');
//    ShowMessage(SectKeyList.DelimitedText);

    if Registry <> nil then Registry.Free;
    SectKeyList.Free;

    Project := GetWorkSpace.DM_FocusedProject;
    FilePath := ExtractFilePath(Project.DM_ProjectFullPath);
    if (Project.DM_ProjectFullPath = 'Free Documents') or (FilePath = '') then
        FilePath :=  SpecialFolder_AllUserDocuments;   // GetCurrentDir;

    FilePath := FilePath + '\AD_Installs_Report.Txt';
    Report.Insert(0, 'Report Altium Installs in Registry');
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

function RegistryReadSectKeys(const SKey : WideString) : TStringList;
Begin
    Result   := TStringList.Create;
    Registry.OpenKeyReadOnly( SKey );
    Registry.GetKeyNames( Result );
//    Registry.GetValueNames( Result ) ;
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

