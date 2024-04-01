{ ShowClassConnections.pas
 derived from www.tdpcb.com   ShowClassConnections.vbs

 Lists the Net & Component Classes and allow showing or hiding the
 connections for nets in that class.
 Allows PCB editing & PcbDoc switching/closing.

modified BL Miller: rewritten in Delphiscript
20230902  v1.10
20240331  v1.20 fix bug in OR classes.
20240401  v1.21 fix colour (was always previous value)& weird not updating show/hide Connections.
}

function GetBoardClasses(ABoard : IPCB_Board, const ClassKind : Integer) : TObjectList; forward;
procedure RemoveClass(var LClass : TObjectList, const CName : WideString);      forward;
procedure MoveTopOfClass(var LClasses : TObjectList, const CName : WideString); forward;
function RefreshBoard(dummy : integer) : IPCB_Board; forward;
function GetCMPClassNets(const CName : WideString) : TStringList; forward;
function GetNetClassNets(const CName : WideString) : TStringList; forward;
function GetNetList(const NetText, const CMPText : WideString) : TStringList; forward;
procedure SetNetRatsNest(const slNetList : TStringList, const NetText : WideString, const State : integer); forward;
procedure SetNetColour(const slNetList : TStringList, const NetText : WideString, const Colour : TColor); forward;

const
    cAllNetsClass = 'All Nets';
    cAllCMPsClass = 'All Components';
    cLogicOR   = 0;    // 'OR'
    cLogicAND  = 1;    // 'AND'

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

    if State = 0 then
        NewColour := Board.LayerColor(Prim.Layer)
    else
        OldColour := NewColour;

    slNetList := GetNetList(NetText, CMPText);
    SetNetColour(slNetList, NetText, NewColour);
//    Board.ViewManager_FullUpdate;
    slNetList.Free;
end;

procedure ActionRatNests(const NetText, const CMPText : WideString, const State : integer);
var
    slNetList         : TStringList;
begin
    slNetList := GetNetList(NetText, CMPText);
    SetNetRatsNest(slNetList, NetText, State);
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
    Result.Sorted     := true;
    Result.Duplicates := dupIgnore;
    slCMPClassNetList := TStringList.Create;
    slNetClassNetList := TStringList.Create;

    if CMPText <> cAllCMPsClass then
        slCMPClassNetList := GetCMPClassNets (CMPText);

    if NetText <> cAllNetsClass then
        slNetClassNetList := GetNetClassNets (NetText);

// OR and AND combine
    for I := 0 to (slCMPClassNetList.Count - 1) do
    begin
        ANet := slCMPClassNetList.Objects(I);
        ANetName := slCMPClassNetList.Strings(I);

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
// OR only
    if Operation = cLogicOR then
    for I := 0 to (slNetClassNetList.Count -1) do
    begin
        ANet := nil;
        ANetName := slNetClassNetList.Strings(I);
        Result.AddObject(ANetName, ANet);
    end;
    slCMPClassNetList.Free;
    slNetClassNetList.Free;
end;

function GetCMPClassNets(const CName : WideString) : TStringList;
var
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

    for J := 0 to (CMPClasses.Count - 1) do
    begin
        CMPClass := CMPClasses.Items(J);
        If (CName = CMPClass.Name) Then
        begin
            I := 0;
            MemberName := CMPClass.MemberName(I);   // Get Members of Class
            While (MemberName <> '') do
            begin
                CMP := Board.GetPcbComponentByRefDes(MemberName);
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
                end;
                inc(I);
                MemberName := CMPClass.MemberName(I);
            end;
        end;  // if
    end;
end;

function GetNetClassNets(const CName : WideString) : TStringList;
var
    NetClass : IPCB_ObjectClass;
    ANetName : WideString;
    I, J     : integer;
begin
    Result := TStringList.Create;
    Result.Sorted      := true;
    Result.Duplicates := dupIgnore;

    for J := 0 to (NetClasses.Count - 1) do
    begin
        NetClass := NetClasses.Items(J);
        If (CName = NetClass.Name) Then
        begin
            I := 0;
            ANetName := NetClass.MemberName(I);   // Get Members of Class
            While (ANetName <> '') do
            begin
                Result.Add(ANetName);

                inc(I);
                ANetName := NetClass.MemberName(I);
            end;
        end;  // if
    end;
End;

procedure SetNetColour(const slNetList : TStringList, const NetText : WideString, const Colour : TColor);
var
    Iterator : IPCB_BoardIterator;
    Conn     : IPCB_Connection;
    ANet     : IPCB_Net;
    ANetName : WideString;
    I        : integer;
begin
    Board.BeginModify;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);
    ANet := Iterator.FirstPCBObject;

 // Look for net name match
    While (ANet <> nil) do
    begin
        for I := 0 to (slNetList.Count - 1) do
        begin
            ANetName := slNetList.Strings(I);
            If (NetText = cAllNetsClass) or (ANet.Name = ANetName) Then
            begin
// simplify later step if have all net objects
                slNetList.Objects(I) := ANet;
            end;
        end;

        ANet := Iterator.NextPcbObject;
    end;

    Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
    Conn := Iterator.FirstPCBObject;

    While (Conn <> nil) do
    begin
        for I := 0 to (slNetList.Count - 1) do
        begin
            ANet := slNetList.Objects(I);

            If (Conn.Net = ANet) Then
            begin
                ANet.BeginModify;
                ANet.SetState_Color(Colour);
                ANet.EndModify;
                ANet.GraphicallyInvalidate;
                Conn.GraphicallyInvalidate;
//                Board.AnalyzeNet(ANet);
                Board.CleanNet(ANet);
            end;
        end;
        Conn := Iterator.NextPcbObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
    Board.EndModify;
    Board.GraphicallyInvalidate;
End;

procedure SetNetRatsNest(const slNetList : TStringList, const NetText : WideString, const State : integer);    //Turn Net Connection ON or OFF
var
    Iterator : IPCB_BoardIterator;
    Conn     : IPCB_Connection;
    ANet     : IPCB_Net;
    ANetName : WideString;
    I        : integer;
begin
    Board.BeginModify;
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);
    ANet := Iterator.FirstPCBObject;

 // Look for net name match
    While (ANet <> nil) do
    begin
        If (NetText = cAllNetsClass) then
        begin
            ANet.BeginModify;
            If State = 1 then
                ANet.SetState_ConnectsVisible(True);
            If State = 0 then
                ANet.SetState_ConnectsVisible(False);
            ANet.EndModify;
            ANet.GraphicallyInvalidate;
        end else
        begin
            for I := 0 to (slNetList.Count - 1) do
            begin
                ANetName := slNetList.Strings(I);
                If (ANet.Name = ANetName) Then
                begin
                    ANet.BeginModify;
                    If State = 1 then
                        ANet.SetState_ConnectsVisible(True);
//  ANet.ShowNetConnects;
                    If State = 0 then
                        ANet.SetState_ConnectsVisible(False);
//  ANet.HideNetConnects;
                    ANet.EndModify;
                    ANet.GraphicallyInvalidate;

// simplify later step if all net objects
                     slNetList.Objects(I) := ANet;
                end;
            end;
        end;

        ANet := Iterator.NextPcbObject;
    end;

    Iterator.AddFilter_ObjectSet(MkSet(eConnectionObject));
    Conn := Iterator.FirstPCBObject;

    While (Conn <> nil) do
    begin
        Conn.BeginModify;
        If (NetText = cAllNetsClass) then
        begin
            If State = 1 then
                Board.ShowPCBObject(Conn);
            If State = 0 then
                Board.HidePCBObject(Conn);

            ANet := Conn.Net;
            Board.CleanNet(ANet);
            ANet.GraphicallyInvalidate;
            Conn.GraphicallyInvalidate;
        end else
        begin
            for I := 0 to (slNetList.Count - 1) do
            begin
                ANet := slNetList.Objects(I);

                If Conn.Net = ANet Then
                begin
                    ANet.BeginModify;
                    If State = 1 then
                        Board.ShowPCBObject(Conn);
                    If State = 0 then
                        Board.HidePCBObject(Conn);
                    ANet.EndModify;
                    ANet.GraphicallyInvalidate;
                    Conn.GraphicallyInvalidate;
                    Board.CleanNet(ANet);
                end;
            end;
        end;
        Conn.EndModify;
        Conn := Iterator.NextPcbObject;
    end;

    Board.BoardIterator_Destroy(Iterator);
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

