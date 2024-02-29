{ NoNetWires.pas
  from NetLister PrjScr

use with SchDoc free or in board project

find & report wires that have no net assigned. i.e. unconnected to any NetItem with intrinsic Net

2024-02-29  1.13  patch TList workaround to still work in AD17

...............................................................................}
{..............................................................................}
Const
    cDebug        = false;
    display       = true;          // load/show report files
    cSchNoNetName = 'N00000';
    cLegacyList   = 17;

Var
    WS           : IWorkspace;
    MMessage     : WideString;
    MMObjAddr    : Integer;
    NetsData     : TStringList;
    NetList      : TList;            // TStringList.Objects() bad in AD23 SchServer.
    NetMatchList : TList;
    Version      : Integer;
    SUnit        : TUnit;

Function ObjectIDToString ( I : Integer) : WideString; forward;
Procedure GenerateReport(Report : TStringList, Filename : WideString); forward;
function FetchNetsFromProject(AProject : IProject, ADoc : IDocument) : TList; forward;
Function GetItems(CurrentSch : ISch_Document, const ObjSet : TSet) : TList; forward;
function MatchNetOfNetObj(NetObj : ISch_GraphicalObject, var ANetItem : INetItem) : INet; forward;
{..............................................................................}

// Problem: eWire has no Net property but eLine is not selected from clicking a net
procedure ListLooseWires();
var
    Project     : IProject;
    Doc         : IDocument;
    CurrentSch  : ISch_Document;
    SchObj      : ISch_GraphicalObject;
    Loc         : TLocation;
    ANet        : INet;
    ANetItem    : INetItem;
    NetName     : WideString;
    ObjIDString : String;
    I           : Integer;
    WireList    : TList;
    NetCount    : integer;

begin
    BeginHourGlass;

    // Check if schematic server exists or not.
    If SchServer = Nil Then Exit;
    WS  := GetWorkspace;
    If WS = Nil Then Exit;
    Doc := WS.DM_FocusedDocument;
    If Doc.DM_DocumentKind <> cDocKind_Sch Then Exit;
    If SchServer = Nil Then Exit;
    CurrentSch := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
    If CurrentSch = Nil Then
        CurrentSch := SchServer.LoadSchDocumentByPath(Doc.DM_FullPath);
    If CurrentSch = Nil Then Exit;
    SUnit := CurrentSch.DisplayUnit;
    Version := GetBuildNumberPart(Client.GetProductVersion, 0);

    Project := GetDXPProjectOfDocument(Doc.DM_FullPath);
//    Project := Sch_GetOwnerProject(CurrentSch);
    if Project.DM_ObjectKindString <> cObjectKindString_BoardProject then Project := nil;

// do a compile so the logical documents get expanded into physical documents.
    if Project <> nil then
        Project.DM_Compile
    else
        Doc.DM_ScrapCompile(-1);

    NetsData := TStringList.Create;
    NetList  := FetchNetsFromProject(Project, Doc);
    NetCount := NetList.Count;
    WireList := GetItems(CurrentSch, MkSet(eWire));

    for I := 0 to (WireList.Count - 1) do
    begin
        if Version > cLegacyList then
            SchObj := WireList.Items(I)
        else
            SchObj := WireList.Objects(I);

        Loc      := SchObj.Location;
        ANetItem := nil;
        ANet     := MatchNetOfNetObj(SchObj, ANetItem);

        NetName := cSchNoNetName;
        if (ANet <> nil) then
            NetName := ANet.DM_NetName;

        if (NetName = cSchNoNetName) then
        begin
            NetName := '<no net name>';
            NetsData.Add(NetName + '  ' + SchObj.GetState_DescriptionString + GetDisplayStringFromLocation(Loc, SUnit)
                         + '  ' + ANetItem.DM_LongDescriptorString);
        end;

        if cDebug then
            ShowMessage (NetName + '  ' + SchObj.GetState_DescriptionString + GetDisplayStringFromLocation(Loc, SUnit)
                         + '  ' + ANetItem.DM_ObjectKindString + '  ' + ANetItem.DM_LongDescriptorString);
    end;

    NetsData.Insert(0,'Schematic Nets Report');
    NetsData.Insert(1,CurrentSch.DocumentName + '  Net Count:' + IntToStr(NetCount));
    NetsData.Insert(2,'Loose Wires / No net assigned');
    NetsData.Insert(3,'------------------------------');
    GenerateReport(NetsData, 'NetLooseWireRpt.txt');
    NetsData.Free;

    WireList.Clear;
    WireList.Free;
    NetList.Clear;
    NetList.Free;   //TList.Destroy
    EndHourGlass;
end;
{..............................................................................}

Function GetItems(CurrentSch : ISch_Document, const ObjSet : TSet) : TList;
Var
    Iterator     : ISch_Iterator;
    SchObj       : ISch_GraphicalObject;

Begin
    if Version > cLegacyList then
        Result := TList.Create
    else
        Result := TStringList.Create;

    Iterator := CurrentSch.SchIterator_Create;
    // Problem: eWire has no Net property but eLine is not selected from clicking a net
    Iterator.AddFilter_ObjectSet(ObjSet);
    SchObj := Iterator.FirstSchObject;
    While (SchObj <> Nil) Do
    Begin
        if Version > cLegacyList then
            Result.Add(SchObj)
        else
            Result.AddObject(SchObj.GetState_DescriptionString, SchObj);

        SchObj := Iterator.NextSchObject;
    End;
    CurrentSch.SchIterator_Destroy(Iterator);
End;

function FetchNetsFromProject(AProject : IProject, ADoc : IDocument) : TList;
Var
    I,J         : Integer;
    Doc         : IDocument;
    ANet         : INet;

Begin
    if Version > cLegacyList then
        Result := TList.Create
    else
        Result := TStringList.Create;

    If AProject <> Nil Then
    begin
//   obtain the physical document thats the same as the focussed document
//   need the physical document for net information...

        For I := 0 to (AProject.DM_PhysicalDocumentCount - 1) Do
        Begin
            Doc := AProject.DM_PhysicalDocuments(I);
            if ADoc <> nil then
            if not SameString(ADoc.DM_FileName, Doc.DM_Filename, false) then
                continue;

            For J := 0 to (Doc.DM_NetCount - 1) Do
            Begin
                ANet := Doc.DM_Nets(J);
                if Version > cLegacyList then
                    Result.Add(ANet)
                else
                    Result.AddObject(ANet.DM_NetName, ANet);
            End;
       End;
    end else
    begin
        For J := 0 to (ADoc.DM_NetCount - 1) Do
        Begin
            ANet := ADoc.DM_Nets(J);
                if Version > cLegacyList then
                    Result.Add(ANet)
                else
                    Result.AddObject(ANet.DM_NetName, ANet);
        End;
    end;
End;

function MatchNetOfNetObj(NetObj : ISch_GraphicalObject, var ANetItem : INetItem) : INet;
Var
    i, j, k       : Integer;
    ANet          : INet;
    ObjIDString   : String;
    APin          : ISch_Pin;
    ALine         : ILine;
    AWire         : ISch_Wire;
    APort         : ISch_Port;
    ASheetEntry   : ISch_SheetEntry;
    ANetLabel     : ISch_NetLabel;
    APowerPort    : ISch_Powerobject;
    ABusEntry     : ISch_BusEntry;
    ACrossSheet   : ISch_CrossSheetConnector;
    AHarnEntry    : ISch_HarnessEntry;
    AParameterSet  : ISch_ParameterSet;
    LocationMatch  : Boolean;
    ParentDoc      : String;
    MatchNetItem   : Integer;

Begin
    Result := nil;
    ObjIDString  := ObjectIDToString(NetObj.ObjectID);

    For j := 0 to (NetList.Count - 1) Do
    Begin
        if Version > cLegacyList then
            ANet := NetList.Items(j)
        else
            ANet := NetList.Objects(j);

        MatchNetItem := -1;
        LocationMatch := False;

        case NetObj.ObjectID of
        eWire, eBusEntry :
            begin
                i := 0;
                while (not LocationMatch) and (i < ANet.DM_LineCount) Do
                begin
                    ALine :=  ANet.DM_Lines(i);
                    ANetItem := ALine;
                    if ALine.DM_SchHandle = NetObj.Handle then
                    if ALine.DM_OwnerDocumentName = ExtractFileName(NetObj.OwnerDocument.DocumentName) then
                    begin
                        LocationMatch := true;
                        MatchNetItem := i;
                    end;
                    Inc(i);
                end;
            end;
        eSheetEntry :
            begin
                i := 0;
                while (not LocationMatch) and (i < ANet.DM_SheetEntryCount) Do
                begin
                    ANetItem := ANet.DM_SheetEntrys(i);
                    LocationMatch := False;
                    ASheetEntry := NetObj;     //ISch_Object

                    if ANetItem.DM_SchHandle = ASheetEntry.Handle then
                    if ANetItem.DM_OwnerDocumentName = Extractfilename(ASheetEntry.OwnerDocument.DocumentName) then
                    begin
                        LocationMatch := true;
                        MatchNetItem := i;
                    end;
                    Inc(i);
                end;
            end;
        eNetLabel :
            begin
                ANetLabel := NetObj;
                for i := 0 to (ANet.DM_NetLabelCount - 1) do
                begin
                    ANetItem := ANet.DM_NetLabels(i);
                    if ANetItem.DM_SchHandle = ANetLabel.Handle then
                    if ANet.DM_NetName = ANetLabel.Text then
                    begin
                        MatchNetItem := i;
                        LocationMatch := true;
                        break;
                    end;
                end;
            end;
        ePin :
            begin
                APin := NetObj;
                i := 0;
                while (not LocationMatch) and (i < ANet.DM_PinCount) Do
                begin
                    ANetItem := ANet.DM_Pins(i);

                    if ANetItem.DM_SchHandle = APin.Handle then
                    begin
                        LocationMatch := true;
                        MatchNetItem := i;
                    end;
                    Inc(i);
                end;
            end;
        ePort :
            begin
                APort := NetObj;
                i := 0;
                while (not LocationMatch) and (i < ANet.DM_PortCount) Do
                begin
                    ANetItem := ANet.DM_Ports(i);
                    if (ANetItem.DM_SchHandle = APort.Handle) then
                    if (ANetItem.DM_PortName = APort.Name) then
                    if (ANetItem.DM_OwnerDocumentName = ExtractFilename(APort.OwnerDocument.DocumentName)) then
                    begin
                        LocationMatch := true;
                        MatchNetItem := i;
                    end;
                    Inc(i);
                end;
            end;

        else // eJunction, ePowerObject, eParameterSet, eHarnessEntry, eCrossSheetConnector
            begin
                i := 0;
                while (not LocationMatch) and (i < ANet.DM_AllNetItemCount) Do
                begin
                    ANetItem := ANet.DM_AllNetItems(i);
                    LocationMatch := False;
            // only consider objects of the same kind
                    if ObjIDString = ANetItem.DM_ObjectKindString then
                    begin
                        if (ANetItem.DM_SchHandle = NetObj.Handle) then
                        begin
                            LocationMatch := true;
                            MatchNetItem := i;
                        end;
                    end;
                    Inc(i);
                end;
            end;
        end;

        If (MatchNetItem >= 0) then
        Begin
            Result := ANet;
            break;
        End;
    End;
End;
{--------------------------------------------------------------------------------}
Function ObjectIDToString ( I : Integer) : WideString;
begin
   // builtin names don't match with ObjectID String fns FFS!
  // cContextHelpStringsByObjectId(I);
// eSignalHarness ??
    case I of
        ePin                 : Result := 'Pin';
        eLine                : Result := 'Line';
        eWire                : Result := 'Wire';
        eJunction            : Result := 'Junction';
        eNetLabel            : Result := 'Net Label';
        ePort                : Result := 'Port';
        eSheetEntry          : Result := 'Sheet Entry';
        eHarnessEntry        : Result := 'Harness Entry';
        eBusEntry            : Result := 'Bus Entry';     // Sch_Line
        ePowerObject         : Result := 'Power Object';
        eCrossSheetConnector : Result := 'Cross-Sheet Connector';
        eNoERC               : Result := 'NoERC';
    else
          Result := 'unknown ObjectID: ' + IntToStr(I);
    end;
end;

Procedure GenerateReport(Report : TStringList, Filename : WideString);
Var
    Prj      : IProject;
    Document : IServerDocument;
    Filepath : WideString;

Begin
    WS  := GetWorkspace;
    If WS <> Nil Then
    begin
       Prj := WS.DM_FocusedProject;
       If Prj <> Nil Then
          Filepath := ExtractFilePath(Prj.DM_ProjectFullPath);
    end;

    If length(Filepath) < 5 then Filepath := 'c:\temp\';

    Filepath := Filepath + Filename;

    Report.SaveToFile(Filepath);

    Document := Client.OpenDocument('Text',Filepath);
    If display and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

