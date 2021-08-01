{ SimpleRegion.pas

B Miller
15/05/2021  v0.10 POC.

}

const
    ArcResolution              = 0.1;  // mils : impacts number of edges etc..

var
    Board         : IPCB_Board;

function AddRegionToBoard(GPC : IPCB_GeometricPolygon, Net : IPCB_Net, const Layer : TLayer, const MainContour : boolean) : IPCB_Region; forward;
function GetMainContour(GPC : IPCB_GeometricPolygon) : IPCB_Contour; forward;

procedure MakeRegion();
var
    Prim          : IPCB_Primitive;
    Contour       : IPCB_Contour;
    GMPC1         : IPCB_GeometricPolygon;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    PCBServer.PCBContourMaker.ArcResolution := MilsToCoord(ArcResolution);

    Contour := PCBServer.PCBContourFactory;   // PCBServer.PCBGeometricPolygonFactory.AddEmptyContour;
    Contour.AddPoint(MilsToCoord(1000), MilsToCoord(1000));
    Contour.AddPoint(MilsToCoord(1000),MilsToCoord(3000));
    PCBServer.PCBContourMaker.AddArcToContour(Contour, 90,0,MilsToCoord(1000),MilsToCoord(2000), MilsToCoord(1000), true);
    Contour.AddPoint(MilsToCoord(2000),MilsToCoord(1000));

    GMPC1 := PcbServer.PCBGeometricPolygonFactory;
    GMPC1.AddContour(Contour);

// Add holes ?
    Contour := PCBServer.PCBContourFactory;
    Contour.AddPoint(MilsToCoord(1300),MilsToCoord(1500));
    Contour.AddPoint(MilsToCoord(1700),MilsToCoord(1500));
    PCBServer.PCBContourMaker.AddArcToContour(Contour, 0,180,MilsToCoord(1500),MilsToCoord(1500), MilsToCoord(200), false);
//    PCBServer.PCBContourMaker.AddArcToContour(Contour, 180,360,MilsToCoord(1500),MilsToCoord(1500), MilsToCoord(200), false);
    GMPC1.AddContourIsHole(Contour, true);
//    GMPC1.IsHole(1);

    Prim := AddRegionToBoard(GMPC1, nil, eTopLayer, False);
    Prim.Selected := true;
    Client.SendMessage('PCB:Zoom', 'Action=Selected', 512, Client.CurrentView);
end;

function AddRegionToBoard(GPC : IPCB_GeometricPolygon, Net : IPCB_Net, const Layer : TLayer, const MainContour : boolean) : IPCB_Region;
var
    GPCVL  : Pgpc_vertex_list;
begin
    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);

// if main outer contour is index (0) then can just use GPC.Contour(0)
    if MainContour and (GPC.Count > 1) then
        Result.SetOutlineContour( GetMainContour(GPC)) // GPC.Contour(0))
    else
    begin
        Result.GeometricPolygon := GPC;
    end;

    Result.SetState_Kind(eRegionKind_Copper);
    Result.Layer := Layer;
    Result.Net   := Net;
//    Result.UnionIndex := UIndex;

    Board.AddPCBObject(Result);
    PCBServer.SendMessageToRobots(Result.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
    PCBServer.PostProcess;
    Result.GraphicallyInvalidate;
end;

function GetMainContour(GPC : IPCB_GeometricPolygon) : IPCB_Contour;
var
    CArea, MArea : double;
    I            : integer;
begin
    Result := PCBServer.PCBContourFactory;
    MArea := 0;
    for I := 0 to (GPC.Count - 1) do
    begin
        CArea := GPC.Contour(I).Area;
        if CArea > MArea then
        begin
            MArea := CArea;
            Result := GPC.Contour(I);
        end;
    end;
end;
