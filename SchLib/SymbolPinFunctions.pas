{ SymbolPinFunctions.pas

  Operates on component symbols in SchDoc & SchLib

Summary
  Transfers existing Pin name info into Functions extension (AD20+)
  AD20+: Loads Pin name & function info from text file.
  AD17-AD19: Loads Pin Names

Trnasfer requires "/" char in Pin.Name before setting functions.

Text File Format:
<tab> delimited.
pin-des<tab>FN1<tab>FN2<LF>

Author BL Miller
 2023-80-09 v0.1 POC
 .................................................................................}

{..............................................................................}
const
    PinFuncFile  = 'PinFunctions.txt';   // not used..
    AD19VersionMajor  = 19;
    AD20VersionMajor  = 20;

Var
    CurrentSheet : ISch_Document;
    PinFuncList  : TStringList;
    Symbolslist  : TStringList;
    IsLib        : boolean;
    VerMajor     : WideString;

procedure ProcessCompPinFunctions(Comp : ISch_Component); forward;
Function GetAllSchCompParameters(const Component : ISch_BasicContainer) : TList; forward;
function GetAllCompPins(Comp : ISch_Component) : TList; forward;
function Version(const dummy : boolean) : TStringList;  forward;
Procedure GenerateReport(Report : TStringList, Filename : WideString);  forward;
Procedure SetDocumentDirty (Dummy : Boolean); forward;


procedure LoadCMPSymbolPinNamesFromFile();
var
    Comp       : ISch_Component;
    Obj        : ISch_GraphicalObject;
    Path       : WideString;
    FileName   : WideString;
    SchLib     : ISch_Lib;
    CmpCnt     : integer;
    Hit          : THitTestResult;
    HitState     : boolean;
    Location     : TLocation;
    I            : integer;

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

    VerMajor := Version(true).Strings(0);

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
    end;

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

    Location := EmptyLocation;

    if not IsLib then
    begin
        HitState := CurrentSheet.ChooseLocationInteractively(Location,'Pick a component ');

        if (HitState) then
        begin
            Hit := CurrentSheet.CreateHitTest(eHitTest_AllObjects, Location);
//       Cursor := HitTestResultToCursor(Hit);

            I := 0;
            while I < Hit.HitTestCount do
            begin
                Obj := Hit.HitObject(I);
                if (Obj.ObjectId = eSchComponent) then
                begin
                    Comp := Obj;
                    ProcessCompPinFunctions(Comp);
                    break;
                end;
                inc(I);
            end;
        end;
    end else
    begin
         Comp := CurrentSheet.CurrentSchComponent;
         ProcessCompPinFunctions(Comp);
    end;
    Comp.GraphicallyInvalidate;

    PinFuncList.Free;

    GenerateReport(SymbolsList, 'LoadPinNameFuncFromFile.txt');
    SymbolsList.Free;
end;

procedure ProcessCompPinFunctions(Comp : ISch_Component);
var
    PinList        : TList;
    Pin            : ISch_Pin;
    PinFuncLine    : TStringList;
    PinNumber      : WideString;
    PinFunc        : WideString;
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
    PinFuncLine.Delimiter := #9;
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

            PinNumber := PinFuncLine.Strings(0);
// comment
            if PinNumber = '#' then continue;
// space no desig.
            if PinNumber = ' ' then continue;

            if PinNumber = Pin.Designator then
            begin
                PinFunc := PinFuncLine.Strings(1);

                for K := 2 to (PinFuncLine.Count - 1) do
                    PinFunc := PinFunc + '/' + PinFuncLine.Strings(K);

                Pin.SetState_Name(PinFunc);

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
Procedure RefreshSymbolFunctionFromName;
Var
    CurrentSheet   : ISch_Document;
    Iterator       : ISch_Iterator;
    Component      : ISch_Component;
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
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

    VerMajor := Version(true).Strings(0);

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

        PinIterator := Component.SchIterator_Create;
        PinIterator.AddFilter_ObjectSet(MkSet(ePin));

        Pin := PinIterator.FirstSchObject;
        While Pin <> Nil Do
        Begin
            If Pin.Name <> '' then
            if (ansipos('/', Pin.Name) > 1) then
            Begin
                if VerMajor >= AD20VersionMajor then
                    Pin.SetState_FunctionsFromName;

                Pin.GraphicallyInvalidate;
                SymbolsList.Add ('  ' + Pin.Designator + '|' + Pin.Name);
            end;
            Pin := PinIterator.NextSchObject;
        End;

        Component.SchIterator_Destroy(PinIterator);

        SymbolsList.Add('');
        SchServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

        Component := Iterator.NextSchObject;
    End;

    // Refresh library.
    CurrentSheet.GraphicallyInvalidate;
    CurrentSheet.SchIterator_Destroy(Iterator);

    SetDocumentDirty(true);
    SymbolsList.Insert(0, 'Count of CMP SYM refreshed : ' + IntToStr(CmpCnt));
    GenerateReport(SymbolsList, 'SYMPinFunctionRefresh.txt');
    Symbolslist.Free;
End;

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

function GetCompPin(Comp : ISch_Component, Designator : Text) : ISch_Pin;
var
    Pin          : ISch_Pin;
    PinIterator  : ISch_Iterator;
begin
    Result := nil;
    PinIterator := Comp.SchIterator_Create;
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    while Pin <> Nil Do
    begin
        if Pin.Designator = Designator then
        begin
            Result := Pin;
            break;
        end;
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
function Version(const dummy : boolean) : TStringList;
begin
    Result               := TStringList.Create;
    Result.Delimiter     := '.';
//    Result.Duplicates    := dupAccept;   // requires .Sort
    Result.DelimitedText := Client.GetProductVersion;
end;
{..............................................................................}

