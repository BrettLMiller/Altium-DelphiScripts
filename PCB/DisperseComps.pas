{ DisperseComponents.pas
PcbDoc: Disperse/distribute component footprints in controlled groups to the
        right hand edge of board outline based on:-
 - components classes.
 - source SchDoc
 - Rooms
Rooms are also auto sized & placed to RHS of the Board Outline.

Things that are NOT moved:-
- any existing Component or Room in the required placement space.
- Component or Room inside the Board Outline shape.
- Graphical "Kind" Footprints
- Footprints with IgnoreFP const in the name.

Script can be re-run after partial placement to move Rooms & Components closer
 to Board Outline.
All Room vertices & Component coordinates remain on Board grid units (integer).
Room components are placed in descending size.
For minimum processing duration can set LiveUpdate & debug = false.

TBD/Notes:  Board.DisplayUnits - TUnit returns wrong values (reversed) in AD17!   (Client.GetProductVersion;)
            Sort classes & Rooms into a sensible order.

B. Miller
06/07/2019 : 0.1  Initial POC
07/07/2019 : 0.2  Added component bounding box offsets.
                  Added Source SchDoc method.
08/08/2019 : 0.21 Minor reporting changes. Bit faster ?
09/07/2019 : 0.3  Better spacing & origin adjustment & coord extreme range checks.
                  CleanNets to refresh connection lines.
10/07/2019 : 0.31 Round the final Comp location to job units & board origin offset.
14/07/2019 : 0.40 Class Component subtotals & Room placement; tweaks to spacing
02/09/2019 : 0.41 Fix CleanNets; was changing the iterated objects.
03/09/2019 : 0.42 Rooms auto sizing & placement.
05/09/2019 : 0.50 Refactored bounding box & comp offsets to reuse for Room & Room comp placement.
06/09/2019 : 0.51 Add board origin details to reported bounding rectangle to match Rooms UI
08/09/2019 : 0.52 Set min. Room size to max component & set max room size limit.
09/09/2019 : 0.53 Fixed reported (in file) room area units & added sq mm.
22/10/2019 : 0.54 Tidied report file with column headings
06/03/2020 : 0.55 Spacefactor 2 -> 3 to make look nicer, stop parts falling out of room
03/03/2022 : 0.56 Add basic ignore FP i.e. 'STENCIL'.
30/05/2022 : 0.57 Add Comp lock check
24/05/2023 : 0.60 Reset FP rotation option.

}

const
    LiveUpdate  = true;    // display PCB changes "live"
    debug       = true;    // report file
    CMPBorder   = 4;       // border added to CMP size  mils
    GRatio      = 1.618;   // aspect R of moved rooms.
    MilFactor   = 10;      // round off Coord in mils
    MMFactor    = 1;
    mmInch      = 25.4;
    TSP_NewCol  = 0;
    TSP_Before  = 1;
    TSP_After   = 2;
    IgnoreFP    = 'STENCIL';   // exclude FP with keyword in FP name (ignored by Rooms method)
    RotateFP    = true;        // rotate before move
    Rotation    = 0;           // angle degrees float
 
var
    FileName      : WideString;
    Board         : IPCB_Board;
    BUnits        : TUnit;
    BOrigin       : TPoint;
    BRBoard       : TCoordRect;
    maxXsize      : TCoord;          // largest comp in column/group
    maxRXsize     : TCoord;          // largest room in column
    SpaceFactor   : double;          // 1 == no extra dead space
    Report        : TStringList;

function GetBoardDetail(const dummy : integer) : TCoordRect;
var
    Height : TCoord;
begin
// returns TUnits but with swapped meanings AD17 0 == Metric but API has eMetric=1 & eImperial=0
    BUnits := Board.DisplayUnit;
    GetCurrentDocumentUnit;
    if (BUnits = eImperial) then BUnits := eMetric
    else BUnits := eImperial;

    BOrigin := Point(Board.XOrigin, Board.YOrigin);
    BRBoard := Board.BoardOutline.BoundingRectangle;

    if debug then
    begin
        Report := TStringList.Create;
        Report.Add('Board originX : ' + CoordUnitToString(BOrigin.X, BUnits) + ' originY ' + CoordUnitToString(BOrigin.Y, BUnits));
    end;

// set some minimum height to work in.
    Height := RectHeight(BRBoard) + MilsToCoord(200);
    if Height < MilsToCoord(2000) then Height := MilsToCoord(2000);
    Result := RectToCoordRect(
              Rect(BRBoard.Right + MilsToCoord(400), BRBoard.Bottom + Height,
                   kMaxCoord - MilsToCoord(10)     , BRBoard.Bottom          ) );
end;

function MinF(a, b : Double) : Double;
begin
    Result := a;
    if a > b then Result := b;
end;
function MaxF(a, b : Double) : Double;
begin
    Result := b;
    if a > b then Result := a;
end;

function RndUnitPos( X : TCoord, Offset : TCoord, const Units : TUnits) : TCoord;
// round the TCoord position value w.r.t Offset (e.g. board origin)
begin
    if Units = eImperial then
        Result := MilsToCoord(Round(CoordToMils(X - Offset) / MilFactor) * MilFactor) + Offset
    else
        Result := MMsToCoord (Round(CoordToMMs (X - Offset) / MMFactor) *  MMFactor ) + Offset;
end;

function RndUnit( X : double, const Units : TUnits) : double;
// round the value w.r.t Offset (e.g. board origin)
begin
    if (Units = eImperial) then
        Result := Round(X / MilFactor) * MilFactor
    else
        Result := Round(X / MMFactor)  * MMFactor;
end;

function GetComponentBR(Comp : IPCB_Component) : TCoordRect;
var
    temp   : TCoord;       // dodgy rect forms.
begin
    Result := RectToCoordRect(Comp.BoundingRectangleNoNameComment);      //TCoord
//    Result   := Comp.BoundingRectangleForPainting;    // inc. masks
//    Result   := Comp.BoundingRectangleForSelection;
    temp := Result.Y1;
    if Result.Y2 < temp then
    begin
        Result.Y1 := Result.Y2;
        Result.Y2 := temp;
    end;
end;

function GetComponentSize(Comp : IPCB_Component) : TPoint;
var
    BRComp : TCoordRect;
begin
    BRComp := GetComponentBR(Comp);
    Result := Point(RectWidth (BRComp), RectHeight(BRComp) );
end;

function GetComponentArea(Comp : IPCB_Component, Border : integer) : double; {sq mils}
var
    BRSize : TPoint;
begin
    BRSize := GetComponentSize(Comp);
    Result := abs((CoordToMils(BRSize.X) + Border) * (CoordToMils(BRSize.Y)+ Border) );
end;

function TestInsideBoard(Component : IPCB_Component) : boolean;
// for speed.. any part of comp touches or inside BO
var
    Prim   : IPCB_Primitive;
    PIter  : IPCB_GroupIterator;
begin
    Result := false;
    PIter  := Component.GroupIterator_Create;
    PIter.AddFilter_ObjectSet(MkSet(ePadObject, eRegionObject));
    Prim := PIter.FirstPCBObject;
    While (Prim <> Nil) and (not Result) Do
    Begin
        if Board.BoardOutline.GetState_HitPrimitive (Prim) then
            Result := true;
        Prim := PIter.NextPCBObject;
    End;
    Component.GroupIterator_Destroy(PIter);
end;

procedure TestStartPosition(var LocationBox : TCoordRect, var LBOffset : TPoint, var maxXCSize : TCoord, const CSize : TPoint, const Opern : integer);
var
    tempOffsetY : TCoord;
begin
    if Opern = TSP_NewCol then
        LBOffset.Y := LBOffset.Y + MilsToCoord(100);               // new class offset in column.

    tempOffsetY := LBOffset.Y;
    if Opern = TSP_After then                                      // next footprint Y coord.
    begin
        if CSize.Y < MilsToCoord(100) then
            LBOffset.Y := LBOffset.Y + CSize.Y * SpaceFactor
        else
            LBOffset.Y := LBOffset.Y + CSize.Y + MilsToCoord(50);
    end;

    if ((LocationBox.Y1 + tempOffsetY + CSize.Y) > LocationBox.Y2) then  // col too high or force to start new column with every new class/sourcedoc
    begin
        LBOffset.Y := 0;
        if maxXCsize < MilsToCoord(150) then
            LBOffset.X := LBOffset.X + maxXCsize * SpaceFactor
        else
        begin
            LBOffset.X := LBOffset.X + maxXCsize + MilsToCoord(50);
        end;
        maxXCsize := 0;
    end;

    LBOffset.X := Min(LBOffset.X, kMaxCoord - LocationBox.X1 - LBOffset.X - MilsToCoord(100));
    LBOffset.Y := Min(LBOffset.Y, kMaxCoord - LocationBox.Y1 - LBOffset.Y - MilsToCoord(100));
end;

procedure PositionComp(Comp : IPCB_Component, var LocationBox : TCoordRect, var LBOffset : TPoint);
var
    OriginOffset : TPoint;    // component origin offset to bounding box
    CSize        : TPoint;
    BRComp       : TCoordRect;
    temp         : TCoord;

begin
    BRComp := GetComponentBR(Comp);
    CSize  := GetComponentSize(Comp);    //TCoord
    CSize  := Point( Max(CSize.X, MilsToCoord(20)), Max(CSize.Y, MilsToCoord(20)) );

//  will it fit?
    TestStartPosition(LocationBox, LBOffset, maxXSize, CSize, TSP_Before);

    maxXSize     := Max(maxXsize, CSize.X);
    OriginOffset := Point(Comp.x - BRComp.X1, Comp.y - BRComp.Y1);

    PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_BeginModify , c_NoEventData);
    Comp.BeginModify;
    temp := RndUnitPos(LocationBox.X1 + LBOffset.X + OriginOffset.X, BOrigin.X, BUnits);   //TCoord
    temp := Min(temp, kMaxCoord - 1000);
    Comp.x := temp;

    temp := RndUnitPos(LocationBox.Y1 + LBOffset.Y + OriginOffset.Y, BOrigin.Y, BUnits);
    temp := Min(temp, kMaxCoord - 1000);
    Comp.y := temp;
    Comp.SetState_XSizeYSize;

    Comp.EndModify;
    PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_EndModify , c_NoEventData);
    Board.ViewManager_GraphicallyInvalidatePrimitive(Comp);

    TestStartPosition(LocationBox, LBOffset, maxXSize, CSize, TSP_After);
    if debug then
        Report.Add(PadRight(IntToStr(Comp.ChannelOffset),4) + ' ' + PadRight(Comp.Name.Text,6) + ' ' + PadRight(Comp.Pattern,20)
                 + ' ' + CoordUnitToString(Comp.x, BUnits)     + ' ' + CoordUnitToString(Comp.y, BUnits)
                 + ' ' + CoordUnitToString(LBOffset.X, BUnits) + ' ' + CoordUnitToString(LBOffset.Y, BUnits) );
end;

procedure PositionRoom(Room : IPCB_ConfinementConstraint, RArea : Double, LocationBox : TCoordRect, var LBOffset : TPoint);
var
    RoomBR    : TCoordRect;
    Length    : TCoord;
    Height    : TCoord;
    RSize     : TPoint;

begin
    // Area in sq mils but Room.BoundingRect is placed by Coord
    // new size
    Length := Sqrt(RArea * GRatio);
    Height := RArea / Length;
    Length := MaxF(Length, 100 * GRatio);
    Height := MaxF(Height, 100);
    Height := MilsToCoord(Height);
    Length := MilsToCoord(Length);

    Length := MinF(Length, kMaxCoord / 8);   // safety limits
    Height := MinF(Height, kMaxCoord / 8);


    RSize := Point(RndUnitPos(Length, 0, BUnits), RndUnitPos(Height, 0, BUnits) );

//  will it fit?
    TestStartPosition(LocationBox, LBOffset, maxRXSize, RSize, TSP_Before);
    maxRXSize := Max(maxRXsize, RSize.X);

//    RoomBR   := Room.BoundingRectangle;
    RoomBR := RectToCoordRect(         //          Rect(L, T, R, B)
              Rect(RndUnitPos(LocationBox.X1 + LBOffset.X,           BOrigin.X, BUnits), RndUnitPos(LocationBox.Y1 + LBOffset.Y + RSize.Y, BOrigin.Y, BUnits),
                   RndUnitPos(LocationBox.X1 + LBOffset.X + RSize.X, BOrigin.X, BUnits), RndUnitPos(LocationBox.Y1 + LBOffset.Y,           BOrigin.Y, BUnits)) );
    Room.BeginModify;
    Room.BoundingRect := RoomBR;
    Room.EndModify;

    TestStartPosition(LocationBox, LBOffset, maxRXSize, RSize, TSP_After);
    RSize := Point(RectWidth (RoomBR), RectHeight(RoomBR) );

    if debug then
        Report.Add('Room : ' + Room.Identifier +  '  absX ' + CoordUnitToString(Room.X - BOrigin.X, BUnits) + ' absY ' + CoordUnitToString(Room.Y - BOrigin.Y, BUnits)
                 + '  offX ' + CoordUnitToString(LBOffset.X, BUnits) + ' offY ' + CoordUnitToString(LBOffset.Y, BUnits)  );
end;

procedure PositionCompsInRoom(Room : IPCB_ConfinementConstraint, CompClass : IPCB_ObjectClass);
var
    CompList     : TObjectList;
    Comp, Comp2  : IPCB_Component;
    CArea        : double;
    Iterator     : IPCB_BoardIterator;
    I            : integer;
    RoomBR       : TCoordRect;
    LCOffset     : TPoint;       // comp offsets in room box

begin
    CompList := TObjectList.Create;
//    RoomBR := RectToCoordRect(Room.BoundingRectangleForPainting); //  Room.BoundingRectangleForSelection;
    RoomBR := Room.BoundingRect;    // not BoundingRectangle !
    if debug then
        Report.Add('Room : ' + Room.Identifier +  '  X1 ' + CoordUnitToString(RoomBR.X1 - BOrigin.X, BUnits) + ' Y1 ' + CoordUnitToString(RoomBR.Y1 - BOrigin.Y, BUnits)
                                                + '  X2 ' + CoordUnitToString(RoomBR.X2 - BOrigin.X, BUnits) + ' Y2 ' + CoordUnitToString(RoomBR.Y2 - BOrigin.Y, BUnits)  );
    LCOffset := Point(MilsToCoord(10), MilsToCoord(10));
    maxXsize := 0; CArea := 0;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);
    Comp := Iterator.FirstPCBObject;
    while Comp <> Nil Do
    begin
        if (Comp.ComponentKind <> eComponentKind_Graphical) then
        if CompClass.IsMember(Comp) then
        if not TestInsideBoard(Comp) then
        begin
            CArea := GetComponentArea(Comp, 0);
            for I := 0 to (CompList.Count - 1) do
            begin
                Comp2 := CompList.Items(I);
                if (CArea > GetComponentArea(Comp2, 0)) then
                begin
                    CompList.Insert(I, Comp);
                    break;
                end;
            end;
            if (I = CompList.Count) then CompList.Add(Comp);
        end;
        Comp := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    if debug then
        Report.Add('ChIdx Desg   FP                  absX     absY     offX     offY ');

    for I := 0 to (CompList.Count - 1) do
    begin
        Comp := CompList.Items(I);
        PositionComp(Comp, RoomBR, LCOffset);
    end;
    CompList.Destroy;
end;

function GetReqRoomArea(Brd : IPCB_Board, CompClass : IPCB_ObjectClass) : TFloatRec; {sq TCoord}
var
    PCBComp    : IPCB_Component;
    Iterator   : IPCB_BoardIterator;
    Area       : Double;          {sq mils}
    CSize      : TPoint;
    maxX, maxY : TCoord;
begin
    Area := 0;
    CSize := Point(0, 0);
    maxX := 0; maxY := 0;
//    CompClass.Name;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);
    PCBComp := Iterator.FirstPCBObject;
    while PCBComp <> Nil Do
    begin
        if CompClass.IsMember(PCBComp) then
        begin
            Area := Area + GetComponentArea(PCBComp, CMPBorder);  // sq mils
            CSize := GetComponentSize(PCBComp);        // TCoord
            maxX := Max(maxX, CSize.X);
            maxY := Max(maxY, CSize.Y);
        end;
        PCBComp := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    maxX := CoordToMils(maxX);
    maxY := CoordToMils(maxY);

// apply space factor but not to the case of one oversized FP
    Area := Area * SpaceFactor;    // * SpaceFactor;

    if (maxX > 0) and (maxY > 0) then
    begin
        if maxX < (maxY * GRatio) then
            maxX := (maxY * GRatio)
        else maxY := (maxX / GRatio);
        if ((maxX * maxY / Area) < 4) and (Area < (maxX * maxY)) then Area := abs(maxX * maxY);
    end;
    Result := Area;
end;

function TestRoomIsInsideBoard(Room : IPCB_Rule) : boolean;
// touching is inside BO!
var
    RuleBR : TCoordRect;

begin
{  Rule.Polygon / Outline  ;       // may have to consider
   for I := 0 To Polygon.PointCount - 1 do
   begin
   if Polygon.Segments[I].Kind = ePolySegmentLine then
}
    Result := false;
    RuleBR := Room.BoundingRect;
    Result := Result or Board.BoardOutline.GetState_StrictHitTest(RuleBR.left, RuleBR.bottom);
    Result := Result or Board.BoardOutline.GetState_StrictHitTest(RuleBR.left, RuleBR.top);
    Result := Result or Board.BoardOutline.GetState_StrictHitTest(RuleBR.right, RuleBR.bottom);
    Result := Result or Board.BoardOutline.GetState_StrictHitTest(RuleBR.right, RuleBR.top);
end;

procedure CleanUpNetConnections(Board : IPCB_Board);
var
    Iterator : IPCB_BoardIterator;
    Connect  : IPCB_Connection;
    Net      : IPCB_Net;
    NetList  : TObjectList;
    N        : integer;
begin
    NetList := TObjectList.Create;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);
    Connect := Iterator.FirstPCBObject;
    while (Connect <> Nil) Do
    begin
        Net := Connect.Net;
        if Net <> Nil then
            if NetList.IndexOf(Net) = -1 then NetList.Add(Net);
        Connect := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    for N := 0 to (NetList.Count - 1) do
    begin
        Net := NetList.Items(N);
        Board.CleanNet(Net);
    end;
    NetList.Destroy;
end;

function GetBoardClasses(Board : IPCB_Board, const ClassKind : Integer) : TObjectList;
var
    Iterator  : IPCB_BoardIterator;
    CompClass : IPCB_ObjectClass;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    Iterator := Board.BoardIterator_Create;
    Iterator.SetState_FilterAll;
    Iterator.AddFilter_ObjectSet(MkSet(eClassObject));
    CompClass := Iterator.FirstPCBObject;
    While CompClass <> Nil Do
    Begin
        if CompClass.MemberKind = ClassKind Then
            if Result.IndexOf( CompClass) = -1 then
                Result.Add(CompClass);

        CompClass := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);
end;

function GetClassCompSubTotals(Board : IPCB_Board, ClassList) : TParameterList;
var
     PCBComp   : IPCB_Component;
     Iterator  : IPCB_BoardIterator;
     Count     : integer;
     CompClass : IPCB_ObjectClass;
     I         : integer;

begin
    Result := TParameterList.Create;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);

    PCBComp := Iterator.FirstPCBObject;
    while PCBComp <> Nil Do
    begin
        if (PCBComp.ComponentKind <> eComponentKind_Graphical) then
        if (PCBComp.Moveable) then
        if (ansipos(IgnoreFP, PCBComp.Pattern) < 1 ) then
        begin
            for I := 0 to (ClassList.Count - 1) do
            begin
                CompClass := ClassList.Items(I);
                if CompClass.IsMember(PCBComp) then
                begin
                    Count := 0;
    // if parameter exists then increment else add
                    if Result.GetState_ParameterAsInteger(CompClass.Name, Count) then
                    begin
                        inc(Count);
                        Result.SetState_AddOrReplaceParameter(CompClass.Name, IntToStr(Count), true) ;
                    end
                    else
                    begin
                        Count := 1;
                        Result.SetState_AddParameterAsInteger(CompClass.Name, Count);
                    end;
                end;
            end;
        end;
        PCBComp := Iterator.NextPCBObject;
    end;
end;


//----------------------------------------------------------------------------------

Procedure DisperseByClass;
Var
   PCBComp          : IPCB_Component;
   LocRect          : TCoordRect;
   LCOffset         : TPoint;
   Iterator         : IPCB_BoardIterator;
   ClassList        : TObjectList;
   ClassList2       : TObjectList;     // sorted by member count
   CompClass        : IPCB_ObjectClass;
   CompClass2       : IPCB_ObjectClass;
   ClassSubTotal    : TParameterList;
   CSubTotal        : integer;
   CSubTotal2       : integer;
   minCTot, maxCTot : integer;
   I, J             : integer;
   skip             : boolean;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    LocRect := GetBoardDetail(0);

    BeginHourGlass(crHourGlass);

    LCoffset := Point(0, 0);
    maxXsize := 0;
    SpaceFactor := 2;


    ClassList := GetBoardClasses(Board, eClassMemberKind_Component);

    ClassSubTotal :=  GetClassCompSubTotals(Board, ClassList);

    if debug then Report.Add('Class count = ' + IntToStr(ClassList.Count) );

    ClassList2 := TObjectList.Create;
    ClassList2.OwnsObjects := false;

    minCTot := 1000000; maxCTot := 0;

    for I := 0 to (ClassList.Count - 1) Do
    begin
        CompClass := ClassList.Items(I);
        CSubTotal := 0;
        ClassSubTotal.GetState_ParameterAsInteger(CompClass.Name, CSubTotal);

        minCTot := Min(minCTot, CSubTotal);
        maxCTot := Max(maxCTot, CSubTotal);
        skip := false;

        if CompClass.SuperClass                        then skip := true;
// all below are superclasses so redundant code..
        if CompClass.Name = 'All Components'           then skip := true;
        if CompClass.Name = 'Outside Board Components' then skip := true;
        if CompClass.Name = 'Inside Board Components'  then skip := true;
        if CompClass.Name = 'Bottom Side Components'   then skip := true;
        if CompClass.Name = 'Top Side Components'      then skip := true;

// potential location below for special hacks..
//        skip := true;
//        if ansipos('_Cell', CompClass.Name) = 0   then skip := true;
//        if ansipos('Cell', CompClass.Name) > 0    then skip := false;

        if debug then
            Report.Add('ClassName : ' + CompClass.Name + '  Kind : ' + IntToStr(CompClass.MemberKind)
                       + '  skip : ' + IntToStr(skip) + '  Member Count = ' + IntToStr(CSubTotal) );

        if not skip then
        begin
            for J := 0 to (ClassList2.Count - 1) do
            begin
                CompClass2 := ClassList2.Items(J);
                ClassSubTotal.GetState_ParameterAsInteger(CompClass2.Name, CSubTotal2);
                if (CSubTotal > CSubTotal2) then
                begin
                    ClassList2.Insert(J, CompClass);
                    break;
                end;
            end;
            if (J = ClassList2.Count) then ClassList2.Add(CompClass)
        end;
    end;
    if ClassList <> nil then ClassList.Destroy;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);

    PCBServer.PreProcess;

    for I := 0 to (ClassList2.Count - 1) Do
    begin
        CompClass := ClassList2.Items(I);

        if debug then
            Report.Add('ChIdx Desg   FP                  absX     absY     offX     offY ');

        PCBComp := Iterator.FirstPCBObject;
        while PCBComp <> Nil Do
        begin
            if (PCBComp.ComponentKind <> eComponentKind_Graphical) then
            if (PCBComp.Moveable) then
            if (ansipos(IgnoreFP, PCBComp.Pattern) < 1 ) then
            if CompClass.IsMember(PCBComp) then
            if not TestInsideBoard(PCBComp) then
            begin
                if (RotateFP) then PCBComp.Rotation := Rotation;
                PositionComp(PCBComp, LocRect, LCOffset);
            end;
            PCBComp := Iterator.NextPCBObject;
        end;
        ClassSubTotal.GetState_ParameterAsInteger(CompClass.Name, CSubTotal);
        if CSubTotal > 0 then
            TestStartPosition(LocRect, LCOffset, maxXSize, Point(0, 0), TSP_NewCol);
        if LiveUpdate then Board.ViewManager_FullUpdate;
    end;

    Board.BoardIterator_Destroy(Iterator);

    PCBServer.PostProcess;
    if ClassList2 <> nil then ClassList2.Destroy;
    if ClassSubTotal <> nil then ClassSubTotal.Destroy;

    CleanUpNetConnections(Board);
    EndHourGlass;

    Board.SetState_DocumentHasChanged;
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;

    if debug then
    begin
        FileName := ChangeFileExt(Board.FileName, '.clsrep');
        Report.SaveToFile(Filename);
        Report.Free;
    end;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 1024, Client.CurrentView);
end;

procedure DisperseBySourceSchDoc;
var
   PCBComp        : IPCB_Component;
   LocRect        : TCoordRect;
   LROffset       : TPoint;
   Iterator       : IPCB_BoardIterator;
   LSchDocs       : TStringList;
   SchDocFileName : IPCB_String;
   I              : integer;
   skip           : boolean;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    LocRect := GetBoardDetail(0);
    BeginHourGlass(crHourGlass);

    LROffset    := Point(0, 0);
    maxXsize    := 0;
    SpaceFactor := 2;

    LSchDocs := TStringList.Create;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);

    PCBComp := Iterator.FirstPCBObject;
    while PCBComp <> Nil Do
    begin
        SchDocFileName := PCBComp.SourceHierarchicalPath;
        if SchDocfileName <> '' then
            if (LSchDocs.IndexOf(SchDocFileName) = -1) then
                LSchDocs.Add(SchDocFileName);

        PCBComp := Iterator.NextPCBObject;
    end;
    if debug then Report.Add('Source Doc count = ' + IntToStr(LSchDocs.Count) );

    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);

    PCBServer.PreProcess;

    for I := 0 to (LSchDocs.Count - 1) Do
    Begin
        SchDocFileName := LSchDocs.Get(I);
        if debug then Report.Add('SourceDoc Name : ' + SchDocFileName);
        if debug then
            Report.Add('ChIdx Desg   FP                  absX     absY     offX     offY ');

        PCBComp := Iterator.FirstPCBObject;
        while PCBComp <> Nil Do
        begin
            if PCBComp.ComponentKind <> eComponentKind_Graphical then
            if (PCBComp.Moveable) then
            if (ansipos(IgnoreFP, PCBComp.Pattern) < 1 ) then
            if SchDocFileName = PCBComp.SourceHierarchicalPath then     // or SourceDescription
            if not TestInsideBoard(PCBComp) then
            begin
                if (RotateFP) then PCBComp.Rotation := Rotation;
                PositionComp(PCBComp, LocRect, LROffset);
            end;
            PCBComp := Iterator.NextPCBObject;
        End;
        TestStartPosition(LocRect, LROffset, maxXSize, Point(0, 0), TSP_NewCol);
        if LiveUpdate then Board.ViewManager_FullUpdate;
    end;
    Board.BoardIterator_Destroy(Iterator);

    PCBServer.PostProcess;
    CleanUpNetConnections(Board);

    LSchDocs.Free;

    EndHourGlass;

    Board.SetState_DocumentHasChanged;
    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;

    if debug then
    begin
        FileName := ChangeFileExt(Board.FileName, '.sdocrep');
        Report.SaveToFile(Filename);
        Report.Free;
    end;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 1024, Client.CurrentView);
end;

Procedure DisperseInRooms;
var
    Iterator      : IPCB_BoardIterator;
    Rule          : IPCB_Rule;
    Room          : IPCB_ConfinementConstraint;
    LocRect       : TCoordRect;
    LROffset      : TPoint;       // room offsets in main big box
    RoomArea      : Double;
    RoomRuleList  : TObjectList;
    ClassList     : TObjectList;
    CompClass     : IPCB_ObjectClass;
    ClassSubTotal : TParameterList;
    CSubTotal     : integer;
    I, J          : integer;
    found         : boolean;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    LocRect := GetBoardDetail(0);

    BeginHourGlass(crHourGlass);

    LROffset := Point(0, 0);
    maxRXSize  := 0;

    RoomRuleList := TObjectList.Create;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);
    Rule := Iterator.FirstPCBObject;
    While (Rule <> Nil) Do
    Begin
        if Rule.RuleKind = eRule_ConfinementConstraint then    // 'RoomDefinition';
            RoomRuleList.Add(Rule);
        Rule := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);

    ClassList := GetBoardClasses(Board, eClassMemberKind_Component);

    ClassSubTotal :=  GetClassCompSubTotals(Board, ClassList);

    if debug then Report.Add('Rooms Rule Count = ' + IntToStr(RoomRuleList.Count));

    for I := 0 to (RoomRuleList.Count - 1) do
    begin
        Room := RoomRuleList.Items(I);
        if debug then
            Report.Add(IntToStr(I) + ': ' + Room.Name + ', UniqueId: ' +  Room.UniqueId +
                       ', RuleType: ' + IntToStr(Room.RuleKind) + '  Layer : ' + Board.LayerName(Room.Layer) );       // + RuleKindToString(Rule.RuleKind));

        if TestRoomIsInsideBoard(Room) then
        begin
            if debug then Report.Add(IntToStr(I) + ': ' + Room.Name + ' is Inside BO');
        end
        else
        begin
 // find the matching class
            found := false;
            J := 0;
            while (not found) and (J < ClassList.Count) do
            begin
                CSubTotal := 0;
                CompClass := ClassList.Items(J);
                ClassSubTotal.GetState_ParameterAsInteger(CompClass.Name, CSubTotal);

                if (CSubTotal > 0) and (CompClass.Name = Room.Identifier) and (not CompClass.SuperClass) then
                begin
                    found := true;
                    if debug then Report.Add('found matching Class ' + IntToStr(J) + ': ' + CompClass.Name + '  Member Count = ' + IntToStr(CSubTotal));
                    if debug then Report.Add('X = ' + CoordUnitToString(Room.X, BUnits) + '  Y = ' + CoordUnitToString(Room.Y, BUnits) );
                    if debug then Report.Add('DSS    ' + Room.GetState_DataSummaryString);
                    if debug then Report.Add('Desc   ' + Room.Descriptor);
                    if debug then Report.Add('SDS    ' + Room.GetState_ScopeDescriptorString);

                    SpaceFactor := 2;   // was 3
                    RoomArea {sq mil} := GetReqRoomArea(Board, CompClass);
                    if debug then
                        if BUnits = eImperial then Report.Add(' area sq in. ' + FormatFloat(',0.###', (RoomArea / SQR(1000)) ) )
                        else  Report.Add(' area sq mm ' + FormatFloat(',0.###', (RoomArea * SQR(mmInch) / SQR(1000)) ) );

                    PositionRoom(Room, RoomArea, LocRect, LROffset);

                    SpaceFactor := 1.6;
                    PositionCompsInRoom(Room, CompClass);
                    if LiveUpdate then Board.ViewManager_FullUpdate;
                end;
                Inc(J);
                if found then
                    if debug then Report.Add('');
            end;
        end;  // outside BO
    end;

    CleanUpNetConnections(Board);
    EndHourGlass;

    RoomRuleList.Destroy;
    if ClassList <> nil then ClassList.Destroy;

    Board.GraphicallyInvalidate;
    Board.ViewManager_FullUpdate;

    if debug then
    begin
        FileName := ChangeFileExt(Board.FileName, '.rmcrep');
        Report.SaveToFile(Filename);
        Report.Free;
    end;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 1024, Client.CurrentView);
end;

{
Rooms
ObjectKind: Confinement Constraint Rule
Category: Placement  Type: Room Definition
   have scope InComponentClass(list of comps)
   have a region BR or VL

        Room.Kind;
        Room.Selected;
        Room.PolygonOutline  ;
        Room.UserRouted;
        Room.IsKeepout;
        Room.UnionIndex;
        Room.NetScope;                    // convert str
        Room.LayerKind;                   // convert str
        Room.Scope1Expression;
        Room.Scope2Expression;
        Room.Priority;
        Room.DefinedByLogicalDocument;

 Room.MoveToXY(RndUnitPos(LocationBox.X1, BOrigin.X, BUnits), RndUnitPos(LocationBox.Y1, BOrigin.Y, BUnits) );

IPCB_ConfinementConstraint Methods
Procedure RotateAroundXY (AX, AY : TCoord; Angle : TAngle);

IPCB_ConfinementConstraint Properties
Property X            : TCoord
Property Y            : TCoord
Property Kind         : TConfinementStyle
Property Layer        : TLayer
Property BoundingRect : TCoordRect

TCoordRect   = Record
    Case Integer of
       0 :(left,bottom,right,top : TCoord);
       1 :(x1,y1,x2,y2           : TCoord);
       2 :(Location1,Location2   : TCoordPoint);

 RectToCoordRect( __Rect__Wrapper) to TCoordRect
}

{  Use built-in functions..
      Board.SelectedObjects_Clear;
      Board.SelectedObjects_Add(Room);
    // DNW can't operate on select rooms..                vvvvvv - does nothing
      Client.SendMessage('PCB:ArrangeComponents', 'Object=Selected|Action=ArrangeWithinRoom', 1024, Client.CurrentView);


//    Board.VisibleGridUnit;
//    Board.ComponentGridSize; // TDouble

}

