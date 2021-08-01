{  OutlineRegionsOnLayer.pas

  make Lines around the perimeter (MainContour) of Regions & ComponentBodies of all footprints in PcbLib
  Need to specify the Layers for: Source / Target (Region) & Destination (lines) for Region & CompBody outlines

Author BLM.
26/06/2021  v0.10  POC
...................................................................................}

const
    cTargetLayer  = 30;    // mech layer of Target primitives.
    cDestinLayer  = 31;    // for Region OutLine
    cDestinLayer2 = 32;    // for CompBody OutLine
    cLineWidth    = 0.5;     // mils

    bDisplay = true;
    ReportFileSuffix = '_FP-RegLinesRpt';
    ReportFileExtension = '.txt';
    ReportFolder = 'Reports';
    bLock   = false;
    bUnLock = false;

Var
    CurrentLib  : IPCB_Library;
    Board       : IPCB_Board;
    CompBody    : IPCB_ComponentBody;

function GenerateReport(Rpt : TStringList) : boolean; forward;
function ContourToLines(GPCVL  : Pgpc_vertex_list, Layer : TLayer, UIndex : integer) : integer; forward;

Procedure OutLineRegions;
Var
    FootprintIterator : IPCB_LibraryIterator;
    Iterator          : IPCB_GroupIterator;
    Handle            : IPCB_Primitive;
    Region            : IPCB_Region;
    Contour           : IPCB_Contour;
    MechLayer         : IPCB_MechanicalLayer;
    Layer             : TLayer;
    NoOfPrims         : Integer;
    NumOfBody         : integer;

    Footprint         : IPCB_Object;
    Rpt               : TStringList;

Begin
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('not a PCB Library document');
        Exit;
    End;

    Board := CurrentLib.Board;
    Layer := LayerUtils.MechanicalLayer(cDestinLayer);
    MechLayer := Board.LayerStack_V7.LayerObject_V7(Layer);
    If Not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        MechLayer.Name := 'Line Out';
        MechLayer.IsDisplayed[Board] := true;
        Board.ViewManager_UpdateLayerTabs;
    end;

    Layer := LayerUtils.MechanicalLayer(cDestinLayer);
    MechLayer := Board.LayerStack_V7.LayerObject_V7(Layer);
    If Not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        MechLayer.Name := 'Reg Line Out';
        MechLayer.IsDisplayed[Board] := true;
        Board.ViewManager_UpdateLayerTabs;
    end;

    Layer := LayerUtils.MechanicalLayer(cDestinLayer2);
    MechLayer := Board.LayerStack_V7.LayerObject_V7(Layer);
    If Not MechLayer.MechanicalLayerEnabled then
    begin
        MechLayer.MechanicalLayerEnabled := true;
        MechLayer.Name := 'CBody Line Out';
        MechLayer.IsDisplayed[Board] := true;
        Board.ViewManager_UpdateLayerTabs;
    end;

    // For each page of library is a footprint
    FootprintIterator := CurrentLib.LibraryIterator_Create;
    FootprintIterator.AddFilter_LayerSet(AllLayers);
    FootprintIterator.SetState_FilterAll;

    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(CurrentLib.Board.FileName));
    Rpt.Add('TargetLayer        : ' + Board.LayerName(LayerUtils.MechanicalLayer(cTargetLayer)) );
    Rpt.Add('Output Lines Layer : ' + Board.LayerName(LayerUtils.MechanicalLayer(cDestinLayer)) );
    Rpt.Add('');

    Try
        Footprint := FootprintIterator.FirstPCBObject;
        While Footprint <> Nil Do
        Begin
            CurrentLib.SetState_CurrentComponent (Footprint);      // to make origin correct.
            Board := CurrentLib.Board;

            Rpt.Add('Footprint : ' + Footprint.Name);

            Iterator := Footprint.GroupIterator_Create;
            Iterator.AddFilter_ObjectSet(MkSet(eRegionObject, eComponentBodyObject));

            Handle := Iterator.FirstPCBObject;

            While (Handle <> Nil) Do
            Begin
//                if bUnLock then Handle.Moveable := true;

                Rpt.Add('Prim : ' + Handle.ObjectIdString);

                if Handle.GetState_ObjectId = eRegionObject then
                begin
                    Region := Handle;

                    if (not Region.IsKeepout) then
                    if (not Region.InPolygon) then
                    if (Region.Layer = LayerUtils.MechanicalLayer(cTargetLayer)) then
                    begin
                        // GMPG := Region.GeometricPolygon;
                        Contour := Region.GetMainContour;
                        NoOfPrims := ContourToLines(Contour, LayerUtils.MechanicalLayer(cDestinLayer), 0);
                        Rpt.Add('Region vertices: ' + IntToStr(NoOfPrims));
                    end;
                end;

                if (Handle.ObjectId = eComponentBodyObject) then
                begin
                    CompBody := Handle;

                    if (CompBody.Layer = LayerUtils.MechanicalLayer(cTargetLayer)) then
                    begin

                        Contour   := CompBody.MainContour;
                        NoOfPrims := ContourToLines(Contour, LayerUtils.MechanicalLayer(cDestinLayer2), 0);
                        Rpt.Add('CompBody vertices: ' + IntToStr(NoOfPrims));
                    end;

//   extruded bodies have a terrible repeated name and/or no name.
//   generic/step models are named by from filename.
//   make blank identifier (not generic model) something useful
                    if CompBody.Identifier = '' then  CompBody.SetState_Identifier(Footprint.Name);

                end;

                if (not bLock) and bUnLock then Handle.Moveable := true;
                if bLock then Handle.Moveable := false;

                Handle := Iterator.NextPCBObject;
            End;

            Rpt.Add('');

            Footprint.GroupIterator_Destroy(Iterator);
             //PcbServer.RobotManager.SendMessage(Component.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
            Footprint := FootprintIterator.NextPCBObject;
        End;

    Finally
        CurrentLib.LibraryIterator_Destroy(FootprintIterator);
        CurrentLib.Navigate_FirstComponent;
        CurrentLib.RefreshView;  // .GraphicallyInvalidate;
    End;

    GenerateReport(Rpt);
    Rpt.Free;
End;

function ContourToLines(GPCVL  : Pgpc_vertex_list, Layer : TLayer, UIndex : integer) : integer;
var
    I      : Integer;
    P1, P2 : TPoint;
    Track  : IPCB_Track;

begin
    Result := 0;
    PCBServer.PreProcess;
    for I := 0 to (GPCVL.Count - 1) do  // - 0 ???
    begin
        P1 := Point(GPCVL.x(I), GPCVL.y(I) );
        if I = GPCVL.Count then
            P2 := Point(GPCVL.x(0), GPCVL.y(0) )
        else
            P2 := Point(GPCVL.x(I + 1), GPCVL.y(I + 1) );

        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
        Track.Width := MilsToCoord(cLineWidth);
        Track.Layer := Layer;
        Track.x1 := P1.x;
        Track.y1 := P1.y;
        Track.x2 := P2.x;
        Track.y2 := P2.y;
        Track.UnionIndex := UIndex;      // no point in PcbLib.
        Board.AddPCBObject(Track);
        PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
        if bLock then Track.Moveable := false;
        inc(Result);
    end;
    PCBServer.PostProcess;
end;

function GenerateReport(Rpt : TStringList) : boolean;
var
    FilePath          : WideString;
    FileName          : TPCBString;
    FileNumber        : integer;
    FileNumStr        : WideString;
    Document          : IServerDocument;

begin
    FilePath := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFileName(FilePath) + '_' + ReportFileSuffix;
    FilePath := ExtractFilePath(FilePath) + ReportFolder;
    if not DirectoryExists(FilePath, false) then
        DirectoryCreate(FilePath);

    FileNumber := 1;
    FileNumStr := IntToStr(FileNumber);
    FilePath := FilePath + '\' + FileName;
    While FileExists(FilePath + FileNumStr + ReportFileExtension) do
    begin
        inc(FileNumber);
        FileNumStr := IntToStr(FileNumber)
    end;
    FilePath := FilePath + FileNumStr + ReportFileExtension;
    Rpt.SaveToFile(FilePath);

    Document  := Client.OpenDocument('Text', FilePath);
    If bDisplay and (Document <> Nil) Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then  // no LongBool const
            Document.DoFileLoad;
    end;
end;

{..............................................................................}
End.
