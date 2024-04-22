{ ShowClassConnections.pas
 derived from www.tdpcb.com   ShowClassConnections.vbs

 Lists the Net & Component Classes and allow showing or hiding the
 connections for nets in that class.
 Allows PCB editing & PcbDoc switching/closing.

modified BL Miller: rewritten in Delphiscript
20230902  v1.10
20240331  v1.20 fix bug in OR classes.
20240401  v1.21 fix colour (was always previous value)& weird not updating show/hide Connections.
20240402  v1.22 tiny performance improvement?, add default colour
20240422  v1.30 refactor getting Net obj; add Hi-Lite button.
20240422  v1.31 return to very slow reliable iterator & ObjectClass.IsMember() methods.
                Alt method: Found a class member (designator) NOT in PCB!!
20240423  v1.32 The cAllxxxClass names are the internal names just use..
}

function GetBoardClasses(ABoard : IPCB_Board, const ClassKind : Integer) : TObjectList; forward;
procedure RemoveClass(var LClass : TObjectList, const CName : WideString);      forward;
procedure MoveTopOfClass(var LClasses : TObjectList, const CName : WideString); forward;
function RefreshBoard(dummy : integer) : IPCB_Board; forward;
function GetCMPClassNets(const CName : WideString) : TStringList; forward;
function GetNetClassNets(const CName : WideString) : TStringList; forward;
function GetNetList(const NetText, const CMPText : WideString) : TStringList; forward;
procedure SetNetRatsNest(const slNetList : TStringList, const State : integer); forward;
procedure SetNetColour(const slNetList : TStringList, const Colour : TColor); forward;

const
    cAllNetsClass  = 'All Nets';
    cAllCMPsClass  = 'All Components';    // internal name of Class
    cLogicOR       = 0;    // 'OR'
    cLogicAND      = 1;    // 'AND'
    cDefaultColour = $0075A19E;  // BRG 24bit default Connection object R=158,G=161,B=117
    cHide = 0;
    cShow = 1;
    cHigh = 2;

var
    Board       : IPCB_Board;
    LBoard      : IPCB_Board;
    NetClasses  : TObjectList;
    CMPClasses  : TObjectList;
    Operation   : integer;
    OldColour   : TColor;
    bColourNets : boolean;

procedure Start;
begin
    LBoard := nil;
    NetClasses := nil;
    CMPClasses := nil;
    Operation  := cLogicOR;

    Board := PCBServer.GetCurrentPCBBoard;
    If Board = nil Then Exit;

    ShowForm(1);
end;

function CleanExit(dummy : integer) : boolean;
begin
    if NetClasses <> nil then NetClasses.Free;
    if CMPClasses <> nil then CMPClasses.Free;
end;

function RefreshBoard(dummy : integer) : IPCB_Board;
begin
// Check current document is a PCB document
    Result := PCBServer.GetCurrentPCBBoard;
    Board  := Result;
    If Result = nil Then Exit;

    NetClasses := GetBoardClasses(Result, eClassMemberKind_Net);
    MoveTopOfClass(NetClasses, cAllNetsClass);
//        RemoveClass(NetClasses, cAllNetsClass);
    CMPClasses := GetBoardClasses(Result, eClassMemberKind_Component);
    MoveTopOfClass(CMPClasses, cAllCMPsClass);

    if LBoard <> Board then
        LBoard := Result;
end;

function SetOperation(const Cycle : boolean) : WideString;
begin
    if Cycle then Inc(Operation);
    Operation := Operation mod 2;
    if Operation = cLogicOR then Result := 'OR';
    if Operation = cLogicAND then Result := 'AND';
end;

procedure ActionColour(const NetText, const CMPText : WideString, NewColour : TColor, const State : integer);
var
    slNetList         : TStringList;
begin
    bColourNets := false;
    if OldColour <> NewColour then
        bColourNets := true;

    if State = cHide then
        NewColour := Board.LayerColor(Prim.Layer)
    else
        OldColour := NewColour;

    slNetList := GetNetList(NetText, CMPText);
    SetNetColour(slNetList, NewColour);
//    Board.ViewManager_FullUpdate;
    slNetList.Free;
end;

procedure ActionRatNests(const NetText, const CMPText : WideString, const State : integer);
var
    slNetList         : TStringList;
begin
    slNetList := GetNetList(NetText, CMPText);
    SetNetRatsNest(slNetList, State);
    slNetList.Free;
end;

function GetNetList(const NetText, const CMPText : WideString) : TStringList;
var
    slNetClassNetList : TStringList;
    slCMPClassNetList : TStringList;
    slNetList         : TStringList;
    ANet              : IPCB_Net;
    ANetName          : WideString;
    I, J              : integer;
begin
    if Board = nil then
    begin
        if NetClasses <> nil then NetClasses.Clear;
        if CMPClasses <> nil then CMPClasses.Clear;
        exit;
    end;

    Result            := TStringList.Create;
//    Result.Sorted     := true;
//    Result.Duplicates := dupIgnore;
    slCMPClassNetList := TStringList.Create;
    slNetClassNetList := TStringList.Create;

    slCMPClassNetList := GetCMPClassNets (CMPText);
    slNetClassNetList := GetNetClassNets (NetText);

// OR and AND combine
    for I := 0 to (slCMPClassNetList.Count - 1) do
    begin
        ANet     := slCMPClassNetList.Objects(I);
        ANetName := slCMPClassNetList.Strings(I);

        J := Result.IndexOf(ANetName);
        if J < 0 then
        begin
            if (Operation = cLogicOR) then
                Result.AddObject(ANetName, ANet);

            if (Operation = cLogicAND) then
            begin
                J := slNetClassNetList.IndexOf(ANetName);
// present in both netlists
                if J > -1 then
                    Result.AddObject(ANetName, ANet);
            end;
        end;
    end;
// OR only
    if Operation = cLogicOR then
    for I := 0 to (slNetClassNetList.Count -1) do
    begin
        ANet     := slNetClassNetList.Objects(I);
        ANetName := slNetClassNetList.Strings(I);
        J := Result.IndexOf(ANetName);
        if J < 0 then
            Result.AddObject(ANetName, ANet);
     end;
    slCMPClassNetList.Free;
    slNetClassNetList.Free;
end;

// IPCB_ObjectClass methods are crap.
// MemberName <> '' may NOT be safe!
// change back to old proven method.
function GetCMPClassNets(const CName : WideString) : TStringList;
var
    Iterator : IPCB_BoardIterator;
    CMP        : IPCB_Component;
    APad       : IPCB_Pad;
    ANet       : IPCB_Net;
    CMPClass   : IPCB_ObjectClass;
    MemberName : WideString;
    ANetName   : WideString;
    I, J, P    : integer;
begin
    Result := TStringList.Create;
    Result.Sorted      := true;
    Result.Duplicates := dupIgnore;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(SignalLayers);

    CMP := Iterator.FirstPCBObject;
    while CMP <> Nil Do
    begin
        for J := 0 to (CMPClasses.Count - 1) do
        begin
            CMPClass := CMPClasses.Items(J);

            if (CName = CMPClass.Name) Then
            if CMPClass.IsMember(CMP) then
            begin
                for P := 1 to CMP.GetPrimitiveCount(MkSet(ePadObject)) do
                begin
                    ANetName := '';
                    APad := CMP.GetPrimitiveAt(P, ePadObject);
                    if APad.InNet then
                    begin
                        ANet := APad.Net;
                        ANetName := ANet.Name;

                        Result.AddObject(ANetName, ANet);
                    end;
                end; // P
            end;  // if
        end;  // J

        CMP := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);
end;

function GetNetClassNets(const CName : WideString) : TStringList;
var
    Iterator : IPCB_BoardIterator;
    NetClass : IPCB_ObjectClass;
    ANet     : IPCB_Net;
    ANetName : WideString;
    I, J     : integer;

begin
    Result := TStringList.Create;
    Result.Sorted      := true;
    Result.Duplicates := dupIgnore;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    ANet := Iterator.FirstPCBObject;
    While (ANet <> nil) do
    begin
        ANetName := ANet.Name;
        for J := 0 to (NetClasses.Count - 1) do
        begin
            NetClass := NetClasses.Items(J);

            if (CName = NetClass.Name) then
            if (CName = cAllNetsClass) or (NetClass.IsMember(ANet)) then
            begin
                Result.AddObject(ANetName, ANet);

            end;  // if
        end;
        ANet := Iterator.NextPcbObject;
    end;
    Board.BoardIterator_Destroy(Iterator);
End;

procedure SetNetColour(const slNetList : TStringList, const Colour : TColor);
var
    Conn     : IPCB_Connection;
    ANet     : IPCB_Net;
    ANetName : WideString;
    I, J     : integer;
begin

    Board.BeginModify;
    for I := 0 to (slNetList.Count - 1) do
    begin
        ANet := slNetList.Objects(I);
        ANet.BeginModify;
        ANet.SetState_Color(Colour);

        if (false) then
        for J := 1 to ANet.GetPrimitiveCount(MkSet(eConnectionObject)) do
        begin
            Conn := ANet.GetPrimitiveAt(J, eConnectionObject);
            Conn.GraphicallyInvalidate;
        end;
        ANet.EndModify;
        ANet.GraphicallyInvalidate;
    end;

    Board.EndModify;
    Board.GraphicallyInvalidate;
End;

procedure SetNetRatsNest(const slNetList : TStringList, const State : integer);    //Turn Net Connection ON or OFF
var
    Conn     : IPCB_Connection;
    ANet     : IPCB_Net;
    ANetName : WideString;
    I, J     : integer;
begin
    Board.BeginModify;

    for I := 0 to (slNetList.Count - 1) do
    begin
        ANet := slNetList.Objects(I);
        ANet.BeginModify;

        if State = cHigh then
        begin
            ANet.LiveHighlightMode := eLiveHighlightMode_High;
            ANet.SetState_IsHighlighted(True);
        end;
        If State = cShow then
            ANet.ShowNetConnects;
        If State = cHide then
            ANet.HideNetConnects;

        if (true) then
        for J := 1 to ANet.GetPrimitiveCount(MkSet(eConnectionObject)) do
        begin
            Conn := ANet.GetPrimitiveAt(J, eConnectionObject);

            Conn.BeginModify;

            Conn.SetState_Mode(eRatsNestConnection);  // TConnectionMode; rats nest or eBrokenNetMarker

            Conn.EndModify;
            Conn.GraphicallyInvalidate;
        end;

        ANet.EndModify;
        ANet.GraphicallyInvalidate;
    end;

    for I := 0 to (slNetList.Count - 1) do
    begin
        ANet := slNetList.Objects(I);
        If State <> cHide then
            Board.CleanNet(ANet);
    end;

    Board.EndModify;
    Board.GraphicallyInvalidate;
End;

function GetBoardClasses(ABoard : IPCB_Board, const ClassKind : Integer) : TObjectList;
var
    Iterator  : IPCB_BoardIterator;
    CompClass : IPCB_ObjectClass;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;

    Iterator := ABoard.BoardIterator_Create;
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
    ABoard.BoardIterator_Destroy(Iterator);
end;

procedure MoveTopOfClass(var LClasses : TObjectList, const CName : WideString);
var
    AClass : IPCB_ObjectClass;
    I      : integer;
begin
    for I := 0 to  (LClasses.Count - 1) do
    begin
        AClass := LClasses.Items(I);
        If AClass.Name = CName Then
        begin
            LClasses.Move(I, 0);
            break;
        end;
    end;
    AClass := nil;
end;

procedure RemoveClass(var LClasses : TObjectList, const CName : WideString);
var
    AClass : IPCB_ObjectClass;
    I       : integer;
begin
    I := 0;
    While I < LClasses.Count do
    begin
        AClass := LClasses.Items(I);
        If AClass.Name = CName Then
            LClasses.Delete(I)
        else
            inc(I);
    end;
    AClass := nil;
end;

