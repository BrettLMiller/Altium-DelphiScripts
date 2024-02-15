{  SchDoc: Pins

TogglePinVisibility():
   Toggles visiblity of Pin designator (number)
   modifiers:
       <ctrl>  toggles Pin name visibility.
       <shift> toggles rotation of Pin name     ONLY works if Pin has Custom Position set!
       <alt>   toggles all pins of the pin owner comp

ToggleCompPinVisibility():
   Toggle visibility of all pins of picked component
       <alt>   toggles all pins of components with same library reference.

   BL Miller.

if Comp.ShowHiddenPins is true then can not hide anything.

ISch_Pin.Width                               // integer
ISch_Pin.Name_CustomFontID;                  //TFontID
ISch_Pin.Name_FontMode;                      // TPinItemMode
ISch_Pin.Name_CustomColor;                      //TColor
ISch_pin.Name_CustomPosition_Margin;            //TCoord
ISch_Pin.Name_CustomPosition_RotationAnchor;    //TPinTextRotationAnchor
ISch_Pin.Name_CustomPosition_RotationRelative;  // TRotationBy90
similar for Designator

}
// ScriptingSystem:RunScriptText
// Text=Var S,L,H,P;Begin S:=SchServer.GetCurrentSchDocument;L:=EmptyLocation;S.ChooseLocationInteractively(L,'Pick a Pin ');H:=S.CreateHitTest(0,L);P:=H.HitObject(0);if P.ObjectID=ePin then P.SetState_ShowDesignator(true);end;
// Text=Var S,L,H,P;Begin S:=SchServer.GetCurrentSchDocument;L:=EmptyLocation;S.ChooseLocationInteractively(L,'Pick a CMP ');H:=S.CreateHitTest(0,L);P:=H.HitObject(0);if P.ObjectID=eSchComponent then P.SetState_ShowHiddenPins:=false;end;

var
    SchDoc       : ISch_Document;

procedure ProcessCompPins(SchDoc : ISch_Document, Comp : ISch_Component, const OnlyThisComp : boolean); forward;
procedure ProcessPin(var Pin : ISch_Pin);   forward;
function GetCompPin(Comp : ISch_Component, Designator : Text) : ISch_Pin; forward;

procedure TogglePinVisibility;
var
    OwnerComp    : ISch_Component;
    Hit          : THitTestResult;
    HitState     : boolean;
    Location     : TLocation;
    I            : integer;
    Obj          : ISch_GraphicalObject;
    Pin          : ISch_Pin;

begin
    SchDoc := SchServer.GetCurrentSchDocument;
    Location := EmptyLocation;

    repeat
        HitState := SchDoc.ChooseLocationInteractively(Location,'Pick a Pin ');

        if not(HitState) then
            break;

        Hit := SchDoc.CreateHitTest(eHitTest_AllObjects, Location);
//       Cursor := HitTestResultToCursor(Hit);

        I := 0;
        while I < Hit.HitTestCount do
        begin
            Obj := Hit.HitObject(I);

            if (Obj.ObjectId = ePin) then
            begin
                Pin := Obj;
                OwnerComp := Pin.OwnerSchComponent;

                if AltKeyDown then
                    ProcessCompPins(SchDoc, OwnerComp, true)
                else
                    ProcessPin(Pin);

            end;
            inc(I);
        end;
    until not (HitState)
end;

procedure ToggleCompPinVis;
var
    SchDoc       : ISch_Document;
    Hit          : THitTestResult;
    HitState     : boolean;
    Location     : TLocation;
    I            : integer;
    Obj          : ISch_GraphicalObject;

begin
    SchDoc := SchServer.GetCurrentSchDocument;
    Location := EmptyLocation;

    repeat
        HitState := SchDoc.ChooseLocationInteractively(Location,'Pick a Component ');

        if not(HitState) then
            break;

        Hit := SchDoc.CreateHitTest(eHitTest_AllObjects, Location);
//       Cursor := HitTestResultToCursor(Hit);

        I := 0;
        while I < Hit.HitTestCount do
        begin
            Obj := Hit.HitObject(I);

            if (Obj.ObjectId = eSchComponent) then
            begin
                Obj.ShowHiddenPins   := true;
                Obj.ShowHiddenFields := true;
                Obj.ShowHiddenPins   := false;
                Obj.ShowHiddenFields := false;
                Obj.GraphicallyInvalidate;
                ProcessCompPins(SchDoc, Obj, false);
            end;
            inc(I);
        end;
    until not (HitState)
end;

procedure ProcessCompPins(SchDoc : ISch_Document, Comp : ISch_Component, const OnlyThisComp : boolean);
var
    OwnerComp      : ISch_Component;
    CompLibRef     : WideString;
    Pin            : ISch_Pin;
    PinIterator    : ISch_Iterator;
    Change         : boolean;

begin
    PinIterator := SchDoc.SchIterator_Create;    // was CurrentSheet
    PinIterator.AddFilter_ObjectSet(MkSet(ePin));

    Pin := PinIterator.FirstSchObject;
    while Pin <> Nil Do
    begin
        Change := false;
        OwnerComp := Pin.OwnerSchComponent;

        if (Not OnlyThisComp) and AltKeyDown then
        if (Comp.LibReference <> '') then
        if SameString(OwnerComp.LibReference, Comp.LibReference,true) then
            Change := true;

        if SameString(OwnerComp.UniqueId, Comp.UniqueId, false) then
            Change := true;

        if (Change) then
            ProcessPin(Pin);

        Pin := PinIterator.NextSchObject;
    end;
    SchDoc.SchIterator_Destroy(PinIterator);
end;

procedure ProcessPin(var Pin : ISch_Pin);
begin

    if Pin.IsHidden then
        Pin.SetState_IsHidden( false);
    if Pin.Disabled then
        Pin.SetState_Disabled(false);
    if not(ShiftKeyDown) then
    begin
        if not (ControlKeyDown) then
        begin
            if (Pin.ShowDesignator) then
                Pin.SetState_ShowDesignator(false)
            else
                Pin.SetState_ShowDesignator(true);

        end else
        begin
            if (Pin.GetState_ShowName) then
                Pin.SetState_ShowName(false)
            else
                Pin.SetState_ShowName(true);

        end;
    end else
    begin
                 //  <shift> down     this used to work ??
        if (Pin.Name_CustomPosition_RotationRelative = 0) then
            Pin.SetState_Name_CustomPosition_RotationRelative(1)   // := 1
        else
            Pin.SetState_Name_CustomPosition_RotationRelative(0);
    end;
    Pin.GraphicallyInvalidate;
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
