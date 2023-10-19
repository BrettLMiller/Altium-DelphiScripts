{ PCBFilter.pas
sanitised copy

set PCB-Filter from cursor rectanglar selection


Usage:
    user has to click select "Apply to All" to apply query expression.
    if you run process with "Apply=True" and any expression then raises errors with script already running!!

The DisplayUnits reversal may be fixed in later AD.


Process: PCB:RunQuery
Parameters :Expr=IsDesignator And (Rotation <> 0) And (Rotation <> 360)|Select=True|Mask=True
Process: PCB:RunQuery
Parameters: Apply=True|Source=Example|Expr=IsComment And (Hide = True)|Zoom=True|Select=True'

Client.SendMessage('PCB:FilterSelect', '_Edit_=True|_Value_=IsTrack And OnTopLayer', 1024, Client.CurrentView);

// Every example has true for either Apply Mask Select Zoom.. no examples of setting false.
}

const
    AD_SNAFU_Units = true;   // true for AD17

var
    Board : IPCB_Board;

procedure FilterAreaSelect;
var
    x, y, x2, y2 : TCoord;
    QExpression  : WideString;
    BUnit        : TUnit;

begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    BUnit := Board.DisplayUnit;
    if (AD_SNAFU_Units) then
    begin
        if (BUnit = eMM) then
            BUnit := eMil
        else
            BUnit := eMM;
    end;

    if Board.ChooseRectangleByCorners('Zone First Corner ','Zone Opposite Corner ', x, y, x2, y2) then
    begin
        if x > x2 then IntSwap(x, x2);
        if y > y2 then IntSwap(y, y2);

        QExpression := 'InRegionAbsolute(' + CoordUnitToStringNoUnit(x,  BUnit) + ',' + CoordUnitToStringNoUnit(y,  BUnit) + ','
                                           + CoordUnitToStringNoUnit(x2, BUnit) + ',' + CoordUnitToStringNoUnit(y2, BUnit) + ')';

        Client.SendMessage('PCB:RunQuery', 'Expr=' + QExpression + '|Zoom=False|DeSelect=false|Select=True|Mask=True', 1023, Client.CurrentView);
//        Client.SendMessage('PCB:RunQuery', 'Expr=' + QExpression + '|Zoom=False|DeSelect=false|Select=True|Mask=True|Apply=True', 1023, Client.CurrentView);
    end;
end;

