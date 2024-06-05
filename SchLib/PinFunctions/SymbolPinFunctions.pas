{ SymbolPinFunctions.pas

  Operates on component symbol(s) in SchDoc & SchLib

Summary
ReportOneCMPSymPinFuncs          : one picked or current CMP
   text file report of functions.

RefreshAllSymbolFunctionFromName : All
RefreshOneCMPSymbolPinFunctions  : one picked or current CMP
RefreshOneCMPSymPinFuncsFromDesc : one picked or current CMP
   Transfers existing Pin name (or description) info into Functions extension (AD20+)

LoadCMPSymbolPinNamesFromFile
LoadCMPSymbolPinNamesFromClipBoard
   AD20+: Loads Pin name & function info from text file or clipboard.
   AD17-AD19: Loads Pin Names
   Clipboard text can be comma or <tab> delimited.

CleanAllSymbolPinNames           : All
CleanOneCMPSymbolPinNames        :  one picked or current CMP
   Correct common pin.name format issues
      'FN1_(FN2/FN3)' to 'FN1/FN2/FN3'
      'FN1,FN2,FN3    to 'FN1/FN2/FN3'
      & remove any leading & trailing '/' & <space>

RemoveForwardSlashOneCMPSymbolPinNames
   Correct incorrect use of forward slash in existing names

NegationPADsToAltiumOneCMPSymbolPinNames
   Convert sensible text negation format \PADs\ to clumsy A\l\t\i\u\m\ or \Altium format

Transfer requires '/' char in Pin.Name before setting functions.
User can paste in CSV delimited text & run Clean.. & then Refresh...

Text File Format:
<tab> delimited.
pin-des<tab>FN1<tab>FN2<LF>

 completely blank Pin.Names in Import file replaced with Pin.Des & set hidden.
 empty name fields ignored

Author BL Miller
 2023-80-09 v0.10  POC
 2023-08-09 v0.20  add basic name cleaning for old symbols.
 2023-08-10 v0.21  Separate string processing for AD17-19 (make AD20+ safer); All & single CMP.
 2023-08-11 v0.22  Support Copy/"paste" thru clipboard, Single symbol text processing helper functions
 2023-08-12 v0.23  Support comma or <tab> delimited text in clipboard.
 2023-10-19 v0.24  make PinFuncList local var 
 2024-06-05 v0.24  Report of existing pin functions of Current CMP.

tbd:
 make the final pin name be another separate string in input file (not just all funcs)?
 .............................................................................................

ISch_Pin.ExporttoParamters
 |PINDEFINEDFUNCTIONSCOUNT=3|PINDEFINEDFUNCTION1=PGED1|PINDEFINEDFUNCTION2=AN7


Convert CSV text to slashes & apply as pin functions (single pin clicking).
ScriptingSystem:RunScriptText
Text=Var S,L,H,P,N;Begin S:=SchServer.GetCurrentSchDocument;L:=EmptyLocation;S.ChooseLocationInteractively(L,'Pick a Pin ');H:=S.CreateHitTest(0,L);P:=H.HitObject(0);if P.ObjectID<>ePin then exit;N:=P.Name;N:=ReplaceText(N, ',', '/');if N<>'' then P.SetState_Name(N);P.SetState_FunctionsFromName;end;
.....................................................................................}

const
    PinFuncFile       = 'PinFunctions.txt';   // not used..
    AD19VersionMajor  = 19;
    AD20VersionMajor  = 20;
    cShowReport       = false;       // load show report file
    cCommaToFSlash    = true;        // convert clipboard text commas to forward slash.
    cDescription      = 2;
    cPinName          = 1;
    cPinFuncCount     = 'PINDEFINEDFUNCTIONSCOUNT';      // const names in parameter export & ASCII file
    cPinFuncN         = 'PINDEFINEDFUNCTION';

Var
    CurrentSheet : ISch_Document;
    Symbolslist  : TStringList;
    IsLib        : boolean;
    VerMajor     : integer;

procedure ProcessCompPinFunctions(Comp : ISch_Component, PinFuncList : TStringList); forward;
function PickAComp(const Sheet : ISch_Document, IsLib : boolean) : ISch_GraphicalObject; forward;
Function GetAllSchCompParameters(const Component : ISch_BasicContainer) : TList; forward;
function GetAllCompPins(Comp : ISch_Component) : TList; forward;
function GetPinFunctions(Pin : ISch_Pin) : TStringList; forward;
function ReportCompSymbolPinFunc(Component : ISch_Component) : boolean; forward;
function RefreshCompSymbolPinFunc(Component : ISch_Component, const NameNDesc : integer) : boolean; forward;
function RemoveFSCompSymbolPinNames(Component : ISch_Component) : ISch_Pin; forward;
function NegationChangePTA(Component : ISch_Component) : boolean; forward;
function ImportClipBoard(const dummy : boolean) : TStringList; forward;
function CleanCompSymbolPinNames(Component : ISch_Component) : ISch_Pin; forward;
function FixCompSymbolPinNames(Component : ISch_Component) : boolean;     forward;
function CleanPinName(Name : WideString) : WideString;  forward;
function CleanPinName22(Name : WideString) : WideString;  forward;
function CleanPinName17(Name : WideString) : WideString;  forward;
Procedure GenerateReport(Report : TStringList, Filename : WideString);  forward;
Procedure SetDocumentDirty (const Dummy : Boolean); forward;

procedure ReportOneCMPSymbolPinFunctions;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        SymbolsList.Add ('Report Pin Functions & Pin Names for Comp SYM  : ' + Comp.LibReference);
        ReportCompSymbolPinFunc(Comp);
        Comp.GraphicallyInvalidate;
    end;

    GenerateReport(SymbolsList, 'PinFuncsRep.txt');
    SymbolsList.Free;
end;

procedure LoadCMPSymbolPinNamesFromFile;
var
    Comp        : ISch_Component;
    Path        : WideString;
    FileName    : WideString;
    SchLib      : ISch_Lib;
    PinFuncList : TStringList;
    CmpCnt      : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    FileName := '';
    Path := ExtractFilePath(CurrentSheet.DocumentName) ;
    ResetParameters;
    AddStringParameter('Dialog',    'FileOpenSave');
    AddStringParameter('Mode',      '0');
    AddStringParameter('FileType1', 'Text File (*.txt)|*.txt');
    AddStringParameter('Prompt',    'Select PinName Text file in target folder ');
    AddStringParameter('Path',      Path);
    RunProcess('Client:RunCommonDialog');

    GetStringParameter('Result', Path);
    if Path = 'True' then
    begin
        GetStringParameter('Path',   Path);
        FileName := ExtractFileName(Path);
        Path     := ExtractFilePath(Path);
// Dialog FileSaveOpen Mode 2 & 4 not supported
//        I := 1;
//        repeat
//            GetStringParameter('File'+IntToStr(I),  FileName);
//            LibList.Add(FileName);
//            inc(I);
//        until FileName = '';
    end
    else exit;

    if not FileExists(Path + FileName, false) then
    begin
        ShowMessage('file not found ');
        exit;
    end;

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('Updated Name & Functions for Comp SYM from file : ' + FileName);
    SymbolsList.Add ('');

    PinFuncList := TStringList.Create;
    PinFuncList.Delimiter := #10;
    PinFuncList.StrictDelimiter := true;
    PinFuncList.LoadFromFile(Path + FileName); // ExtractFilePath(SchDoc.DocumentName) + '\' + PinFuncfile);

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        ProcessCompPinFunctions(Comp, PinFuncList);
        Comp.GraphicallyInvalidate;
    end;

    PinFuncList.Free;

    GenerateReport(SymbolsList, 'LoadPinNameFuncFromFile.txt');
    SymbolsList.Free;
end;

procedure LoadCMPSymbolPinNamesFromClipBoard;
var
    Comp        : ISch_Component;
    Path        : WideString;
    FileName    : WideString;
    SchLib      : ISch_Lib;
    PinFuncList : TStringList;
    CmpCnt      : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('Updated Name & Functions for Comp SYM from clipboard : ');
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);
    ShowMessage('Prepare Clipboard ');

    if Comp <> nil then
    begin
        PinFuncList := ImportClipBoard(true);
        ProcessCompPinFunctions(Comp, PinFuncList);
        Comp.GraphicallyInvalidate;
    end;

    PinFuncList.Free;

    GenerateReport(SymbolsList, 'LoadPinNameFuncFromClipboard.txt');
    SymbolsList.Free;
end;

procedure CleanOneCMPSymbolPinNames;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        SymbolsList.Add ('Clean Pin Names for Comp SYM  : ' + Comp.LibReference);
        CleanCompSymbolPinNames(Comp);
        Comp.GraphicallyInvalidate;
    end;

    GenerateReport(SymbolsList, 'CleanCompSymbolPinNames.txt');
    SymbolsList.Free;
end;

procedure FixOneCMPSymbolPinNames;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        SymbolsList.Add ('Fix Pin Names for Comp SYM  : ' + Comp.LibReference);
        FixCompSymbolPinNames(Comp);
        Comp.GraphicallyInvalidate;
    end;

    GenerateReport(SymbolsList, 'FixCompSymbolPinNames.txt');
    SymbolsList.Free;
end;

procedure RemoveForwardSlashOneCMPSymbolPinNames;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        RemoveFSCompSymbolPinNames(Comp);
        Comp.GraphicallyInvalidate;
    end;

    SymbolsList.Free;
end;

procedure NegationPADsToAltiumOneCMPSymbolPinNames;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        NegationChangePTA(Comp);
        Comp.GraphicallyInvalidate;
    end;

    SymbolsList.Free;
end;

procedure RefreshOneCMPSymPinFuncsFromDesc;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        SymbolsList.Add ('Refresh Pin Functions from Pin Desciption for Comp SYM  : ' + Comp.LibReference);
        RefreshCompSymbolPinFunc(Comp, cDescription);
        Comp.GraphicallyInvalidate;
    end;

    GenerateReport(SymbolsList, 'RefreshPinNameFuncNames.txt');
    SymbolsList.Free;
end;

procedure RefreshOneCMPSymbolPinFunctions;
var
    Comp       : ISch_Component;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;

begin
    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;
    IsLib := false;
    If (CurrentSheet.ObjectID = eSchLib) then IsLib := true;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add ('SchDoc/Lib : ' + ExtractFileName(CurrentSheet.DocumentName));
    SymbolsList.Add ('');

    Comp := PickAComp(CurrentSheet, IsLib);

    if Comp <> nil then
    begin
        SymbolsList.Add ('Refresh Pin Functions from Pin Names for Comp SYM  : ' + Comp.LibReference);
        RefreshCompSymbolPinFunc(Comp, cPinName);
        Comp.GraphicallyInvalidate;
    end;

    GenerateReport(SymbolsList, 'RefreshPinNameFuncNames.txt');
    SymbolsList.Free;
end;

Procedure RefreshAllSymbolFunctionFromName;
Var
    CurrentSheet   : ISch_Document;
    Iterator       : ISch_Iterator;
    Component      : ISch_Component;
    CmpCnt         : integer;
    IsLib          : boolean;
    CompSrcLibName : WideString;
    CompDBTable    : WideString;
    CompDesignId   : WideString;
    CompLibRef     : WideString;
    CompSymRef     : WideString;
Begin

    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;

    BeginHourGlass(crHourGlass);
    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add    (' All Comp Symbols: ' + ' refresh function from Name ');
    SymbolsList.Add('');
    CmpCnt :=0;
    IsLib  := false;

    If CurrentSheet.ObjectID = eSchLib Then
    begin
        IsLib := true;
        Iterator := CurrentSheet.SchLibIterator_Create;
    end else
        Iterator := CurrentSheet.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    Component := Iterator.FirstSchObject;
    While Component <> Nil Do
    Begin
        inc(CmpCnt);
        CompSrcLibName := Component.SourceLibraryName;
        CompDBTable    := Component.DatabaseTableName;
        CompDesignId   := Component.DesignItemId;
        CompLibRef     := Component.LibReference;
        CompSymRef     := Component.SymbolReference;

        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

        if not IsLib then
            SymbolsList.Add (Component.Designator.Text + ' Comp DesignID : ' + CompDesignId + '   ExCompSrcLib : ' + CompSrcLibName + '   ExSymRef : ' + CompSymRef)
        else
            SymbolsList.Add (' Comp LibRef : ' + CompLibRef + '   ExCompSrcLib : ' + CompSrcLibName);

        SymbolsList.Add(' Refreshed Func. for Pin Designator & Name');

        RefreshCompSymbolPinFunc(Component, cPinName);

        SymbolsList.Add('');
        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

        Component := Iterator.NextSchObject;
    End;

    // Refresh library.
    CurrentSheet.GraphicallyInvalidate;
    CurrentSheet.SchIterator_Destroy(Iterator);

    SetDocumentDirty(true);
    SymbolsList.Insert(0, 'Count of CMP SYM refreshed : ' + IntToStr(CmpCnt));
    GenerateReport(SymbolsList, 'SYMPinFuncRefresh.txt');
    Symbolslist.Free;
    EndHourGlass;
End;

Procedure CleanAllSymbolPinNames;
Var
    CurrentSheet   : ISch_Document;
    Iterator       : ISch_Iterator;
    Component      : ISch_Component;
    CmpCnt         : integer;
    IsLib          : boolean;
    CompSrcLibName : WideString;
    CompDBTable    : WideString;
    CompDesignId   : WideString;
    CompLibRef     : WideString;
    CompSymRef     : WideString;
Begin

    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;
    If CurrentSheet = Nil Then Exit;

    If (CurrentSheet.ObjectID <> eSchLib) and (CurrentSheet.ObjectID <> eSheet) Then
    Begin
         ShowError('Operates on SchDoc/Lib only.');
         Exit;
    End;

    BeginHourGlass(crHourGlass);
    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    Symbolslist := TStringList.Create;
    SymbolsList.Add    (' All Comp Symbols: ' + ' clean Pin Names ');
    SymbolsList.Add('');
    CmpCnt :=0;
    IsLib  := false;

    If CurrentSheet.ObjectID = eSchLib Then
    begin
        IsLib := true;
        Iterator := CurrentSheet.SchLibIterator_Create;
    end else
        Iterator := CurrentSheet.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    Component := Iterator.FirstSchObject;
    While Component <> Nil Do
    Begin
        inc(CmpCnt);
        CompDesignId   := Component.DesignItemId;
        CompLibRef     := Component.LibReference;

        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

        if not IsLib then
            SymbolsList.Add (Component.Designator.Text + ' Comp DesignID : ' + CompDesignId)
        else
            SymbolsList.Add (' Comp LibRef : ' + CompLibRef);
        SymbolsList.Add(' Cleaned Pin Designator & Old & New Name');

        CleanCompSymbolPinNames(Component);

        SymbolsList.Add('');
        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

        Component := Iterator.NextSchObject;
    End;

    // Refresh library.
    CurrentSheet.GraphicallyInvalidate;
    CurrentSheet.SchIterator_Destroy(Iterator);

    SetDocumentDirty(true);
    SymbolsList.Insert(0, 'Count of CMP SYM pin names cleaned : ' + IntToStr(CmpCnt));
    GenerateReport(SymbolsList, 'SYMPinNameClean.txt');
    Symbolslist.Free;
    EndHourGlass;
End;

{..............................................................................}
function ImportClipBoard(const dummy : boolean) : TStringList;
var
    ClipB         : TClipBoard;
    LI            : integer;
    Line          : WideString;
begin
    Result := TStringList.Create;
    Result.Delimiter := #10;
    Result.StrictDelimiter := true;
    ClipB := TClipboard.Create;
    Result.DelimitedText := ClipB.AsText;
    ClipB.free;

    for LI := 0 to (Result.Count - 1) do
    begin
        Line := Result.Strings(LI);

        if VerMajor >= AD20VersionMajor then
            Line := ReplaceText(Line, ',', #9)
        else
            Line := StringReplace(Line, ',', #9, eReplaceOne);      //eReplaceOne == ALL!

        Result.Strings(LI) := Line;
    end;
end;
{..............................................................................}
function PickAPin(const Sheet : ISch_Document) : ISch_GraphicalObject;
var
    Obj        : ISch_GraphicalObject;
    Hit        : THitTestResult;
    HitState   : boolean;
    Location   : TLocation;
    I          : integer;
begin
    Result := nil;
    Location := EmptyLocation;

    if not IsLib then
    begin
        HitState := Sheet.ChooseLocationInteractively(Location, 'Pick a pin ');
        if (HitState) then
        begin
            Hit := Sheet.CreateHitTest(eHitTest_AllObjects, Location);
//       Cursor := HitTestResultToCursor(Hit);
            I := 0;
            while I < Hit.HitTestCount do
            begin
                Obj := Hit.HitObject(I);
                if (Obj.ObjectId = eSchPin) then
                begin
                    Result := Obj;
                    break;
                end;
                inc(I);
            end;
        end;
    end;
end;

procedure ProcessCompPinFunctions(Comp : ISch_Component, PinFuncList : TStringList );
var
    PinList        : TList;
    Pin            : ISch_Pin;
    PinFuncLine    : TStringList;
    PinNumber      : WideString;
    PinFunc        : WideString;
    AllPinFunc     : WideString;
    OldPinName     : WideString;
    I, J, K        : integer;
    CompSrcLibName : WideString;
    CompDBTable    : WideString;
    CompDesignId   : WideString;
    CompLibRef     : WideString;
    CompSymRef     : WideString;

begin
    CompSrcLibName := Comp.SourceLibraryName;
    CompDBTable    := Comp.DatabaseTableName;
    CompDesignId   := Comp.DesignItemId;
    CompLibRef     := Comp.LibReference;
    CompSymRef     := Comp.SymbolReference;

    PinFuncLine := TStringList.Create;
    PinFuncLine.Delimiter := #9;   // <TAB>
    PinFuncLine.StrictDelimiter := true;

    PinList := GetAllCompPins(Comp);
    SchServer.RobotManager.SendMessage(Comp.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

    if not IsLib then
        SymbolsList.Add (Comp.Designator.Text + ' Comp DesignID : ' + CompDesignId + '   ExCompSrcLib : ' + CompSrcLibName + '   ExSymRef : ' + CompSymRef)
    else
        SymbolsList.Add (' Comp LibRef : ' + CompLibRef + '   ExCompSrcLib : ' + CompSrcLibName);
    SymbolsList.Add(' Refreshed Func. for Pin Designator & Name');

    for I := 0 to (PinList.Count - 1) do
    begin
        Pin := PinList.Items(I);

        for J := 0 to (PinFuncList.Count - 1) do
        begin
            PinFuncLine.DelimitedText := PinFuncList[J];
// blank lines
            If PinFuncLine.Text = '' then continue;

            PinNumber := Trim(PinFuncLine.Strings(0));
            if PinNumber = '' then continue;
// comment
            if PinNumber[1] = '#' then continue;
// space no desig.
            if PinNumber[1] = ' ' then continue;

            if PinNumber = Pin.Designator then
            begin
                AllPinFunc := '';
// trim lead & trail spaces
                for K := 1 to (PinFuncLine.Count - 1) do
                begin
                    PinFunc := Trim(PinFuncLine.Strings(K));
                    if AllPinFunc = '' then
                        AllPinFunc := PinFunc
                    else if PinFunc <> '' then
                        AllPinFunc := AllPinFunc + '/' + PinFunc;
                end;
// set blank as pindes.
                if AllPinFunc = '' then
                begin
                    AllPinFunc := PinNumber;
                    Pin.SetState_ShowName(false);
                end else
                    Pin.SetState_ShowName(true);

                Pin.SetState_Name(AllPinFunc);

                if VerMajor >= AD20VersionMajor then
                    Pin.SetState_FunctionsFromName;

                SymbolsList.Add ('  ' + Pin.Designator + '|' + Pin.Name);

                Pin.GraphicallyInvalidate;
            end;
        end;
    end;

    SchServer.RobotManager.SendMessage(Comp.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
    PinFuncLine.Free;
    PinList.Free;
end;
{..............................................................................}
function ReportCompSymbolPinFunc(Component : ISch_Component) : boolean;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    PinName        : WideString;
    PinDesc        : WideString;
    slFunctions    : TStringList;

begin
    slFunctions := TStringList;

    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        slFunctions := GetPinFunctions(Pin);

        PinName := Pin.GetState_Name;
        PinDesc := Pin.GetState_Description;
        SymbolsList.Add ('  ' + PadRight(Pin.Designator,3) + ' | ' + PadRight(PinName,20) + ' | ' + PadRight(PinDesc,20) + ' |' + slFunctions.DelimitedText);

        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
    slFunctions.Clear;
    slFunctions.Free;
end;
{..............................................................................}
function RefreshCompSymbolPinFunc(Component : ISch_Component, const NameNDesc : integer) : boolean;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    PinName        : WideString;
    PinDesc        : WideString;

begin
    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        PinName := Pin.GetState_Name;
        PinDesc := Pin.GetState_Description;

        if NameNDesc = cPinName then
        If PinName <> '' then
        if (ansipos('/', PinName) > 1) then
        Begin
            PinName := CleanPinName(PinName);

            if VerMajor >= AD20VersionMajor then
            begin
                Pin.SetState_FunctionsFromName;
                Pin.GraphicallyInvalidate;
            end;
            SymbolsList.Add ('  ' + Pin.Designator + ' | ' + PinName + ' | ' + PinDesc);
        end;

        if NameNDesc = cDescription then
        If PinDesc <> '' then
        if (ansipos('/', PinDesc) > 1) then
        Begin
            PinDesc := CleanPinName(PinDesc);

            if VerMajor >= AD20VersionMajor then
            begin
                Pin.SetState_Name(PinDesc);
                Pin.SetState_FunctionsFromName;

                Pin.SetState_Name(PinName);
                Pin.GraphicallyInvalidate;
            end;

            SymbolsList.Add ('  ' + Pin.Designator + ' | ' + PinName + ' | ' + PinDesc);
        end;
        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
// double display
function FixCompSymbolPinNames(Component : ISch_Component) : boolean;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    PinName        : WideString;

begin
    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        PinName := Pin.GetState_Name;
        Pin.SetState_Name(PinName + '/' + PinName);
  //      Pin.DeleteNameFunctions;

        Pin.SetState_FunctionsFromName;
        Pin.SetState_Name(PinName);
        Pin.SetState_FunctionsFromName;
        Pin.DefaultValue := PinName;
        Pin.GraphicallyInvalidate;

        SymbolsList.Add ('  ' + Pin.Designator + ' | ' + PinName );

        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
function CleanCompSymbolPinNames(Component : ISch_Component) : ISch_Pin;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    OldPinName     : WideString;
    PinName        : WideString;
begin
    Result := nil;
    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        OldPinName := Pin.Name;
        PinName    := CleanPinName(OldPinName);

        Pin.SetState_Name(PinName);
        Pin.GraphicallyInvalidate;
        SymbolsList.Add ('  ' + Pin.Designator + '|' + OldPinName + '|' + PinName);

        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
function NegationChangePTA(Component : ISch_Component) : boolean;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    OldPinName     : WideString;
    PinName        : WideString;
    NON            : boolean;
    I, Cnt         : integer;
begin
    Result := false;
    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        OldPinName := Pin.Name;
        PinName := OldPinName;
        Cnt := 0;
        for I := 1 to Length(OldPinName) do
            if OldPinName[I] = '\' then inc(Cnt);

        NON := false;
        if (Cnt > 0) then
        begin
            PinName := '';
            for I := 1 to Length(OldPinName) do
            begin
                if OldPinName[I] = '\' then
                    NON := not (NON)
                else
                begin
                    PinName := PinName + OldPinName[I];
                    if NON then PinName := PinName + '\';
                end;
            end;
        end;

        Pin.SetState_Name(PinName);
        Pin.GraphicallyInvalidate;
        SymbolsList.Add ('  ' + Pin.Designator + '|' + OldPinName + '|' + PinName);

        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
function RemoveFSCompSymbolPinNames(Component : ISch_Component) : ISch_Pin;
var
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    OldPinName     : WideString;
    PinName        : WideString;
begin
    Result := nil;
    PinIterator := Component.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    While Pin <> Nil Do
    Begin
        OldPinName := Pin.Name;
        PinName := StringReplace(OldPinName, '/', '', eReplaceOne);

        Pin.SetState_Name(PinName);
        Pin.GraphicallyInvalidate;

        Pin := PinIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
function PickAComp(const Sheet : ISch_Document, IsLib : boolean) : ISch_GraphicalObject;
var
    Obj        : ISch_GraphicalObject;
    Hit        : THitTestResult;
    HitState   : boolean;
    Location   : TLocation;
    I          : integer;
begin
    Result := nil;
    Location := EmptyLocation;

    if not IsLib then
    begin
        HitState := Sheet.ChooseLocationInteractively(Location, 'Pick a component ');
        if (HitState) then
        begin
            Hit := Sheet.CreateHitTest(eHitTest_AllObjects, Location);
//       Cursor := HitTestResultToCursor(Hit);
            I := 0;
            while I < Hit.HitTestCount do
            begin
                Obj := Hit.HitObject(I);
                if (Obj.ObjectId = eSchComponent) then
                begin
                    Result := Obj;
                    break;
                end;
                inc(I);
            end;
        end;
    end else
    begin
         Result := Sheet.CurrentSchComponent;
    end;
end;
{..............................................................................}
function GetPinFunctions(Pin : ISch_Pin) : TStringList;
var
    slParameters   : TStringList;
    i, j, PCount   : integer;
    Func        : WideString;
begin
    Result := TStringList.Create;
    Result.Delimiter := '|';
    slParameters := TStringList.Create;
    slParameters.Delimiter := '|';
    slParameters.StrictDelimiter := true;
    slParameters.NameValueSeparator := '=';

    slParameters.DelimitedText := Pin.ExportToParameters;
    i := slParameters.IndexOfName(cPinFuncCount);

    if i > -1 then
        PCount := slParameters.ValueFromIndex(i);
    for i := 1 to PCount do
    begin
        Func := '';
        j := slParameters.IndexOfName(cPinFuncN + IntToStr(i));
        if j > 0 then
            Func := slParameters.ValueFromIndex(j);
        if Func <> '' then
            Result.Add(Func);
    end;
    slParameters.Clear;
    slParameters.Free;
end;
{..............................................................................}
function CleanPinName(Name : WideString) : WideString;
begin
    Result := Name;
    if VerMajor >= AD20VersionMajor then
        Result := CleanPinName22(Name)
    else
        Result := CleanPinName17(Name);
end;

function CleanPinName22(Name : WideString) : WideString;
begin
    Result := Name;
// remove lead & trailling space
    Result := Trim(Result);
// ','  --> '/'
    Result := ReplaceText(Result, ',', '/');
// '_(' --> '/'  and ')_' --> '/'
//    Result := ReplaceText(Result, '_(', '/');
//    Result := ReplaceText(Result, ')_', '/');
// '(' --> '/'  and ')' --> '/'
//    Result := ReplaceText(Result, '(', '/');
//    Result := ReplaceText(Result, ')', '/');
// '//' to '/'
    Result := ReplaceText(Result, '///', '/');
    Result := ReplaceText(Result, '//', '/');

    if (ansipos('/', Result) = 1) then
        Result := Copy(Result, 2, 256);
    if AnsiEndsStr('/', Result) then
        Result := Copy(Result, 1, Length(Result) - 1);
end;
{..............................................................................}
function CleanPinName17(Name : WideString) : WideString;
begin
// AD17 does not have TextReplace nor AnsiEndStr
// and AD17 StringReplace eReplaceOne & eReplaceAll are swapped/backwards !!
    Result := Name;
// remove lead & trailling space
    Result := Trim(Result);
// ','  --> '/'
    Result := StringReplace(Result, ',', '/', eReplaceOne);      //eReplaceOne == ALL!
// '_(' --> '/'  and ')_' --> '/'
//    Result := StringReplace(Result, '_(', '/', eReplaceOne);
//    Result := StringReplace(Result, ')_', '/', eReplaceOne);
// '(' --> '/'  and ')' --> '/'
//    Result := StringReplace(Result, '(', '/', eReplaceOne);
//    Result := StringReplace(Result, ')', '/', eReplaceOne);
// '//' to '/'
    Result := StringReplace(Result, '///', '/', eReplaceOne);
    Result := StringReplace(Result, '//' , '/', eReplaceOne);

    if (ansipos('/', Result) = 1) then
        Result := Copy(Result, 2, 256);
    if Result[Length(Result)] = '/' then
        Result := Copy(Result, 1, Length(Result) - 1);
end;
{..............................................................................}
Function GetAllSchCompParameters(const Component : ISch_BasicContainer) : TList;
Var
   PIterator : ISch_Iterator;
   Parameter : ISch_Parameter;
Begin
    Result := TList.Create;
//    Result.OwnsObjects := false;
    PIterator := Component.SchIterator_Create;
    PIterator.AddFilter_ObjectSet(MkSet(eParameter) );
    PIterator.SetState_IterationDepth(eIterateAllLevels);

    Parameter := PIterator.FirstSchObject;
    while Parameter <> Nil Do
    begin
        Result.Add(Parameter);
        Parameter := PIterator.NextSchObject;
    End;
    Component.SchIterator_Destroy( PIterator );
End;
{..............................................................................}
function GetAllCompPins(Comp : ISch_Component) : TList;
var
    Pin          : ISch_Pin;
    PinIterator  : ISch_Iterator;
begin
//    GetState_AllPins(Comp);
    Result := TList.Create;
    PinIterator := Comp.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    while Pin <> Nil Do
    begin
        Result.Add(Pin);
        Pin := PinIterator.NextSchObject;
    end;
    Comp.SchIterator_Destroy(PinIterator);
end;
{..............................................................................}
Procedure GenerateReport(Report : TStringList, Filename : WideString);
Var
    WS             : IWorkspace;
    Prj            : IProject;
    Doc            : IDocument;
    ReportDocument : IServerDocument;
    Filepath       : WideString;

Begin
    WS  := GetWorkspace;
    If WS <> Nil Then
    begin
       Prj := WS.DM_FocusedProject;
       Doc := WS.DM_FocusedDocument;

       If Prj <> Nil Then
          Filepath := ExtractFilePath(Prj.DM_ProjectFullPath);   //  Doc.DM_FullPath

//  to get unique report file per SchLib doc..
    //   Filepath := ExtractFilePath(Doc.FullPath) + ChangefileExt(ExtractFileName(Doc.FullPath), '');
    end;

    If length(Filepath) < 5 then Filepath := ExtractFilePath(Doc.DM_FullPath);

    Filepath := Filepath + Filename;

    Report.Insert(0, ExtractFilename(Prj.DM_ProjectFullPath));
    Report.SaveToFile(Filepath);

    if not cShowReport then exit;
    ReportDocument := Client.OpenDocument('Text',Filepath);
    If ReportDocument <> Nil Then
    begin
        Client.ShowDocument(ReportDocument);
        if (ReportDocument.GetIsShown <> 0 ) then
            ReportDocument.DoFileLoad;
    end;
end;
{..............................................................................}
Procedure SetDocumentDirty (Dummy : Boolean);
Var
    AView           : IServerDocumentView;
    AServerDocument : IServerDocument;
Begin
    If Client = Nil Then Exit;
    AView := Client.GetCurrentView;
    AServerDocument := AView.OwnerDocument;
    AServerDocument.Modified := True;
End;
{..............................................................................}

