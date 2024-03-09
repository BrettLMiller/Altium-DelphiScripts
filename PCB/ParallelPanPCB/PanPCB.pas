{ PanPCB.PrjScr PanPCB.pas PanPCBForm.pas .dfm

Allows Pan & zoom across multiple PcbDocs w.r.t individual board origin.
Any Pcbdoc can be used to move all others.
Can select different effective origins
Can select components.
Pans to selected component in open PcbLibs
Can open PcbLib using Component footprint name & library

Strict Library Match  : PcbLib filename must match Footprint source library
Allow Open            : allow opening any PcbLib (inc DBLib) with filename match in Workspace.
Any Path              : find a copy of PcbLib anywhere Workspace or in a folder branch .

Set to 1sec refresh.
Click or mouse over the form to start.

Displays matching (to current layer) non-mech layers
Enables and displays (ditto) matching mech layers.
Mechanical layers are ONLY matched by layer number not LayerKinds.

Author BL Miller

202306010  0.10 POC
20230611   0.11 fix tiny mem leak, form to show cursor not BR, failed attempt set current layer.
20230611   0.20 eliminate use WorkSpace & Projects to allow ServDoc.Focus etc
20230611   0.21 match undisplayed layers in other Pcbdocs as they are selected.
20230613   0.22 locate & pan matching selected CMP by designator
20230614   0.23 Three origin modes: board, bottom left & centre of board.
20230615   0.24 support PcbLib by focusing selected FP
20230616   0.25 selected component information.
20230616   0.26 refactor: split processes, move out of form code.
20230617   0.27 open PcbLibs & focus select footprint model
20230618   0.28 bug in SearchPath & test before Client.OpenDoc as can create file!
20230622   0.29 support project searchpath (partially).
20230625   0.30 support load source PcbLib from DBLib, deselect FP after open PcbLib.
20230623   0.31 check if DBLib sourcelib already open.
20240309   0.32 fix Pan&Scan for parallel PcbLibs.

tbd:
set same current layer      ; seems not to work with scope & is TV7_layer.
honour the enabled/disabled install lib status.

SetState_CurrentLayer does not exist, & .CurrentLayer appears to fail to set other PcbDocs.
}
const
    cLongTrue     = -1;
    cEnumBoardRef = 'Board Origin|Bottom Left|Centre|Zoom';
    cRefZoom    = 3;
    cRefBOrigin = 0;
    cRefBLeft   = 1;
    cRefCentre  = 2;
    cInitSearchPath = 'c:\Altium';
    cIgnoreLibName  = 'Simulation';

function FocusedPCB(dummy : integer) : boolean;             forward;
function FocusedLib(dummy : integer) : boolean;             forward;
function FocusedDocType(dummy : integer) : WideString;      forward;
function RefreshFocus(dummy : integer) : boolean;           forward;
function GetCurrentFPName(var PcbLibName : WideString) : widestring; forward;
function AllPcbDocs(dummy : integer) : TStringList;         forward;
function AllPcbLibs(dummy : integer) : TStringList;         forward;
function PanOtherPCBDocs(dummy : integer) : boolean;        forward;
function PanOtherPcbLibs(dummy : integer) : boolean;        forward;
function OpenPcbLibs(dummy : integer) : boolean;            forward;
function GetLoadPcbLibByPath(LibPath : Widestring, const Load : boolean) : IPCB_Library;     forward;
function FindPrjDocByFileName(Prj : IProject, FileName : WideString) : IDocument;            forward;
function FindAllOtherPrjDocByFileName(Prj : IProject, FileName : WideString) : IDocument;    forward;
function PrjSearchPaths(Prj : IProject, FileName : WideString) : TStringlist;                forward;
function FindInstallLibraryPath(LibName : WideString, LibKind : TLibKind) : WideString;      forward;
function LibraryType (LibPath : WideString) : ILibraryType;       forward;
function GetCursorView (dummy : integer) : TCoordPoint;           forward;
function GetViewRect(APCB : IPCB_Board) : TCoordRect;             forward;
function CalcOGVR(CPCB : IPCB_Board, OPCB : IPCB_Board, const IsLib : boolean) : TCoordRect; forward;
function IsFlipped(dummy : integer) : boolean;                    forward;
function FindLayerObj(ABrd : IPCB_Board, Layer : TLayer) : IPCB_LayerObject;                 forward;
function ClearBoardSelections(ABrd : IPCB_Board) : boolean;       forward;

var
    CurrentPCB     : IPCB_Board;
    CurrentLib     : IPCB_Library;
    CurrentBoard   : IPCB_Board;
    CurrentFName   : WideString;
    CurrentServDoc : IServerDocument;
    CurrentCMP     : IPCB_Component;
    CurrentPLC     : IPCB_LibComponent;    //the focused PcbLib Component
    CurrentGVPR    : TCoordRect;
    CurrentCPoint  : TCoordPoint;
    LastCMPName    : WideString;
    CMPPcbLib      : widestring;
    slBoardRef     : TStringList;
    BrdList        : TStringlist;
    PcbLibList     : TStringlist;
    iBoardRef      : integer;
    bViewPChange   : boolean;
    bCMPChange     : boolean;
    bCenterCMP     : boolean;
    bExactLibName  : boolean;
    bOpenLibs      : boolean;
    bAnyLibPath    : boolean;
    bIgnoreSelFP   : boolean;
    SearchPath     : Widestring;

procedure PanPCBs;
var
    dummy : WideString;
begin
    If Client = Nil Then Exit;
    if not Client.StartServer('PCB') then exit;
    If PcbServer = nil then exit;

    slBoardRef := TStringList.Create;
    slBoardRef.Delimiter       := '|';
    slBoardRef.StrictDelimiter := true;
    slBoardRef.DelimitedText   := cEnumBoardRef;
    bExactLibName  := true;
    bOpenLibs      := false;
    bAnyLibPath    := false;
    SearchPath     := cInitSearchPath;
    CurrentServDoc := nil;
    CurrentPCB     := nil;
    CurrentBoard   := nil;
    CurrentFName   := 'no file';
    CurrentLib     := nil;
    CurrentCMP     := nil;
    CurrentPLC     := nil;
    CurrentGVPR    := TCoordRect;
    CurrentCPoint  := TCoordPoint;
    LastCMPName    := '';
    CMPPcbLib      := '';
    bViewPChange   := true;
    bCMPChange     := true;
    bCenterCMP     := true;
    bIgnoreSelFP   := false;
    iBoardRef      := cRefBOrigin;
    dummy          := '';

    RefreshFocus(1);
    ShowForm(1);
end;

function RefreshFocus(dummy : integer) : boolean;
var
    Focused  : boolean;
    FPName   : WideString;
    LastGVPR : TCoordRect;
begin
    Result := false;
    BrdList    := AllPcbDocs(1);
    PcbLibList := AllPcbLibs(1);

    Focused := FocusedPCB(1);
    bIgnoreSelFP := not Focused;

    Focused := FocusedLib(1);

    LastGVPR := CurrentGVPR;

// also updates ViewPort size
    GetCursorView(1);
    if bViewPChange then
        Result := true;

// get any focused FP & its PcbLib
    FPName := GetCurrentFPName(CMPPcbLib);

// minimise PcbLib focus toggling.
    bCMPChange := (LastCMPName <> FPName);
    LastCMPName := FPName;
end;

function PanProcessAll(dummy : integer) : boolean;
var
    Found        : boolean;
    FocusDocType : integer;
begin
    Found  := true;
    if CurrentPCB <> nil then
        PanOtherPCBDocs(1);

    if Not (bViewPChange or bCMPChange) then exit;
// what if focused PcbDoc is closed & an open PcbLib was never focused.
    FocusDocType := FocusedDocType(1);
    if (FocusDocType <> cDocKind_Pcb) and (FocusDocType <> cDocKind_PcbLib) then exit;

    Found := false;
//    if CurrentLib <> nil then
    Found := PanOtherPcbLibs(1);

    If CurrentCMP = nil then exit;
    if not bOpenLibs then exit;

    if not Found then
    begin    
        bIgnoreSelFP := true;
        OpenPcbLibs(1);
    end;
end;

function PanOtherPCBDocs(dummy : integer) : boolean;
var
    PCBSysOpts : IPCB_SystemOptions;
    LayerStack : IPCB_LayerStack_V7;
    ServDoc    : IServerDocument;
    OBrd       : IPCB_Board;
    MechLayer  : IPCB_MechanicalLayer;
    VLSet      : IPCB_LayerSet;
    Prim       : IPCB_Primitive;
    OCMP       : IPCB_Component;
    OBO        : TCoordPoint;
    OVR        : TcoordRect;
    DocFPath   : WideString;
    I, J       : integer;
    CLayer     : TLayer;
    OLayer     : TLayer;
    CLO        : IPCB_LayerObject;
    CLName     : WideString;
    IsMLayer   : boolean;
    SLayerMode : boolean;
    CBFlipped   : boolean;
    OBFlipped   : boolean;
    bView3D     : boolean;
    CGV    : IPCB_GraphicalView;
    CGVM   : TPCBViewMode;
//    CWidth, wParam, lParam : integer;
//    ConfigType : WideString;
//    Config     : WideString;
begin
    Result := false;
    CurrentCMP := nil;
    if CurrentServDoc.BeingClosed = cLongTrue then exit;

// stop previous selection in PcbDoc overriding PcbLib CMP selection.
// annd allow for PcbLib CMP to hightlight all FP in PcbDocs.
    if not bIgnoreSelFP then
    if CurrentPCB.SelectecObjectCount > 0 then
    begin
        Prim := CurrentPCB.SelectecObject(0);
        if Prim.ObjectID = eComponentObject then CurrentCMP := Prim;
        if Prim.InComponent then CurrentCMP := Prim.Component;
    end;

//    if bIgnoreSelFP then
//    if CurrentCMP <> nil then CurrentCMP.Selected := false;

    CLayer   := CurrentPCB.GetState_CurrentLayer;
    IsMLayer := LayerUtils.IsMechanicalLayer(CLayer);

    if IsMLayer then
    begin
        LayerStack := CurrentPCB.LayerStack_V7;
        MechLayer := LayerStack.LayerObject_V7[CLayer];
        SLayerMode := MechLayer.DisplayInSingleLayerMode;
    end;

    CGV  := CurrentPCB.GetState_MainGraphicalView;     // TPCBView_DirectX()
    bView3D := CGV.Is3D;

    for I := 0 to (BrdList.Count -1 ) do
    begin
        DocFPath := BrdList.Strings(I);
        ServDoc  := BrdList.Objects(I);
        OBrd     := PCBServer.GetPCBBoardByPath(DocFPath);
// check if not open in PcbServer & ignore.
// should be redundant when using ServerDocument.
        if OBrd = nil then continue;

        If (OBrd.BoardID <> CurrentPCB.BoardID) then
        begin
            ServDoc.Focus;
            OCMP := nil;
            if CurrentCMP <> nil then
            begin
                ClearBoardSelections(OBrd);
                OCMP := OBrd.GetPcbComponentByRefDes(CurrentCMP.Name.Text);
                if OCMP <> nil then
                begin
                    OCMP.Selected := true;
                end;
            end;

// changes the physical window size!
            CGV  := OBrd.GetState_MainGraphicalView;

            if not IsMLayer then
            if not OBrd.VisibleLayers.Contains(CLayer) then
            begin
                OBrd.VisibleLayers.Include(CLayer);
                OBrd.LayerIsDisplayed(CLayer) := true;
                OBrd.ViewManager_UpdateLayerTabs;
            end;

            if IsMLayer then
            begin
                LayerStack := OBrd.LayerStack_V7;
                MechLayer := LayerStack.LayerObject_V7[CLayer];
                MechLayer.MechanicalLayerEnabled   := true;
                MechLayer.IsDisplayed(OBrd)        := true;
                MechLayer.SetState_DisplayInSingleLayerMode(SLayerMode);
                OBrd.ViewManager_UpdateLayerTabs;
            end;

            OLayer := OBrd.Getstate_CurrentLayer;
            if (OLayer <> CLayer) then
            begin
                OBrd.CurrentLayer := CLayer;
                OBrd.ViewManager_UpdateLayerTabs;
            end;

            if bViewPChange then
            begin
                OVR := CalcOGVR(CurrentBoard, OBrd, false);

                if bCenterCMP and (OCMP <> nil) then
                begin
                    OBO := Point(OCMP.X, OCMP.Y);
                    OBrd.GraphicalView_ZoomOnRect(OBO.X - RectWidth(OVR)/2, OBO.Y - RectHeight(OVR)/2,
                                                  OBO.X + RectWidth(OVR)/2, OBO.Y + RectHeight(OVR)/2);
                end else
                    OBrd.GraphicalView_ZoomOnRect(OVR.X1, OVR.Y1, OVR.X2, OVR.Y2);
                OBrd.GraphicalView_ZoomRedraw;
            end;
            Result := true;
        end;
    end;
end;

function PanOtherPcbLibs(dummy : integer) : boolean;
var
    ServDoc    : IServerDocument;
    OLib       : IPCB_Library;
    LibCMP     : IPCB_LibComponent;
    SLibName   : WideString;
    I          : integer;
    OVR        : TCoordRect;
    OBO        : TCoordPoint;
begin
    Result := false;
// PcbLibs open
    for I := 0 to (PcbLibList.Count -1 ) do
    begin
        ServDoc  := PcbLibList.Objects(I);
        if ServDoc.BeingClosed = cLongTrue then continue;

        OLib := GetLoadPcbLibByPath(ServDoc.FileName, false);
        If (OLib.LibraryID = CurrentLib.LibraryID) then continue;

        SLibName := ExtractFileName(CMPPcbLib);

// indirect to sourcelib
        if LibraryType(SLibName) = eLibDatabase then
        begin
            SLibName := FindInstallLibraryPath(SLibName, eLibDatabase);
            SLibName := ExtractFileName(SLibName);
        end;

        if bExactLibName then
        if SLibName <> ExtractFileName(ServDoc.FileName) then
            continue;

        OLib := GetLoadPcbLibByPath(ServDoc.FileName, false);

        LibCMP := OLib.GetComponentByName(LastCMPName);
        if bCMPChange then
        begin
            if LibCMP <> nil then
            begin
                OLib.SetState_CurrentComponent(LibCMP);    //must use else Origin & BR all wrong.
                LibCMP.Board.ViewManager_FullUpdate;
            end;
        end;
        if bCMPChange or bViewPChange then
        begin
            OVR := CalcOGVR(CurrentBoard, OLib.Board, true);
            OLib.Board.GraphicalView_ZoomOnRect(OVR.X1, OVR.Y1, OVR.X2, OVR.Y2);
        end;
        Result := true;
    end;
end;

function OpenPcbLibs(dummy : integer) : boolean;
var
    Prj         : IProject;
    LibDoc      : IDocument;
    ServDoc     : IServerDocument;
    OLib        : IPCB_Library;
    LibCMP      : IPCB_LibComponent;
    LibFileName : WideString;
    LibPath     : Widestring;
    LCMPName    : Widestring;
    FPLibPath   : Widestring;
    FoundPath   : WideString;
    slFileList  : TStringlist;
    bFound      : boolean;
begin

    bFound       := false;
    LibPath      := '';
    LibDoc       := nil;
    ServDoc      := nil;
    slFileList   := TStringList.Create;
    FoundPath    := SearchPath;
    LibFileName  := ExtractFileName(CurrentCMP.SourceFootprintLibrary);
    FPLibPath    := ExtractFilePath(CurrentCMP.SourceFootprintLibrary);
    LCMPName     := CurrentCMP.Pattern;
// PCBLib not opened
// this focused project
    Prj := GetWorkspace.DM_FocusedProject;
    if Prj <> nil then
    begin
        LibDoc := FindPrjDocByFileName(Prj, LibFileName);
        if LibDoc <> nil then
            LibPath := LibDoc.DM_FullPath
        else
            slFileList :=  PrjSearchPaths(Prj, LibFileName);
        if slFileList.Count > 0 then LibPath := slFileList.Strings(0);
    end;

// all other projects
    if LibPath = '' then
    begin
        LibDoc := FindAllOtherPrjDocByFileName(Prj, LibFileName);
        if LibDoc <> nil then
            LibPath := LibDoc.DM_FullPath;
    end;

// free project
    if LibPath = '' then
    begin
        Prj := GetWorkspace.DM_FreeDocumentsProject;
        if Prj <> nil then
            LibDoc := FindPrjDocByFileName(Prj, LibFileName);
        if LibDoc <> nil then
            LibPath := LibDoc.DM_FullPath
    end;

// installed libs
    if LibPath = '' then
        LibPath := FindInstallLibraryPath(LibFileName, eLibSrc_File);

    if (LibPath <> '') then
        ServDoc := Client.OpenDocumentShowOrHide(cDocKind_PcbLib, LibPath, True);

    if (ServDoc = nil) then
    begin
        FoundPath := FPLibPath;
        bFound := FindFileInFolderBranch(LibFileName, FoundPath, SearchPath);

        if not bFound then
            FoundPath := SearchPath;

        if (not bFound) and bAnyLibPath then
            bFound := FindFileInFolderBranch(LibFileName, FoundPath, SearchPath);

        if bFound and (FoundPath <> '') then
            ServDoc := Client.OpenDocumentShowOrHide(cDocKind_PcbLib, FoundPath, True);
        if (ServDoc <> nil) then
        begin
            Prj := GetWorkspace.DM_FreeDocumentsProject;
            Prj.DM_BeginUpdate;
            Prj.DM_AddSourceDocument(ServDoc.FileName);
            Prj.DM_EndUpdate;
        end;
    end;

    if (ServDoc <> nil) then
    begin
        OLib := GetLoadPcbLibByPath(ServDoc.FileName, true);
        if OLib <> nil then
        begin
            LibCMP := OLib.GetComponentByName(LCMPName);
            if LibCMP <> nil then
            begin
                OLib.SetState_CurrentComponent(LibCMP);    //must use else Origin & BR all wrong.
                LibCMP.Board.ViewManager_FullUpdate;
            end;
            Result := true;
        end;
        Client.ShowDocument(ServDoc);
//        ServDoc.View(0).Show;
        Servdoc.Focus;
    end;
    slFileList.Clear;
    slFileList.Free;
    Prj.DM_RefreshInWorkspaceForm;
end;

function ClearLastCMPName(dummy : integer);
begin
    LastCMPName := '';
end;

function GetLoadPcbLibByPath(LibPath : Widestring, const Load : boolean) : IPCB_Library;
begin
    Result := PCBServer.GetPCBLibraryByPath(LibPath);
    if Load then
    if Result = nil then
        Result := PcbServer.LoadPcbBoardByPath(LibPath);
end;

function PrjSearchPaths(Prj : IProject, FileName : WideString) : TStringlist;
var
    SearchPath  : ISearchPath;
    LibPath     : WideString;
    FilePaths   : TStrings;
    I           : integer;
    bSubFolders : boolean;
begin
    Result    := TStringList.Create;
    FilePaths := TStringList.Create;
    for I := 0 to (Prj.DM_SearchPathCount - 1) do
    begin
        SearchPath := Prj.DM_SearchPaths(I);
        LibPath   := ExtractFilepath(Searchpath.DM_AbsolutePath);   // comes with file mask *.*
        bSubFolders := SearchPath.DM_IncludeSubFolders;
        FindFiles(LibPath, FileName, faAnyFile, bSubFolders, FilePaths);
        if (FilePaths.Count > 0) then
            Result.Add(FilePaths.Strings(0));
    end;
    FilePaths.Clear;
    FilePaths.Free;
end;

function FindInstallLibraryPath(LibName : WideString, LibKind : TLibKind) : WideString;
var
    IntLibMan   : IIntegratedLibraryManager;
    DBLib       : IDatabaseLibDocument;
    DBSourceLib : WideString;
    FilePath    : WideString;
    I           : integer;
begin
    Result := '';
    IntLibMan := IntegratedLibraryManager;
    If IntLibMan = Nil Then Exit;
    for I := 0 to (IntLibMan.InstalledLibraryCount - 1) Do
    begin
        FilePath  := IntLibMan.InstalledLibraryPath(I);

        if ansipos(cIgnoreLibName, ExtractFileNameFromPath(FilePath)) = 1 then
            continue;

        if ExtractFileName(FilePath) <> LibName then continue;

        if LibraryType(FilePath) = LibKind then
            Result := FilePath;

        if LibraryType(FilePath) = eLibDatabase then
        begin
            DBSourceLib := '';
            Result := IntLibMan.GetDatabaseModelFullLibPath(FilePath, DBSourceLib, CurrentCMP.Pattern, cDocKind_PcbLib);
        end;
        if Result <> '' then break;
    end;
end;

// FindProjectDocumentByFileName() needs fullpath.
function FindPrjDocByFileName(Prj : IProject, FileName : WideString) : IDocument;
var
   Doc : IDocument;
   I   : integer;
begin
    Result := nil;
    I := 0;
    for I := 0 to Prj.DM_LogicalDocumentCount - 1 Do
    begin
        Doc := Prj.DM_LogicalDocuments(I);
        if Doc.DM_Filename = ExtractFileName(FileName) then
        begin
            Result := Doc;
            break;
        end;
    end;
end;

function FindAllOtherPrjDocByFileName(Prj : IProject, FileName : WideString) : IDocument;
var
    WS     : IWorkspace;
    OPrj   : IProject;
    LibDoc : IDocument;
    I      : integer;
begin
    Result := nil;
    WS := GetWorkspace;
    for I := 0 to (WS.DM_ProjectCount - 1) do
    begin
        OPrj := WS.DM_Projects(I);
        if OPrj = Prj then continue;
        LibDoc := FindPrjDocByFileName(OPrj, FileName);
        if LibDoc <> nil then
            Result := LibDoc;
    end;
end;

Function LibraryType (LibPath : WideString) : ILibraryType;
// LibPath is the full path & name.
var
    IntLibMan   : IIntegratedLibraryManager;
    I        : Integer;
    LibCount : Integer;

begin
    Result := -1;
    IntLibMan := IntegratedLibraryManager;
    LibCount := IntLibMan.AvailableLibraryCount;   // zero based totals !

    for I := 0 to (LibCount - 1) Do           //.Available...  <--> .Installed...
    Begin
        if IntLibMan.AvailableLibraryPath(I) = LibPath then
            Result := IntLibMan.AvailableLibraryType(I);
        if Result <> -1 then break;
    end;
End;

function GetCurrentFPName(var PcbLibName : WideString) : widestring;
begin
    Result := 'no footprint selected';
    if FocusedDocType(1) = cDocKind_Pcb then
    if CurrentCMP <> nil then
    begin
        Result      := CurrentCMP.Pattern;
        PcbLibname  := CurrentCMP.SourceFootprintLibrary;
    end;
    if FocusedDocType(1) = cDocKind_PcbLib then
    if CurrentPLC <> nil then
    begin
        Result     := CurrentPLC.Name;
        PcbLibName := CurrentLib.Board.FileName;
    end;
end;

function GetCurrentFPLibraryName(dummy : integer) : widestring;
var
    SourceCMPLibRef : widestring;
begin
    Result := 'no Lib footprint selected';
    if FocusedDocType(1) = cDocKind_Pcb then
    if CurrentCMP <> nil then
    begin
        SourceCMPLibRef := ExtractFileName(CurrentCMP.SourceLibReference);
        if SourceCMPLibRef = '' then
            SourceCMPLibRef := 'NO CompSource LibRef';
        Result := SourceCMPLibRef + ' / ' + ExtractFileName(CurrentCMP.SourceFootprintLibrary);
    end;
    if FocusedDocType(1) = cDocKind_PcbLib then
    if CurrentPLC <> nil then
        Result := 'n/a';
end;

function CleanExit(dummy : integer) : boolean;
begin
    if BrdList <> nil then BrdList.Clear;
    if PcbLibList  <> nil then PcbLibList.Clear;
end;

function GetCursorPoint(DocKind : WideString) : TCoordPoint;
begin
    Result := TPoint;
    if DocKind = cDocKind_PcbLib then
        Result := Point(CurrentLib.Board.XCursor - CurrentLib.Board.XOrigin, CurrentLib.Board.YCursor - CurrentLib.Board.YOrigin)
    else
        Result := Point(CurrentPCB.XCursor - CurrentPCB.XOrigin, CurrentPCB.YCursor - CurrentPCB.YOrigin);
end;

function ViewPortChanged(LastGVPR : TcoordRect) : boolean;
var
    Magnit : extended;
begin
    Result := false;
    Magnit := abs(LastGVPR.X1 - CurrentGVPR.X1) + abs(LastGVPR.X2 - CurrentGVPR.X2);
    Magnit := abs(LastGVPR.Y1 - CurrentGVPR.Y1) + abs(LastGVPR.Y2 - CurrentGVPR.Y2) + Magnit;
    if Magnit > 1000 then
        Result := true;
end;

function GetCursorView (dummy : integer) : TCoordPoint;
var
    Board    : IPCB_Board;
    HasPCB   : boolean;
    HasLIB   : boolean;
    LastGVPR : TCoordRect;
begin
    Result       := TPoint;
    CurrentFName := 'no focused file';
    LastGVPR     := CurrentGVPR;

    HasPCB := FocusedPCB(1);
    HasLIB := FocusedLib(1);

    if HasPCB then
    begin
        CurrentFName  := ExtractFileName(CurrentPCB.FileName);
        CurrentGVPR   := GetViewRect(CurrentPCB);
        bViewPChange  := ViewPortChanged(LastGVPR);
        CurrentCPoint := GetCursorPoint(cDocKind_Pcb);
    end;
    if HasLIB then
    begin
        Board         := CurrentLib.Board;
        CurrentFName  := ExtractFileName(Board.FileName);
        CurrentGVPR   := GetViewRect(Board);
        bViewPChange  := ViewPortChanged(LastGVPR);
        CurrentCPoint := GetCursorPoint(cDocKind_PcbLib);
    end;
end;

function FormGetCursorView(var TBText : widestring) : TCoordPoint;
begin
    Result := CurrentCPoint;
    TBText := CurrentFName;
end;

function GetViewRect(APCB : IPCB_Board) : TCoordRect;
begin
    Result := TRect;
//  seems just same
//    CWR := CPCB.WindowBoundingRectangle;  // TCoord
    Result := APCB.GraphicalView_ViewportRect;
    Result := RectToCoordRect(Rect(Result.X1 - APCB.XOrigin, Result.Y2 - APCB.YOrigin,
                                   Result.X2 - APCB.XOrigin, Result.Y1 - APCB.YOrigin) );
end;

// scale new Graph View rect using window sizes, one dimension wins over the other.
//              'C'urrent & 'O'ther 
function CalcOGVR(CPCB : IPCB_Board, OPCB : IPCB_Board, const IsLib : boolean) : TCoordRect;
var
//   BOL : IPCB_BoardOutline;
   GVR   : TRect;
   CVR   : TCoordRect;
   OBO   : TCoordPoint;
   CBO   : TCoordRect;
   OBBOR : TCoordRect;
   CBBOR : TCoordRect;
   Mode  : integer;
   IsFlip : boolean;
   Rotation : float;
begin
    OBBOR := OPCB.BoundingRectangle;   // was BOL. but fails with PcbLib
    CBBOR := CPCB.BoundingRectangle;
    GVR := CPCB.GraphicalView_ViewportRect;

// need handle selected PcbDoc CMP flipped or rotated w.r.t PcbLib!
// ignore reverse case.
    IsFlip := false;
    Rotation := 0;
    if IsLib and (CurrentCMP <> nil) then
    begin
        if CurrentCMP.Layer = eBottomLayer then IsFlip := true;
        Rotation := CurrentCMP.Rotation;
    end;

    Mode := iBoardRef;

    Case Mode of
    cRefBLeft :    // bottom left
        begin
            OBO := Point(OBBOR.X1, OBBOR.Y1);
            CBO := Point(CBBOR.X1, CBBOR.Y1);
        end;
    cRefCentre :    // CofMass
        begin
            OBO := Point(OBBOR.X1 + RectWidth(OBBOR)/2, OBBOR.Y1 + RectHeight(OBBOR)/2);
            CBO := Point(CBBOR.X1 + RectWidth(CBBOR)/2, CBBOR.Y1 + RectHeight(CBBOR)/2);
        end;
    cRefZoom :
        begin
            OBO := Point(OPCB.XOrigin, OPCB.YOrigin);
            CBO := Point((GVR.X1 + GVR.X2) /2, (GVR.Y1 + GVR.Y2) /2);
        end;
    else
        begin    //     cRefBOrigin = 0
            OBO := Point(OPCB.XOrigin, OPCB.YOrigin);
            CBO := Point(CPCB.XOrigin, CPCB.YOrigin);
        end;
    end;

    CVR := RectToCoordRect(Rect(GVR.X1 - CBO.X, GVR.Y2 - CBO.Y,
                                GVR.X2 - CBO.X, GVR.Y1 - CBO.Y) );

    Result := RectToCoordRect(Rect(CVR.X1 + OBO.X, CVR.Y2 + OBO.Y,
                                   CVR.X2 + OBO.X, CVR.Y1 + OBO.Y));
end;

function GetViewScale(APCB : IPCB_Board) : extended;
begin
    Result := APCB.Viewport.Scale;
end;

// no good! requires mouse over before status changes.
// but the main menu knows the correct state!
function IsFlipped(dummy : integer) : boolean;
var
    GUIM : IGUIManager;
    state : WideString;
begin
    If Client = Nil Then Exit;
    GUIM := Client.GUIManager;
    GUIM.UpdateInterfaceState;
    Result := false;
    state := GUIM.StatusBar_GetState(1);
    If pos('Flipped',state) <> 0 Then
      Result := true;
end;

function FlipBoard(dummy : integer) : boolean;
begin
    ResetParameters;
    RunProcess('PCB:FlipBoard');
end;

function ClearBoardSelections(ABrd : IPCB_Board) : boolean;
var
    CMP : IPCB_Component;
    I   : integer;
begin
    Result := false;
    ABrd.SelectedObjects_BeginUpdate;
    ABrd.SelectedObjects_Clear;
    ABrd.SelectedObjects_EndUpdate;
    for I := 0 to (ABrd.SelectecObjectCount - 1) do
    begin
        CMP := ABrd.SelectecObject(I);
        CMP.Selected := false;
        Result := true;
    end;
end;

function FindLayerObj(ABrd : IPCB_Board, Layer : TLayer) : IPCB_LayerObject;
var
   LO         : IPCB_LayerObject;
   Lindex     : integer;
begin
    Result := nil; Lindex := 0;
    LO := ABrd.MasterLayerStack.First(eLayerClass_All);
    While (LO <> Nil ) do
    begin
        if LO.V7_LayerID.ID = Layer then
            Result := LO;
        LO := ABrd.MasterLayerStack.Next(eLayerClass_All, LO);
    end;
end;

function AllPcbDocs(dummy : integer) : TStringList;
var
    SM      : IServerModule;
    Prj     : IProject;
    ServDoc : IServerDocument;
    Doc     : IDocument;
    I, J    : integer;
begin
    Result := TStringlist.Create;
    SM := Client.ServerModuleByName('PCB');
    for I := 0 to (SM.DocumentCount - 1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind = cDocKind_Pcb) then
            Result.AddObject(ServDoc.FileName, ServDoc);
    end;
end;

function AllPcbLibs(dummy : integer) : TStringList;
var
    SM      : IServerModule;
    Prj     : IProject;
    ServDoc : IServerDocument;
    Doc     : IDocument;
    I, J    : integer;
begin
    Result := TStringlist.Create;

    SM := Client.ServerModuleByName('PCB');
    for I := 0 to (SM.DocumentCount - 1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind = cDocKind_PcbLib) then
            Result.AddObject(ServDoc.FileName, ServDoc);
    end;
end;

function FocusedDocType(dummy : integer) : WideString;
var
    Doc : IDocument;
begin
    Result := '';
    Doc := GetWorkspace.DM_FocusedDocument;
    if Doc <> nil then
        Result := Doc.DM_DocumentKind;
end;

function FocusedPCB(dummy : integer) : boolean;
var
    SM       : IServerModule;
    ServDoc  : IServerDocument;
    Doc      : IDocument;
    APCB     : IPCB_Board;
    I        : integer;
begin
    Result := false;
    Doc := GetWorkspace.DM_FocusedDocument;
    SM  := Client.ServerModuleByName('PCB');
    APCB := PCBServer.GetCurrentPCBBoard;

    if Doc <> nil then
    for I := 0 to (SM.DocumentCount - 1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind <> cDocKind_Pcb) then continue;
        if (ServDoc.IsShown <> cLongTrue) then continue;

        if CurrentServDoc = nil then
            CurrentServDoc := ServDoc;

        if Doc.DM_FileName = ExtractFileName(ServDoc.FileName) then
        begin
            CurrentServDoc := ServDoc;
            if APCB <> nil then
            if APCB.Filename = ServDoc.FileName then
            begin
                CurrentPCB := APCB;
                CurrentBoard := APCB;
                Result := true;
            end;
        end;
    end;
end;

function FocusedLib(dummy : integer) : boolean;
var
    SM      : IServerModule;
    ServDoc : IServerDocument;
    Doc  : IDocument;
    APCB : IPCB_Library;
    I    : integer;
begin
    Result := false;
    Doc := GetWorkspace.DM_FocusedDocument;
    SM  := Client.ServerModuleByName('PCB');
    APCB := PCBServer.GetCurrentPCBLibrary;
    if APCB <> nil then
        CurrentLib := APCB;
    if APCB <> nil then
        CurrentBoard := APCB.Board;

    if Doc <> nil then
    for I := 0 to (SM.DocumentCount - 1) do
    begin
        ServDoc := SM.Documents(I);
        if (ServDoc.Kind <> cDocKind_PcbLib) then continue;
        if (ServDoc.IsShown <> cLongTrue) then continue;

        if CurrentServDoc = nil then
            CurrentServDoc := ServDoc;

        if Doc.DM_FileName = ExtractFileName(ServDoc.FileName) then
        begin
            CurrentPLC := nil;
            if APCB <> nil then
            if ExtractfileName(APCB.Board.Filename) = Doc.DM_FileName then
            begin
                CurrentServDoc := ServDoc;
                CurrentBoard := APCB.Board;
                CurrentPLC := APCB.GetState_CurrentComponent;
                Result := true;
            end;
        end;
    end;
end;

