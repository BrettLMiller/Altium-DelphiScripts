{ SavePCB_ASCII.pas

   setup to export Protel 2.8. but can export Altium ascii
Author BL Miller

2023-07-22 v0.1 POC copied from existing OJ & PCB export scripts.
2023-07-25 v1.0 workaround annoying duplicate parameters.

Would be nice to use GetState_Parameter & TParameterList methods but these do not allow getting at the duplicates!

AD17:
Something is not right about Parameter string passed to Generate().
  Can have multiple TargetFilename etc, do some have leading space?
  After Outjob save close reopen, duplicates are gone ?
  Parameter is Not properly maintained as ParameterList inside Altium.
  Can NOT pass back all Parameters from Configure() as end up with duplicates (with empty value or space ' ' !
  But need to pass back TargetFileName.

TBD:
add Messages panel support to indicate pass fail.
switch ascii export formats in Configure() ?

Server process:
Process:    PCB:Export
Parameters: Format = HyperLynx | FileName = PCBBoard.PCBDoc
This automatically exports a file called PCBBoard.PCBDoc to the current directory in HyperLynx format.
PROTEL NETLIST, SPECCTRA DESIGN,
DXF, HYPERLINX, IPC, NETLIST, SHAPE,
SELECTED

both these work (save) in script.
    NewServerDoc.DoFileSave('PCB ASCII File(*.PcbDoc)');
    NewServerDoc.DoFileSave('Protel PCB 2.8 ASCII(*.pcb)');

 from Altium SDK info
Schematic Template, Binary and a blank string ""  represent the same Altium Designer file format.
'ASCII'          – ASCII format
'ORCAD'          – ORCAD format
'TEMPLATE'
'BINARY'         – standard binary format
'AUTOCAD DXF'    – DXF format
'AUTOCAD DWG'    – DWG format}
}

const
    cSourceFileNameParameter = 'SourceFileName';
    cSourceFolderParameter   = 'SourceFolder';
    cDefaultOutputFN         = 'Default.Pcb';
    cDebug                   = false;  // true;
var
    Prj          : IProject;
    ParamList    : TSStringList; // TParameterList;
    Report       : TStringList;
    OutputFN     : WideString;
    SourceFolder : WideString;
    TargetPCB    : WideString;
    TargetFolder : WideString;
    TargetPrefix : WideString;
    AddToProject : boolean;

function GetParameterStr(Parameter : WideString) : WideString;    forward;
function SetParameterStr(Parameter : WideString) : WideString;    forward;
function PredictOutputFileNames(Parameter : String) : WideString; forward;
function GetStringListNameValue(const SL : TStringList, const Name : WideString) : TStringList; forward;
function MakeReport (const FN: WideString, const Parameter : Widestring); forward;

// Parameter == TargetFolder=   TargetFileName=    TargetPrefix=   OpenOutputs=(boolean)   AddToProject=(boolean)

procedure Generate(Parameter : String);
var
    NewServerDoc   : IServerDocument;
    OutputFullPath : WideString;
    Success        : integer;  // long bool
begin
    if cDebug then MakeReport('generate.txt', Parameter);

    OutputFN := TargetFolder + PredictOutputFileNames(Parameter);
    OutputFullPath := TargetFolder + OutputFN;

    if PCBServer = nil then Client.StartServer('PCB');

    if not FileExists(SourceFolder + TargetPCB, false) then
    begin
        ShowMessage(TargetPCB + ' file does not exist');
        exit;
    end;
    if ((SourceFolder + TargetPCB) = OutputFullPath) then exit;

// avoid goofy Altium methods that are dangerous unreliable.
    CopyFile(SourceFolder + TargetPCB, OutputFullPath, false);
    NewServerDoc := Client.OpenDocument('PCB', OutputFullPath);
    NewServerDoc.Filename;

// both these work (save)
//    Success := NewServerDoc.DoFileSave('PCB ASCII File(*.PcbDoc)');      // Altium Ascii
// save as Protel Ascii
    Success := NewServerDoc.DoFileSave('Protel PCB 2.8 ASCII(*.pcb)');     // PCB FILE 6 VERSION 2.80

    if Success = -1 then
    if AddToProject then
        Prj.DM_AddSourceDocument(NewServerDoc.Filename);
end;

function Configure(Parameter : String) : WideString;
Var
    Path : String;
begin
    if cDebug then MakeReport('configure.txt', Parameter);

    GetParameterStr(Parameter);
    Path := SourceFolder;

    ResetParameters;
    AddStringParameter('Dialog',    'FileOpenSave');
    AddStringParameter('Mode',      '0');
    AddStringParameter('FileType1', 'PCB File (*.PcbDoc)|*.PcbDoc');
    AddStringParameter('Prompt',    'Select a PcbDoc then click OK');
    AddStringParameter('Path',      Path);
    RunProcess('Client:RunCommonDialog');

    GetStringParameter('Result', Path);
    if Path = 'True' then
    begin
        GetStringParameter('File1',  Path);
        GetStringParameter('Path',   Path);
        SourceFolder := ExtractFilePath(Path);
        TargetPCB    := ExtractFileName(Path);
    end;

    OutputFN     := StringReplace(TargetPCB, 'PcbDoc', 'Pcb',1);

    Result :=                cSourceFileNameParameter + '=' + TargetPCB;
    Result := Result + '|' + cSourceFolderParameter   + '=' + SourceFolder;
// expt extra spaces in name
//    Result := Result + '|' + 'TargetFileName'         + '=' + OutputFN;
//    Result := Result + '|' + ' TargetFileName'         + '=' + OutputFN;
//    Result := Result + '|' + 'TargetFileName '         + '=' + OutputFN;
end;

// OutJob Output Container "Change"
function PredictOutputFileNames(Parameter : String) : WideString;
// return is just a string of filenames delimited by '|'
begin
    if cDebug then MakeReport('predict.txt', Parameter);

    GetParameterStr(Parameter);
    OutputFN := StringReplace(TargetPCB, 'PcbDoc', 'Pcb',1);
    Result := OutputFN;
end;

// parse for key parameters & set vars in this scope.
function GetParameterStr(const Parameter : WideString) : WideString;
var
    Doc       : IDocument;
    sVal      : WideString;
    MatchList : TStringList;
    I         : integer;
begin
    MatchList := TStringList.Create;
    ParamList := TStringList.Create;
    ParamList.Delimiter := '|';
    ParamList.NameValueSeparator := '=';
    ParamList.StrictDelimiter    := true;
    ParamList.DelimitedText      := Parameter;

    Prj := GetWorkspace.DM_FocusedProject;
    Doc := Prj.DM_PrimaryImplementationDocument;
    TargetPCB    := ExtractFilename(Doc.DM_FileName);
    SourceFolder := ExtractFilePath(Prj.DM_ProjectFullPath);
    OutputFN     := StringReplace(TargetPCB, 'PcbDoc', 'Pcb',1);

// source PCB
    if GetState_Parameter(Parameter, cSourceFileNameParameter, sVal) then
        TargetPCB := Trim(sVal);
    if GetState_Parameter(Parameter, cSourceFolderParameter, sVal) then
        SourceFolder := Trim(sVal);

// output target file
// deal to multiples with blank values!
    MatchList := GetStringListNameValue(ParamList, 'TargetFileName');
    for I := 0 to (MatchList.Count - 1) do
    begin
        sVal := Trim(MatchList.Strings(I));
        if sVal <> '' then
        begin
            OutputFN := sVal;
            break;
        end;
    end;

    if GetState_Parameter(Parameter, 'TargetPrefix', sVal) then
        TargetPrefix := Trim(sVal);

    MatchList := GetStringListNameValue(ParamList, 'TargetFolder');
    for I := 0 to (MatchList.Count - 1) do
    begin
        sVal := Trim(MatchList.Strings(I));
        if sVal <> '' then
        begin
            TargetFolder := sVal;
            break;
        end;
    end;

    AddToProject := false;
    if GetState_Parameter(Parameter, 'AddToProject', sVal) then
        AddToProject := (Trim(sVal) = 'True');

    MatchList.Free;
    ParamList.Free;
end;

// direct call method for testing
procedure main;
var
    Doc   : IDocument;
begin
    Prj := GetWorkspace.DM_FocusedProject;
    Doc := Prj.DM_PrimaryImplementationDocument;
    TargetPCB    := ExtractFilename(Doc.DM_FileName);
    SourceFolder := ExtractFilePath(Prj.DM_ProjectFullPath);
    TargetFolder := SourceFolder + 'Script\';
    Generate(cSourceFolderParameter + '=' + SourceFolder + '|' +cSourceFileNameParameter + '=' + TargetPCB + 
             '|TargetFolder=' + TargetFolder + '|TargetFileName=' + cDefaultOutputFN + '| OpenOutputs=false');
end;

function MakeReport (const FN: WideString, const Parameter : Widestring);
begin
    Report := TStringList.Create;
    Report.Delimiter := '|';
//    Report.NameValueSeparator := '=';
    Report.StrictDelimiter := true;
    Report.DelimitedText := Parameter;
    Report.SaveToFile('c:\temp\' + FN);
    Report.Free;
end;

function GetStringListNameValue(const SL : TStringList, const Name : WideString) : TStringList;
var
    sVal : WideString;
    I    : integer;
begin
    Result := TStringList.Create;
    for I := 0 to (SL.Count - 1) do
    begin
        if ParamList.Names(I) = Name then
        begin
            sVal := ParamList.ValuefromIndex(I);
            Result.Add(sVal);
        end;
    end;
end;

// WIP
Function GetOutputFileNameWithExtension(Ext : String) : String;
Begin
    Prj := GetWorkspace.DM_FocusedProject;
    If TargetFolder = '' Then
        TargetFolder := Prj.DM_GetOutputPath;
    If TargetFileName = '' Then
        TargetFN := Prj.DM_ProjectFileName;
    Result := AddSlash(TargetFolder) + TargetPrefix + ChangeFileExt(TargetFN, Ext);
End;


