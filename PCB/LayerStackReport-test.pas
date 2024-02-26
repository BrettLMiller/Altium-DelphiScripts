{.................................................................................
 Summary   Used to test LayerClass methods in AD17-22 & report into text file.
           Works on PcbDoc & PcbLib files.

    MakeNewLayerStackCopy:
       create new PcbDoc with clean stack copy.

           From MechLayerNames-test.pas

 Author: BL Miller

 v 0.51
 16/06/2019  : Test for AD19 etc.
 01/07/2019  : messed with MechPair DNW; added MinMax MechLayer constants to report
 08/09/2019  : use _V7 layerstack for mech layer info.
 11/09/2019  : use & report the LayerIDs & iterate to 64 mech layers.
 28/09/2019  : Added colour & display status to layerclass outputs
 30/09/2019  : Resolved the V7_LayerID numbers & fixed colour error in LayerClass
 02/10/2019  : Added mechlayer kind for AD19+
 16/10/2019  : Added UsedByPrims; IPCB_MechanicalLayerPairs.LayerUsed() works with correct index
 31/10/2019 0.51  Added thickness for Cu & dielectric layer properties
 27/05/2020 0.52  Pastemask has a (hidden) thickness. Add thickness total
 28/05/2020 0.53  Don't sum soldermask thickness twice (dielectric & mask)
 01/07/2020 0.54  convert version major to int value to test.
 04/12/2020 0.55  add short & mid & long layer names & layerobj objectaddress
 10/04/2021 0.56  just renamed some variables. Possible Mech Pairs record layer workaround.
 14/05/2021 0.57  Add Master & Sub stack
 18/06/2021 0.58  DielectricTypeToStr is builtin fn..
 13/04/2022 0.59  change logic handling layer types in each class. Sum thickness in Physical
 21/04/2022 0.60  support PcbLib single LayerStack.
 22/04/2022 0.61  sub-stack regions appear to be (2) possible kinds. Hacky soln.
 22/07/2022 0.62  very hacky soln to get the CamView gerber layer name-numbers.
 17/08/2022 0.63  Add drill layer pairs & add mechlayer kind text
 29/11/2022 0.64  add use LayerIterator.Layer to avoid TV7_Layer.ID
 15/02/2023 0.65  add 2 more layerkinds Capping & Filling
 2023-07-11 0.66  Implicit PcbLib test, eliminate _V7 methods if possible.
 2024-01-08 0.67  LO UUID
 2024-02-26 0.70  Crude dump of the missing LSM properties Surface Finish Material etc.

         tbd : find way to fix short & mid names if wrong.
                Use Layer Classes test in AD17 & AD19
                get the matching stack region names for each substack.
                IPCB_BoardRegionManager
                Not convinced about Board.LayerPositionInSet(AllLayers, LayerObj) as TV6_LayerSet junk.

NOT possible to eliminate use of LayerObject_V7() with MechPairs in AD17-AD18
Can only iterate the "enabled" board mech layerset.
AD17 works with 32 mechlayers but the part of API (& UX) do not.

More crappy Altium mess.

TDrillLayerPairType built-in const are wrong; Punched & Laser are swapped.

If layers are moved in LSM then static values for a dynamic "list" object become wrong
IPCB_LayerObject.V7_LayerID.ID
IPCB_LayerObject.V6_LayerID
IPCB_LayerObject.GetState_LayerDisplayName(eLayerNameDisplay_Short)
IPCB_LayerObject.GetState_LayerDisplayName(eLayerNameDisplay_Medium)

IPCB_Layerobject2.GetState_DisplayInSingleLayerMode;
IPCB_LayerObject2.SetState_DisplayInSingleLayerMode(true);


Note: can report all mech layers in AD17-AD22

                      V8_LID    V7_LID
 Top Surface Finish = 1030000   ?27?      already inuse could be coverlay in AD17
 Bottom Surface     = 1030001   ?28?        AD17  eTopCoverlayOutlineLayers
                      1030002   ?29?              eBottomCoverlayOutlineLayers
                      1030003   ?30?
                      1030004   ?31?
                      1030005   ?32?
 Top Overlay        = 1030006   33
 Bottom Overlay     = 1030007   34
 Top Paste          = 1030008   35
 Bottom Paste       = 1030009   36
 Top Solder         = 103000A   37
 Bottom Solder      = 103000B   38
 IPlane1            = 1010001   39
 Dielectric1        = 1040001   2010001
 Mech Layer 1       = 1020001   57

Stack export file.
// LAYER_V8_2LAYERID=16973824                              1030000 hex
// LAYER_V8_2ID={6E475535-500B-4A5B-B8EE-FE219503AF87}
// LAYER_V8_2TYPEID={B0827674-798C-4CF8-807C-8E6C2A11C145}
// LAYER_V8_2ISSURFACEFINISH=True|
// LAYER_V8_2NAME=Top Surface Finish
// LAYER_V8_2ISHIDDEN=False
// LAYER_V8_2USEDBYPRIMS=False
// LAYER_V8_2ISADVANCED=True
// LAYER_V8_2$LSM$Material=Nickel, Gold
// LAYER_V8_2$LSM$Process=ENIG|
// LAYER_V8_2$LSM$Thickness=1.5748mil
// LAYER_V8_2$LSM$Material.Color=#FFFFC400
// LAYER_V8_2_{6A9FF12B-A611-4ECE-8D99-90921FD624DF}CONTEXT=0|
// LAYER_V8_2_{6A9FF12B-A611-4ECE-8D99-90921FD624DF}USEDBYPRIMS=False|
// LAYER_V8_2_{6A9FF12B-A611-4ECE-8D99-90921FD624DF}NAME=Top Surface Finish
// LAYER_V8_2_{6A9FF12B-A611-4ECE-8D99-90921FD624DF}SHARED=0

{
Try Fix stack mess with:
 LayerObject.SetState_LayerID()
 LayerObject.SetState_LayerID(Layer7)   DNW with V6 or V7 LO.

 LO.LayerID;        returns zero for dieletric layers.
 LO.V7_LayerID.ID;  always works
..................................................................................}

{.................................................................................}
const
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;     // scripting API has broken consts from TV6_Layer
    AD19MaxMechLayers = 1024;
    NoMechLayerKind   = 0;      // enum const does not exist for AD17/18
    cPasteThick       = 4       // std stencil (mil)

    cPhysicalLSOnly   = false;  // true;   // only report the physical class.
    cCheckLayerNames  = false;  // but can NOT change short & mid names of signal, plane & dielectric.

    NewStackPcbFileName = 'StackReOrder.PcbDoc';

var
    PCBSysOpts     : IPCB_SystemOptions;
    PCBLib         : IPCB_Library;
    Board          : IPCB_Board;
    MLayerStack    : IPCB_MasterLayerStack;
    MechLayer      : IPCB_MechanicalLayer;
    MechLayer2     : IPCB_MechanicalLayer;
    MechLayerKind  : TMechanicalKind;
    MLayerKindStr  : WideString;
    MechLayerPairs : IPCB_MechanicalLayerPairs;
    MechLayerPair  : TMechanicalLayerPair;
    MechPairIndex  : integer;
    VerMajor       : integer;
    LegacyMLS      : boolean;
    MaxMechLayers  : integer;
    Layer          : TLayer;
    Layer7         : TV7_Layer;
    Layer6         : TV6_Layer;
    LOAddr         : long;
    ML1, ML2       : integer;
    slMechPairs    : TStringList;
    TempS          : TStringList;
    ReportLog   : TStringList;
    BOrigin     : TCoordPoint;

function LayerClassName (LClass : TLayerClassID) : WideString;                  forward;
function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;       forward;
function LayerKindToStr(LK : TMechanicalLayerKind) : WideString;                forward;
function FindAllMechPairLayers(LayerStack : IPCB_MasterLayerStack;, MLPS : IPCB_MechanicalLayerPairs) : TStringList; forward;
function GetLayerSetCamViewNumber(Layer : Tlayer) : integer;                                 forward;
function GetLayerFromLayerObject(LS: IPCB_LayerStack, LayerObj : IPCB_LayerObject) : TLayer; forward;
function FindInLayerClass(AStack : IPCB_LayerStack, LayerObj : IPCB_LayerObject, const LayerClass : TLayerClassID) : integer;           forward;
function GetLayerObjectFromShortName(LS : IPCB_LayerStack, const LayerClass : TLayerClassID, const SN : WideString) : IPCB_LayerObject; forward;
procedure ReportDrillPairs(Board : IPCB_Board, SubStack : IPCB_LayerStack);                  forward;
function DrillTypeToStr(DType : TDrillLayerPairType) : Widestring;                           forward;
function RemoveLayers(AStack : IPCB_LayerStack, const LayerClass : TLayerClassID) : integer; forward;
function GetLoadPcbDocByPath(LibPath : Widestring, const Load : boolean) : IPCB_Board;       forward;
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) :IPCB_MechanicalLayer;          forward;
function GetMechLayerObjectFromLID7(LS: IPCB_MasterLayerStack, var I : integer, MLID : TLayer) : IPCB_MechanicalLayer; forward;


procedure MakeNewLayerStackCopy;
var
    ServDoc    : IServerDocument;
    NewBrd     : IPCB_Board;
    NewMLS     : IPCB_MasterLayerStack;
    NewLO      : IPCB_LayerObject;
    RefLO      : IPCB_LayerObject;
    LayerObj   : IPCB_LayerObject;
    BrdPath    : WideString;
    LayerClass : TLayerClassID;
    LS         : IPCB_LayerSet;
    LSI        : IPCB_LayerIterator;
    Layer      : TLayer;
    NewLayer   : TLayer;
    IsPlane    : boolean;
    IsSignal   : boolean;
    PN, DI, SI : integer;
    Start, Stop : boolean;
    OShortLName : Widestring;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then exit;
    if Board = nil then exit;

    MLayerStack := Board.MasterLayerStack;
    BOrigin     := Point(Board.XOrigin, Board.YOrigin);
    BrdPath     := ExtractFilePath(Board.FileName);
    if BrdPath = '' then BrdPath := 'c:\temp\';

    ReportLog := TstringList.Create;

// create new PcbDoc.
    ServDoc := CreateNewDocumentFromDocumentKind(cDocKind_Pcb);
    ServDoc.DoSafeChangeFileNameAndSave(BrdPath + NewStackPcbFileName, cDocKind_Pcb);
    if (ServDoc <> nil) then
        NewBrd := GetLoadPcbDocByPath(ServDoc.FileName, false);

    NewBrd.BeginModify;
    NewMLS := NewBrd.MasterLayerStack;
    NewMLS.SetState_LayerStackStyle(eLayerStackCustom);

// do NOT remove any layers outside of Top & Bottom Copper as can NOT create masks/overlay

    LS := LayerSetutils.CreateLayerSet;
    LS.Include(eTopSolder);
    LS.Include(eBottomSolder);
    LS.Include(eTopOverlay);
    LS.Include(eBottomOverlay);
    LSI := LS.LayerIterator;
    LSI.SetBeforefirst;
    while LSI.Next do
    begin
        Layer    := LSI.Layer;
        RefLO    := MLayerStack.LayerObject(Layer);
        LayerObj := NewMLS.LayerObject(Layer);
        if not RefLO.IsInLayerStack then
        begin
            NewMLS.RemoveLayer(LayerObj);
        end else
        begin
            if (Layer = eTopSolder) or (Layer = eBottomSolder) then
            begin                     //   RefLO.DielectricType
                LayerObj.DielectricHeight   := RefLO.DielectricHeight;
                LayerObj.DielectricMaterial := RefLO.DielectricMaterial;
                LayerObj.DielectricConstant := RefLO.DielectricConstant;
            end;
        end;
    end;

// tbd surface finish   customData ??
// methods may all be read-only, may need to write xml file.
// LSP := GetLayerStackProvider(Board);
// LSI := LSP.GetLayerStackInfo(i)
// Process Material Material.Color Thickness

    ReportLog.Add('O:NLID   OName  NewName  IsSig IsPl SI PN DI   ');

    LayerClass := eLayerClass_Physical;
// build all above bottom copper layer.
    Start := false; Stop := false;
    PN := 0; DI := 0; SI:= 0;
    RefLO := NewMLS.LayerObject(eBottomLayer);
    LayerObj := MLayerStack.First(LayerClass);
    While LayerObj <> nil do
    begin
        Layer     := LayerObj.V7_LayerID.ID;
        IsPlane   := LayerUtils.IsInternalPlaneLayer(Layer);
        IsSignal  := LayerUtils.IsSignalLayer(Layer);
        Layerutils.IsMidLayer(Layer);
        LayerObj.Name;

        NewLO := NewMLS.LayerObject(Layer);
//        NewBrd.LayerColor(LayerObj.V6_LayerID) := Board.LayerColor(LayerObj.V6_LayerID);

        Case Layer of
        eTopLayer :
            begin
                inc(SI);
                Start := true;
                NewLO := NewMLS.LayerObject(Layer);
                NewLO.Name               := LayerObj.Name;
                NewLO.ComponentPlacement := LayerObj.ComponentPlacement;
                NewLO.CopperThickness    := LayerObj.CopperThickness;
                if not LegacyMLS then
                begin
                    NewLO.CopperOrientation := LayerObj.CopperOrientation;
//                    NewLO.Weight := LayerObj.Weight;
                end;
            end;
        eBottomLayer :
            begin
                inc(SI);
                Stop := true;
                NewLO := NewMLS.LayerObject(Layer);
                NewLO.Name               := LayerObj.Name;
                NewLO.ComponentPlacement := LayerObj.ComponentPlacement;
                NewLO.CopperThickness    := LayerObj.CopperThickness;
                if not LegacyMLS then
                begin
                    NewLO.CopperOrientation := LayerObj.CopperOrientation;
//                    NewLO.Weight := LayerObj.Weight;
                end;
            end;
        else
            if Start and (not Stop) then
            begin
                if IsSignal then
                begin
                    inc(SI);
                    NewLO := NewMLS.FirstAvailableSignalLayer;
                    NewMLS.InsertInStackAbove(RefLO, NewLO);
                    NewLO.Name               := LayerObj.Name;
                    NewLO.ComponentPlacement := LayerObj.ComponentPlacement;
                    NewLO.CopperThickness    := LayerObj.CopperThickness;
                    if not LegacyMLS then
                    begin
                        NewLO.CopperOrientation := LayerObj.CopperOrientation;
//                        NewLO.Weight := LayerObj.Weight;
                    end;
                end;

                if IsPlane then
                begin
                    inc(PN);
                    NewLayer := LayerUtils.FromShortDisplayString('P' + IntToStr(PN) );
                    NewLO := NewMLS.FirstAvailableInternalPlane;
                    NewMLS.InsertInStackAbove(RefLO, NewLO);
//                    NewLO := NewMLS.LayerObject(NewLayer);
                    NewLO.Name             := LayerObj.Name;
                    NewLO.CopperThickness  := LayerObj.CopperThickness;
                    if not LegacyMLS then
                    begin
                        NewLO.CopperOrientation := LayerObj.CopperOrientation;
//                        NewLO.Weight := LayerObj.Weight;
                    end;
                    NewLO.PullBackDistance := LayerObj.PullBackDistance;
                    NewLO.NetName          := LayerObj.Netname;     // meaningless with IPCB_SplitPlanes
                end;

// dielectrics automatically inserted with copper.
                if true then
                if not(IsPlane or IsSignal) then
                begin
                    inc(DI);
                    NewLayer := LayerUtils.FromShortDisplayString('D' + IntToStr(DI) );
                    NewLO := GetLayerObjectFromShortName(NewMLS, eLayerClass_Dielectric, 'D'+IntToStr(DI));
                    if NewLO = nil then
                    begin
// can NOT create dielectric directly; add dummy copper & then delete!
                        NewLO := NewMLS.FirstAvailableSignalLayer;
                        NewMLS.InsertInStackAbove(RefLO, NewLO);
                        NewMLS.RemoveLayer(NewLO);

                        NewLO := GetLayerObjectFromShortName(NewMLS, eLayerClass_Dielectric, 'D'+IntToStr(DI));
                    end;
//   copy props
                    NewLO.SetState_DielectricType( LayerObj.DielectricType );
                    NewLO.DielectricHeight   := LayerObj.DielectricHeight;
                    NewLO.SetState_DielectricMaterial( LayerObj.DielectricMaterial );
                    NewLO.DielectricConstant := LayerObj.DielectricConstant;
                end;

            end;
        end;  //case

        OShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);

        ReportLog.Add(IntToStr(Layer) + ' | ' + IntToStr(NewLO.V7_LayerID.ID) + ' | ' + LayerObj.Name + ' | ' + NewLO.Name +
                      ' | ' + BoolToStr(IsSignal, true) + ' | ' + BoolToStr(IsPlane, true) + ' | ' + IntToStr(SI) +
                      ' | ' + IntToStr(PN) + ' | ' + IntToStr(DI) );

        LayerObj := MLayerStack.Next(LayerClass, LayerObj);
    end;

    NewBrd.GraphicallyInvalidate;
    NewBrd.EndModify;

   ReportLog.SaveToFile(BrdPath + 'newstackreport.txt');
   ReportLog.Free;
end;

function FindBoardStackRegions(Board : IPCB_Board) : TObjectList;
var
    BIterator : IPCB_BoardIterator;
    SR        : IPCB_Region;
    LS        : IPCB_LayerSet;
//    BRM       : IPCB_BoardRegionsManager;
    BR        : IPCB_BoardRegion;
    i         : integer;

begin
//  Default BOL Multilayer Stack Region, PCBLib has none.
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    LS := LayerSetUtils.CreateLayerSet.Include(eMultiLayer);
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_IPCB_LayerSet(LS);
    BIterator.AddFilter_ObjectSet(MkSet(eRegionObject));
    SR := Biterator.FirstPCBObject;
    while SR <> nil do
    begin
       if SR.ViewableObjectID = eViewableObject_BoardRegion then 
            Result.Add(SR);

        SR := Biterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);

{   BRM := Board.BoardRegionsManager;
    BRM := IPCB_BoardRegionsManager;
    for i := 0 to (BRM.BoardRegionCount - 1) do
    begin
        BR := BRM.BoardRegion(i);
        BR.LayerStack.Name;    // match to get LS vs BR name
    end;
}
end;

// only called is const cCheckLayerNames is true
// fixing short & mid is not possible yet.
procedure CheckShortMidLayerNames(StackIndex: integer, SubStack : IPCB_LayerStack);
var
    LayerObj    : IPCB_LayerObject;
    LayerClass  : TLayerClassID;
    LC1, LC2    : TLayerClass;
    i           : Integer;

    LayerPos    : WideString;
    OShortLName  : WideString;
    OMidLName    : WideString;
    ShortLName  : WideString;
    MidLName    : WideString;
    LongLName   : WideString;
    IsPlane     : boolean;
    IsSignal    : boolean;
    LAddress    : integer;
    LIndex     : integer;

begin
    i := 1;
// signal layers
// TL   TOP Top Layer
// 1    Mid-1   Mid Layer 1

    TempS.Add('Signals');
    LIndex  := 0;
    LayerClass := eLayerClass_Signal;
    LayerObj := SubStack.First(LayerClass);

    While (LayerObj <> Nil ) do
    begin
//        Layer := LayerObj.LayerID;  // zero for dielectrics
        Layer := LayerObj.V7_LayerID.ID;
        LayerObj.IsInLayerStack;       // check always true.

        LAddress := GetLayerSetCamViewNumber(Layer);
        Inc(LIndex);
        LayerPos  := IntToStr(Board.LayerPositionInSet(AllLayers, LayerObj));

   //     TLayernameDisplayMode: eLayerNameDisplay_Short/Medium/Long
        OShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
        OMidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
        LongLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

        if (Layer <> eTopLayer) and (Layer <> eBottomLayer) then
        begin
            ShortLName := IntToStr(LIndex-1);
            MidLName   := 'Mid-' + IntToStr(Lindex-1);
//            LayerObj.SetState_LayerDisplayName_Short(ShortLName);
//            LayerUtils.AsShortDisplayString(LIndex) := ShortLName;
//            LayerObj.SetState_LayerDisplayName(eLayerNameDisplay_Medium) := MidLName;

            if OShortLName <> ShortLName then
                TempS.Add('bad short name');
            if oMidLName <> MidLName then
                TempS.Add('bad mid name');
        end;

        TempS.Add(Padright(IntToStr(LayerClass) + '.' + IntToStr(LIndex),5) + ' | ' + PadRight(LayerPos,3) + ' ' + PadRight(LayerObj.Name, 20)
                      + PadRight(OShortLName, 5) + ' ' + PadRight(OMidLName, 13) + '  ' + PadRight(LongLName, 15)
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadLeft(IntToStr(Layer), 9) + ' '
                      + ' LP:' + IntToStr(LAddress) + ':' + IntToHex(LAddress,7) );

            LayerObj := SubStack.Next(Layerclass, LayerObj);
        Inc(i);
    end;

// Plane layers:
// P1   Plane-1  "user name"

    TempS.Add('Planes');
    LIndex := 0;
    LayerClass := eLayerClass_InternalPlane;
    LayerObj := SubStack.First(LayerClass);

    While (LayerObj <> Nil ) do
    begin
        Layer := LayerObj.V7_LayerID.ID;
        LayerObj.IsInLayerStack;       // check always true.

        LAddress := GetLayerSetCamViewNumber(Layer);
        Inc(LIndex);
        LayerPos  := IntToStr(Board.LayerPositionInSet(AllLayers, LayerObj));

        OShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
        OMidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
        LongLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

        ShortLName := 'P'+IntToStr(LIndex);
        MidLName   := 'Plane-' + IntToStr(LIndex);
        if OShortLName <> ShortLName then
            TempS.Add('bad short name');
        if oMidLName <> MidLName then
            TempS.Add('bad mid name');

        TempS.Add(Padright(IntToStr(LayerClass) + '.' + IntToStr(LIndex),5) + ' | ' + PadRight(LayerPos,3) + ' ' + PadRight(LayerObj.Name, 20)
                      + PadRight(OShortLName, 5) + ' ' + PadRight(OMidLName, 13) + '  ' + PadRight(LongLName, 15)
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadLeft(IntToStr(Layer), 9)
                      + ' GI:' + IntToStr(LAddress) + ':' + IntToHex(LAddress,7) );

        LayerObj := SubStack.Next(Layerclass, LayerObj);
        Inc(i);
    end;

// Dielectric layers:
// D1   Dielectric-1  "user name"

    TempS.Add('Dielectric Layers');
    LIndex := 0;
    LayerClass := eLayerClass_Dielectric;
    LayerObj := SubStack.First(LayerClass);

    While (LayerObj <> Nil ) do
    begin
        Layer := LayerObj.V7_LayerID.ID;
        LayerObj.IsInLayerStack;       // check always true.

        LAddress := GetLayerSetCamViewNumber(Layer);
        LayerPos  := IntToStr(Board.LayerPositionInSet(AllLayers, LayerObj));

        OShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
        OMidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
        LongLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

        if LayerObj.DielectricType <>  eSurfaceMaterial then
        begin
            Inc(LIndex);
            ShortLName := 'D'+IntToStr(LIndex);
            MidLName   := 'Dielectric-' + IntToStr(Lindex);
            if OShortLName <> ShortLName then
                TempS.Add('bad short name');
            if oMidLName <> MidLName then
                TempS.Add('bad mid name');
        end;

        TempS.Add(Padright(IntToStr(LayerClass) + '.' + IntToStr(LIndex),5) + ' | ' + PadRight(LayerPos,3) + ' ' + PadRight(LayerObj.Name, 20)
                      + PadRight(OShortLName, 5) + ' ' + PadRight(OMidLName, 13) + '  ' + PadRight(LongLName, 15)
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadLeft(IntToStr(Layer), 9) + ' '
                      + ' GI:' + IntToStr(LAddress) + ':' + IntToHex(LAddress,7) );

        LayerObj := SubStack.Next(Layerclass, LayerObj);
        Inc(i);
    end;
end;

function LayerInLayerSet(LO : IPCB_LayerObj, LS : IPCB_LayerSet) : TLayer;
var
    LSI  : IPCB_LayerIterator;
    TLO  : IPCB_LayerObject;
    good : boolean;
begin
    Result := 0;
    if not LS.Isfinite then exit;

    LS.SerializeToString;
    LSI := LS.LayerIterator;
    good := LSI.First;
    LSI.SetBeforeFirst;
    while LSI.Next do
    begin
        if LO = LSI then
            Result := LSI.Layer;
        LO;            // LO.I_ObjectAddress;
    end;
//    LS.Contains(39);
end;

procedure ReportSubStack(StackIndex: integer, SubStack : IPCB_LayerStack, const LSKind : WideString);
var
    LayerObj    : IPCB_LayerObject;
    LayerClass  : TLayerClassID;
    LC1, LC2    : TLayerClass;
    Dielectric  : IPCB_DielectricLayer;
    Copper      : IPCB_ElectricalLayer;
    Plane       : IPCB_InternalPlane;
    i           : Integer;
    temp        : integer;
    LOUUID      : WideString;
    LayerPos    : integer;
    LayerPosS   : WideString;
    Thickness   : WideString;
    DieType     : TDielectricType;
    DieTypeS    : WideString;
    DieMatl     : WideString;
    DieConst    : WideString;
    LColour     : WideString;
    ShortLName  : WideString;
    MidLName    : WideString;
    LongLName   : WideString;
    IsPlane     : boolean;
    IsSignal    : boolean;
    IsDisplayed : boolean;
    TotThick    : TCoord;
    Thick       : TCoord;
    LAddress    : integer;
    LSLIndex    : integer;
    LS          : IPCB_LayerSet;

begin

    TempS.Add(' Layers in ' + LSKind + ': ' + IntToStr(SubStack.Count) );
    TempS.Add('  is flex layer? :    '    + BoolToStr(SubStack.IsFlex, true) );
    TempS.Add('');
    TempS.Add(' ----- LayerStack(eLayerClass) ------');

    TotThick := 0;

// LayerClass methods    Mechanical is strangely absent/empty.
    LC1 := eLayerClass_All;
    LC2 := eLayerClass_PasteMask;

    if (cPhysicalLSOnly) then
    begin
           LC1 := eLayerClass_Physical;
           LC2 := LC1;
    end;

    LS := Board.ElectricalLayers;  // IPCB_Layerset

    for LayerClass := LC1 to LC2 do
    begin
        TempS.Add('eLayerClass ' + IntToStr(LayerClass) + '  ' + LayerClassName(LayerClass));
        if (LayerClass = eLayerClass_Dielectric) or (LayerClass = eLayerClass_SolderMask) then
            TempS.Add('lc.i  |     LO name             short mid            Plane  Displayed  Colour     V7_LID   Used? Dielectric : Type    Matl    Thickness  Const ')
        else if (LayerClass = eLayerClass_Electrical) or (LayerClass = eLayerClass_Signal)
             or (LayerClass = eLayerClass_PasteMask) or (LayerClass = eLayerClass_InternalPlane) then
            TempS.Add('lc.i  | Pos LO name             short mid            Plane  Displayed  Colour     V7_LID   Used?                              Thickness (Cu) ')
        else
            TempS.Add('lc.i  |     LO name             short mid            Plane  Displayed  Colour     V7_LID   Used? ');

        i := 1;
        LayerObj := SubStack.First(LayerClass);

        While (LayerObj <> Nil ) do
        begin

            LOUUID := '';
            if not LegacyMLS then LOUUID := LO.Id;
 
            Layer  := GetLayerFromLayerObject(SubStack, LayerObj);
            Layer7 := LayerObj.V7_LayerID.ID;
//            Board.LayerStack.LayerObject(Layer7).SetState_LayerID(Layer7);

//            LayerObj.SetState_V7_LayerID(Layer7);

            LayerObj.IsInLayerStack;       // check always true.
// fight to get gerber index layer numbers.
            LSLIndex := GetLayerSetCamViewNumber(Layer);
            LAddress := LSLIndex;

            LayerPos  := 0; LayerPosS := '';
            Thick     := 0; Thickness := '';
            DieType   := -1;
            DieTypeS  := '';
            DieMatl   := '';
            DieConst  := '';     // as string for simplicity of reporting

            IsPlane  := LayerUtils.IsInternalPlaneLayer(Layer);
            IsSignal := LayerUtils.IsSignalLayer(Layer);

{            LayerUtils.IsElectricalLayer(27);            // AD17 Mid Layer26
            LayerUtils.AsString(196608);  // 16973824); // 33619963);
            LayerUtils.FromString('Top Surface Finish');  // AD17=0
}
            if false then
            for I:= 2010000 to 2020000 do
            begin
                DieMatl := LayerUtils.AsString(I);
                if DieMatl <> 'No Layer' then
                    Showmessage(IntToHex(I,7) + ' ' + DieMatl);
            end;

            if IsSignal or LayerUtils.IsElectricalLayer(Layer) or IsPlane then
            begin
                Copper    := LayerObj;
                if not LegacyMLS then
                    Copper.CopperOrientation;
                Thick     := Copper.CopperThickness;
                Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
                DieMatl := 'foil';
                DieTypeS := 'copper';

            //  only applies to eLayerClass_Electrical   ret zero for InternalPlanes - set not right
                LayerPos  := Board.LayerPositionInSet(AllLayers, LayerObj);  // AllLayers
                if IsPlane then
                begin
                    Plane := LayerObj;
                    Plane.PullBackDistance;  //  Plane.NetName;
                end;
            end
            else if (Layer = eTopPaste) or (Layer = eBottomPaste) then
            begin            // TPasteMaskLayerAdapter()
                Thick     := LayerObj.CopperThickness;   // nonsense default value
                Thick     := MilsToCoord(cPasteThick);
                Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
            end
            else if (Layer = eTopOverlay) or (Layer = eBottomOverlay) then
            begin
                 Thick     := MilsToCoord(0.2);
                 Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
            end else
            begin   // dielectrics     eNoDie.. eSurfaceMaterial eCore ePrepreg
                Dielectric := LayerObj;  //       IPCB_DielectricLayer
                DieType := Dielectric.DielectricType;
                DieTypeS   := kDielectricTypeStrings(DieType);
                if (DieType = eNoDielectric)    then DieTypeS := 'undefined';
                if (DieType = eSurfaceMaterial) then DieTypeS := 'Surface';
                if (DieType = ePrePreg)         then DieTypeS := 'Pre-Preg';
                if DieType  = eCore             then DieTypeS := 'Core';
                Thick     :=  Dielectric.DielectricHeight;
                Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
                DieMatl   := Dielectric.DielectricMaterial;
                DieConst  := FloatToStr(Dielectric.DielectricConstant);
//                if not LegacyMLS then
//                if (Layer = eTopSolder) or (Layer = eBottomSolder) then
//                    Dielectric.CoverlayExpansion;  //CustomData

            end;

//      sum class Physical thickness but do not sum pastemask..
            if (LayerClass = eLayerClass_Physical) then
            begin
                if (Layer = eTopPaste) or (Layer = eBottomPaste) then
                    Thick := 0;
                TotThick := TotThick + Thick;
            end;

//          TLayernameDisplayMode: eLayerNameDisplay_Short/Medium/Long
            ShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
            MidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
//   LongLname is same as LO.Name
            LongLName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

            IsDisplayed := Board.LayerIsDisplayed(Layer);
       //     ColorToString(Board.LayerColor(Layer]));   // TV6_Layer
            LColour := ColorToString(PCBSysOpts.LayerColors(Layer));
            if LayerPos > 0 then
            begin
                LayerPosS := IntToStr(LayerPos);
                Board.LayerName(LayerPos);
            end;

            TempS.Add(Padright(IntToStr(LayerClass) + '.' + IntToStr(i),5) + ' | ' + PadRight(LayerPosS,3) + ' ' + PadRight(LayerObj.Name, 20)
                      + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 13) // + '  ' + PadRight(LongLName, 20)
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadRight(BoolToStr(IsDisplayed,true), 6) + '  ' + PadRight(LColour, 12)
                      + PadLeft(IntToStr(Layer), 9) + ' ' + PadRight(BoolToStr(LayerObj.UsedByPrims, true), 6)
                      + PadRight(DieTypeS, 15) + PadRight(DieMatl, 15) + PadRight(Thickness, 10) + PadRight(DieConst,5) + ' GI:' + IntToStr(LAddress) + ':' + IntToHex(LAddress,7)
                      + ' | ' + LOUUID );

            LayerObj := SubStack.Next(Layerclass, LayerObj);
            Inc(i);
        end;
    end;

    TempS.Add('');
    TempS.Add(LSKind + IntToStr(StackIndex + 1) + ': Total Thickness : ' + CoordUnitToStringWithAccuracy(ToTThick, eMetric, 3, 4) );
end;

Procedure LayerStackInfoTest;
var
    BR          : IPCB_BoardRegion;
    SubStack    : IPCB_LayerStack;
    LIterator   : IPCB_LayerObjectIterator;
    LayerObj    : IPCB_LayerObject;
    Dielectric  : IPCB_DielectricObject;
    LayerName   : WideString;
    ShortLName  : WideString;
    MidLName    : WideString;
    LongLName   : WideString;
    IsDisplayed : boolean;
    LayerKind   : WideString;
    LSR         : TObjectList;
    LowLayer, HighLayer : IPCB_LayerObject;
    LowPos,   HighPos   : integer;
    i, j, k     : integer;
    FileName    : String;
    XLayers     : string;
    LSLIndex    : integer;
    Layer6      : TV6Layer;
    slCustom    : TStringList;
    LSP         : IPCB_LayerStackProvider;
    LSFI        : ILayerStackFeatureInfo;
    LSI         : ILayerStackInfo;
    LayerInfo   : ILayerInfo;
    LSLProperty : WideString;
    LSCPValue   : WideString;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
    if Board = nil then exit;

    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0); // Version(true).Strings(0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    MechLayerKind := NoMechLayerKind;
    if (VerMajor >= AD19VersionMajor) then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName);

    MLayerStack := Board.MasterLayerStack;

//    XLayers := WideStrAlloc(10000);
//    MLayerStack.Export_ToParameters(XLayers);

    LSR := FindBoardStackRegions(Board);

    slMechPairs := TStringList.Create;
    TempS       := TStringList.Create;
    TempS.Add('Altium Version: ' + Client.GetProductVersion);
    TempS.Add('');
    TempS.Add('-- Master Stack Info -- ');
    TempS.Add('Board filename: ' + ExtractFileName(Board.FileName) );
    TempS.Add('');
{ Type: TLayerStackStyle
  eLayerStack_Pairs
  eLayerStacks_InsidePairs
  eLayerStackBuildup
  eLayerStackCustom
}
    if PCBLib <> nil then
    begin
        SubStack := Board.MasterLayerStack;
        TempS.Add('Layer Stack: ' + PadRight(SubStack.Name, 30) + '  ID: ' + SubStack.ID);
        ReportSubStack(0, SubStack, 'LayerStack');
    end else
    begin
        TempS.Add('Stack Regions: ' + IntToStr(LSR.Count) );
        for i := 0 to (LSR.Count - 1) do
        begin
            BR := LSR.Items(i);
            BR.Descriptor;
            BR.HoleCount;
            BR.Identifier;
            BR.Index;
            BR.Detail;
            TempS.Add('Stack Region ' + IntToStr(i + 1) + '  name: ' + PadRight(BR.Name,30) + ' LS: DNK          area: ' + FormatFloat(',0.###', BR.Area / c1_00MM / c1_00MM) + ' sq.mm ' );
        end;

        TempS.Add('');

        TempS.Add('');
        TempS.Add('Number of Sub Stacks: ' + IntToStr(MLayerStack.SubstackCount) );
        for i := 0  to (MLayerStack.SubstackCount - 1) do
        begin
            SubStack := MLayerStack.SubStacks[i];
            TempS.Add('Sub Stack ' + IntToStr(i + 1) + '  name: ' + SubStack.Name + '  ID: ' + SubStack.ID);
            ReportSubStack(i, SubStack, 'SubStack');
            TempS.Add('');

            ReportDrillPairs(Board, SubStack);
            TempS.Add('');
        end;

        if (cCheckLayerNames) then
        for i := 0  to (MLayerStack.SubstackCount - 1) do
        begin
            SubStack := MLayerStack.SubStacks[i];
            TempS.Add('Checking short & mid layer names ');
            TempS.Add('Sub Stack ' + IntToStr(i + 1) + '  name: ' + SubStack.Name + '  ID: ' + SubStack.ID);
            CheckShortMidLayerNames(i, SubStack);
            TempS.Add('');
        end;
    end;

    TempS.Add('');
    TempS.Add('');
    TempS.Add('API Layers constants: (all obsolete)');
    TempS.Add('MaxRouteLayer = ' +  IntToStr(MaxRouteLayer) +' |  MaxBoardLayer = ' + IntToStr(MaxBoardLayer) );
    TempS.Add(' MinLayer = ' + IntToStr(MinLayer) + '   | MaxLayer = ' + IntToStr(MaxLayer) );
    TempS.Add(' MinMechanicalLayer = ' + IntToStr(MinMechanicalLayer) + '  | MaxMechanicalLayer =' + IntToStr(MaxMechanicalLayer) );
    TempS.Add('');
    TempS.Add(' ----- Mechanical Layers ------');
    TempS.Add('');
    TempS.Add('idx  LayerID   boardlayername       layername           short mid            long             kind              UsedByPrims ');


// whole lot of nothing.
    LayerObj := MLayerStack.First(eLayerClass_Mechanical);
    i := 0;
    While (LayerObj <> Nil ) do
    begin
       inc(i);
       LayerObj := MLayerStack.Next(eLayerClass_Mechanical, LayerObj);
    end;

    i := 0;
    LIterator := Board.MechanicalLayerIterator;
    LIterator.AddFilter_MechanicalLayers;
    LIterator.SetBeforeFirst;
    While LIterator.Next Do
    Begin
        Inc(i);
        LayerObj := LIterator.LayerObject;
        Layer    := LIterator.Layer;

/// V8 LayerID
        LSLIndex := GetLayerSetCamViewNumber(Layer);

        MechLayerKind := NoMechLayerKind;
        LayerName     := LayerObj.Name;

         // TLayernameDisplayMode: eLayerNameDisplay_Short / Medium / Long
        ShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
        MidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
        LongLName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);

        if not LegacyMLS then MechLayerKind := LayerObj.Kind;

        TempS.Add(PadRight(IntToStr(i), 3) + PadRight(Layer, 10) + ' ' + PadRight(Board.LayerName(Layer), 20)
                  + ' ' + PadRight(LayerName, 20) + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 12) + '  ' + PadRight(LongLName, 20)
                  + ' ' + PadRight(LayerKindToStr(MechLayerKind),18) + ' ' + PadRight(BoolToStr(LayerObj.UsedByPrims, true),8)  + ' GI:' + IntToStr(LSLIndex) + ':' + IntToHex(LSLIndex,7) );

    end;
    TempS.Add('');
    TempS.Add('');

//   no mech pairs in AD17 PcbLib
    if ((PCBLib = nil) and LegacyMLS) or (not LegacyMLS) then
    begin
        TempS.Add(' ----- MechLayerPairs -----');
        TempS.Add('');

        MechLayerPairs := Board.MechanicalPairs;

// is this list always in the same order as MechanicalPairs ??
        slMechPairs := FindAllMechPairLayers(MLayerStack, MechLayerPairs);

        TempS.Add('Mech Layer Pair Count : ' + IntToStr(MechLayerPairs.Count));
        TempS.Add('');
        if (MechLayerPairs.Count > 0) then
            TempS.Add('Ind  LNum1 : LayerName1     <--> LNmum2 : LayerName2 ');

        if slMechPairs.Count <> MechLayerPairs.Count then
            ShowMessage('Failed to find all Mech Pairs ');

        for MechPairIndex := 0 to (slMechPairs.Count -1 ) do
        begin
            ML1 := slMechPairs.Names(MechPairIndex);
            ML2 := slMechPairs.ValueFromIndex(MechPairIndex);

// bad assumption!
            MechLayerPair := MechLayerPairs.LayerPair[MechPairIndex];   // __TMechanicalLayerPair__Wrapper()

            LayerKind := '';
            if not LegacyMLS then
            begin
                LayerKind := 'LayerPairKind : ' + LayerPairKindToStr( MechLayerPairs.LayerPairKind(MechPairIndex) );
            end;

            TempS.Add(PadRight(IntToStr(MechPairIndex),3) + PadRight(IntToStr(ML1),3) + ' : ' + PadRight(Board.LayerName(ML1),20) +
                               ' <--> ' + PadRight(IntToStr(ML2),3) + ' : ' + PadRight(Board.LayerName(ML2),20) + LayerKind);
        end;
    end else
        TempS.Add(' no MechLayerPairs in this version ');

 //  broken because no wrapper function to handle TMechanicalLayerPair record.
{ LayerPair[I : Integer] property defines indexed layer pairs and returns a TMechanicalLayerPair record of two PCB layers.

  TMechanicalLayerPair = Record          // TCoordPoint/Rect are record; TPoint.x works.  TCoordRect.x1 works
    Layer1 : TLayer;
    Layer2 : TLayer;
  End;

try:-
  .LowLayer      DNW
  .HighLayer

//    StringToWideChar(XLayers, PWC, 5000);
//    MechLayerPairs.Export_ToParameters(PWC);
//    MechLayerPairs.LayerPair[0].LowLayer;   L0 LowerLayer
//    MechLayerPairs.LayerPairLayerStackID(0);
}

    I := 1;
    TempS.Add('');
    TempS.Add('idx Layer    Name      LOAddr');
    LayerObj := MLayerStack.First(eLayerClass_Electrical);
    while (LayerObj <> nil) do
    begin
        LOAddr := LayerObj.I_ObjectAddress;
        Layer7 := LayerObj.V7_LayerID.ID;
        Layer6 := LayerObj.V6_LayerID;

        TempS.Add(PadRight(IntToStr(I),3) + Padright(IntToStr(Layer7),4) + ' ' + IntToStr(Layer6) + ' ' + LayerObj.Name  + '  ' + IntToHex(LOAddr,7) );
        inc(I);
        LayerObj := MLayerStack.Next(eLayerClass_Electrical, LayerObj);
    end;

    TempS.Add('');
    if not LegacyMLS then
        LSP := GetLayerStackProvider(Board);
        for i := 0 to (LSP.GetLayerStackFeaturesCount - 1) do
        begin
            LSFI := LSP.GetLayerStackFeatures(i);         //ILayerStackFeatureInfo
            LSFI.GetState_GUID;
            LSFI.GetState_IsDefault;
            LSFI.GetState_IsHidden;
            LSFI.GetState_Name;
        end;

        TempS.Add('idx|  Name                   |  TypeID                                |  GUID                                   | Material ');
        for i := 0 to (LSP.GetLayerStacksCount - 1) do
        begin
            LSI := LSP.GetLayerStackInfo(i);              //ILayerStackInfo
            LSI.GetState_Name;
            LSI.GetState_TotalThickness;
            LSI.GetLayersCount;
            for j := 0 to (LSI.GetLayersCount - 1) do
            begin
                LayerInfo := LSI.GetLayerInfo(j);         // ILayerInfo
                TempS.Add(PadRight(LayerInfo.GetState_Number,3) + '|' + PadRight(LayerInfo.GetState_Name,25) + '|' + PadRight(LayerInfo.GetState_TypeId,40) + '|' + PadRight(LayerInfo.GetState_GUID,40) + ' | ' + LayerInfo.GetState_Material);
                for k := 0 to (LSI.GetLayerPropertiesCount - 1) do
                begin
                    LSLProperty := LSI.GetLayerProperty(k);
                    LSCPValue   := LayerInfo.GetState_CustomProperty(LSLProperty);
                    if LSCPValue <> '' then
                        TempS.Add(LSLProperty + '|' + LSCPValue);
                end;
            end;
            TempS.Add('');
        end;
    end;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    if ExtractFilePath(FileName) = '' then FileName := SpecialFolder_Temporary;
    FileName := ExtractFilePath(FileName) + '\layerstacktests.txt';

    TempS.SaveToFile(FileName);
    TempS.Free;
    slMechPairs.Free;

    if not LegacyMLS then
    begin
        slCustom := TStringList.Create;
        slCustom.Add(MLayerStack.GetState_CustomData);
        FileName := ExtractFilePath(FileName) + '\layerstackcustomdata.txt';
        slCustom.SaveToFile(FileName);
        slCustom.Free;
    end;
end;

{......................................................................................................................}
function LayerClassName (LClass : TLayerClassID) : WideString;
begin
//Type: TLayerClassID
    case LClass of
    eLayerClass_All           : Result := 'All';
    eLayerClass_Mechanical    : Result := 'Mechanical';
    eLayerClass_Physical      : Result := 'Physical';
    eLayerClass_Electrical    : Result := 'Electrical';
    eLayerClass_Dielectric    : Result := 'Dielectric';
    eLayerClass_Signal        : Result := 'Signal';
    eLayerClass_InternalPlane : Result := 'Internal Plane';
    eLayerClass_SolderMask    : Result := 'Solder Mask';
    eLayerClass_Overlay       : Result := 'Overlay';
    eLayerClass_PasteMask     : Result := 'Paste Mask';
    else                        Result := 'Unknown';
    end;
end;

function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;
begin
    case LPK of
    NoMechLayerKind : Result := 'Not Set';            // single
    1               : Result := 'Assembly';
    2               : Result := 'Coating';
    3               : Result := 'Component Center';
    4               : Result := 'Component Outline';
    5               : Result := 'Courtyard';
    6               : Result := 'Designator';
    7               : Result := 'Dimensions';
    8               : Result := 'Glue Points';
    9               : Result := 'Gold Plating';
    10              : Result := 'Value';
    11              : Result := '3D Body';

// Via IPC-4761
    15              : Result := 'Tenting';
    16              : Result := 'Covering';
    17              : Result := 'Plugging';
    else              Result := 'Unknown'
    end;
end;

function LayerKindToStr(LK : TMechanicalLayerKind) : WideString;
begin
    case LK of
    NoMechLayerKind : Result := 'Not Set';            // single
    1               : Result := 'Assembly Top';
    2               : Result := 'Assembly Bottom';
    3               : Result := 'Assembly Notes';     // single
    4               : Result := 'Board';
    5               : Result := 'Coating Top';
    6               : Result := 'Coating Bottom';
    7               : Result := 'Component Center Top';
    8               : Result := 'Component Center Bottom';
    9               : Result := 'Component Outline Top';
    10              : Result := 'Component Outline Bottom';
    11              : Result := 'Courtyard Top';
    12              : Result := 'Courtyard Bottom';
    13              : Result := 'Designator Top';
    14              : Result := 'Designator Bottom';
    15              : Result := 'Dimensions';         // single
    16              : Result := 'Dimensions Top';
    17              : Result := 'Dimensions Bottom';
    18              : Result := 'Fab Notes';         // single
    19              : Result := 'Glue Points Top';
    20              : Result := 'Glue Points Bottom';
    21              : Result := 'Gold Plating Top';
    22              : Result := 'Gold Plating Bottom';
    23              : Result := 'Value Top';
    24              : Result := 'Value Bottom';
    25              : Result := 'V Cut';             // single
    26              : Result := '3D Body Top';
    27              : Result := '3D Body Bottom';
    28              : Result := 'Route Tool Path';   // single
    29              : Result := 'Sheet';             // single
    30              : Result := 'Board Shape';
// Via IPC-4761
    37              : Result := 'Tenting Top';
    38              : Result := 'Tenting Bottom';
    39              : Result := 'Covering Top';
    40              : Result := 'Covering Bottom';
    41              : Result := 'Plugging Top';
    42              : Result := 'Plugging Bottom';
    43              : Result := 'Filling';
    44              : Result := 'Capping';
    else              Result := 'Unknown'
    end;
end;

// NOT possible to eliminate LayerObject_V7() with AD17.
function FindAllMechPairLayers(LayerStack : IPCB_MasterLayerStack, MLPS : IPCB_MechanicalLayerPairs) : TStringList;
// is this list always in the same order as MechanicalPairs ??
// no it is NOT & higher layer number can be top side layer !!
var
    Index      : integer;
    i, j       : integer;
begin
    Result := TStringList.Create;
    Result.StrictDelimiter := true;
    Result.Delimiter := '|';
    Result.NameValueSeparator := '=';

    for i := 1 to MaxMechLayers do
    begin
        MechLayer := GetMechLayerObject(LayerStack, i, ML1);

        if MechLayer.MechanicalLayerEnabled then
        begin
            for j := (i + 1) to MaxMechLayers do
            begin
                MechLayer2 := GetMechLayerObject(LayerStack, j, ML2);

                if MechLayer2.MechanicalLayerEnabled then
                if MLPS.PairDefined(ML1, ML2) then
                if (MLPS.LayerUsed(ML1) and MLPS.LayerUsed(ML2)) then
                    Result.Add(IntToStr(ML1) + '=' + IntToStr(ML2));
            end;
        end;
    end;
end;
                                                            // cardinal      V7 LayerID
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) : IPCB_MechanicalLayer;
begin
    if LegacyMLS then
    begin
        MLID := LayerUtils.MechanicalLayer(i);
        Result := LS.LayerObject_V7(MLID)
    end else
    begin
        Result := LS.GetMechanicalLayer(i);
        MLID := Result.V7_LayerID.ID;       // .LayerID returns zero for dielectric
    end;
end;
                                                            // cardinal      V7 LayerID
function GetMechLayerObjectFromLID7(LS: IPCB_MasterLayerStack, var I : integer, MLID : TLayer) : IPCB_MechanicalLayer;
var
    AMLID      : TLayer;
    AMechLayer : IPCB_MechanicalLayer;
    J          : integer;
begin
    Result := nil;
    AMLID  := 0;
    for J := 1 to MaxMechLayers do
    begin
        AMechLayer :=  GetMechLayerObject(LS, J, AMLID);
        if AMLID <> MLID then continue;

        I := J;                // return cardinal index
        Result := AMechLayer;
        break;
    end;
end;

function GetLayerObjectFromShortName(LS : IPCB_LayerStack, const LayerClass : TLayerClassID, const SN : WideString) : IPCB_LayerObject;
var
    LayerObj   : IPCB_LayerObject;
begin
    Result := nil;
    LayerObj := LS.First(LayerClass);
    While LayerObj <> nil do
    begin
        if SN = LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short) then
            Result := LayerObj;
        LayerObj := LS.Next(LayerClass, LayerObj);
    end;
end;

function FindInLayerClass(AStack : IPCB_LayerStack, LayerObj : IPCB_LayerObject, const LayerClass : TLayerClassID) : integer;
var
   LO         : IPCB_LayerObject;
   Lindex     : integer;
begin
    Result := 0; Lindex := 0;
    LO := AStack.First(LayerClass);
    While (LO <> Nil ) do
    begin
        inc(Lindex);
        if LO = LayerObj then Result := Lindex;    // swap over order with line below!
        LO := AStack.Next(Layerclass, LO);
    end;
end;

function GetLayerFromLayerObject(LS : IPCB_LayerStack, LayerObj : IPCB_LayerObject) : TLayer;
var
    LIterator : IPCB_LayerIterator;
begin
    Result := 0;
    if FindInLayerClass(LS, LayerObj, eLayerClass_Signal) > 0 then
        LIterator := Board.SignalLayerIterator
    else if FindInLayerClass(LS, LayerObj, eLayerClass_InternalPlane) > 0 then
        LIterator := Board.InternalPlaneLayerIterator
    else if FindInLayerClass(LS, LayerObj, eLayerClass_Mechanical) > 0 then
        LIterator := Board.MechanicalLayerIterator
    else LIterator := Board.LayerIterator_IncludeNonEditable;

    LIterator.setBeforeFirst;
    While LIterator.Next Do
    Begin
        if LayerObj = LIterator.LayerObject then
        begin
            Result := LIterator.Layer;
            break;
        end;
    end;
end;

function RemoveLayers(LS : IPCB_LayerStack, const LayerClass : TLayerClassID) : integer;
var
   LO         : IPCB_LayerObject;
begin
    Result := 0;

    LO := LS.First(LayerClass);
    While (LO <> Nil ) do
    begin
        LS.RemoveLayer(LO);
        inc(Result);
        LO := LS.First(LayerClass);
//        LO := LS.Next(Layerclass, LO);
        if Result > 32 then break;
    end;
end;

function GetLoadPcbDocByPath(LibPath : Widestring, const Load : boolean) : IPCB_Board;
begin
    Result := PCBServer.GetPCBBoardByPath(LibPath);
    if Load then
    if Result = nil then
        Result := PcbServer.LoadPcbBoardByPath(LibPath);
end;

function GetLayerSetCamViewNumber(Layer : Tlayer) : integer;
var
    ALayerSet   : IPCB_LayerSet;
    slLayerSet  : TStringList;
    slLayerLine : TStringList;
    LSText      : WideString;
    Idx : integer;
begin
    Result := 0;
    slLayerSet := TStringList.Create;
    slLayerSet.Delimiter       := '_';
    slLayerSet.NameValueSeparator := '~';
    slLayerSet.StrictDelimiter := true;
    ALayerSet := LayerSetUtils.CreateLayerSet.Include(Layer);
    LSText := LayerSetUtils.SerializeToString(ALayerSet);
    slLayerset.DelimitedText := LSText;
    Idx := -1;
    Idx := slLayerSet.IndexofName('Standard.Include');
    if Idx < 0 then Idx := slLayerSet.IndexofName('Signal.Include');
    if Idx < 0 then Idx := slLayerSet.IndexofName('Dielectric.Include');
    if Idx < 0 then Idx := slLayerSet.IndexofName('Misc.Include');
    if Idx < 0 then Idx := slLayerSet.IndexofName('Internal.Include');
    if Idx < 0 then Idx := slLayerSet.IndexofName('Mechanical.Include');

    if Idx > -1 then
    begin
        LSText := slLayerSet.ValueFromIndex(Idx);
        slLayerLine := TStringList.Create;
        slLayerLine.Delimiter          := ',';
        slLayerLine.NameValueSeparator := '=';
        slLayerLine.StrictDelimiter    := true;
        slLayerLine.DelimitedText      := LSText;
        if slLayerLine.Count > 0 then
        begin
            Result := slLayerLine.Names(slLayerLine.Count-1);
        end;
        if Result = '' then Result := 0;
        slLayerLine.Free;
    end;
    slLayerSet.Free;
end;

procedure ReportDrillPairs(Board : IPCB_Board, SubStack : IPCB_LayerStack);
Var
    i            : Integer;
    DLayerPair   : IPCB_DrillLayerPair;
    DrillType    : TDrillLayerPairType;
    StartLayer   : IPCB_LayerObject;
    StopLayer    : IPCB_LayerObject;

    LowLayerObj  : IPCB_LayerObject;
    HighLayerObj : IPCB_LayerObject;
    LowPos       : Integer;
    HighPos      : Integer;
    CounterHole  : boolean;
    BackDrill    : boolean;
    Inverted     : boolean;
Begin
//        IPCB_board.GetState_LayerPairByPair();

    TempS.Add('Drill Pairs                              Type   Back  Counter ');
    For i := 0 To (Board.DrillLayerPairsCount - 1) Do
    Begin
        DLayerPair  := Board.LayerPair[i];

        if not DLayerPair.IsdefinedIn(SubStack.ID) then continue;

//        TempS.Add(DLayerPair.Substacks_ToString);

        Inverted := false; DrillType := eDrilledHole; CounterHole := false;
        if not LegacyMLS then
        begin
            DrillType   := DLayerPair.DrillLayerPairType;
            CounterHole := DLayerPair.IsCounterHole;
            Inverted    := DLayerPair.Inverted;
        end;
        Backdrill   := DLayerPair.IsBackdrill;

        if not Inverted then
        begin
            StartLayer := DLayerPair.StartLayer;
            StopLayer  := DLayerPair.StopLayer;
        end else
        begin
            StopLayer  := DLayerPair.StartLayer;
            StartLayer := DLayerPair.StopLayer;
        end;
        LowLayerObj  := SubStack.LayerObject[DLayerPair.LowLayer];
        HighLayerObj := SubStack.LayerObject[DLayerPair.HighLayer];

        LowPos       := Board.LayerPositionInSet(SetUnion( SignalLayers, InternalPlanes), StartLayer);
        HighPos      := Board.LayerPositionInSet(SetUnion(SignalLayers, InternalPlanes), StopLayer);

        TempS.Add(IntToStr(i+1) + ' | ' + IntToStr(LowPos)  + ':' + StartLayer.Name  + ' - ' + IntToStr(HighPos) + ':' + StopLayer.Name
                  +  ' ' + DrillTypeToStr(DrillType) + ' '+BoolToStr(BackDrill,true) + ' ' + BooltoStr(CounterHole, true) );

    End;
End;

function DrillTypeToStr(DType : TDrillLayerPairType) : Widestring;
begin
   Result := 'unknown';
   case Dtype of
      eDrilledHole       : Result := 'MechDrill';
      eLaserDrilledHole  : Result := 'Laser';
      ePunchedHole       : Result := 'Punched';
      ePlasmaDrilledHole : Result := 'Plasma';
   end;
end;

{
IPCB_LayerListIterator
    LIterator := LayerUtils.LayerIterator_PossibleLayers;
    LIterator.AddFilter_ElectricalLayers;
    LIterator.AddFilter_MiscLayers;
    LIterator.SetBeforeFirst;
    while LIterator.Next do
    begin
        I     := LIterator.Index;
        Layer := LIterator.Layer;
        ShowMessage(IntToStr(I) + ' ' + IntToStr(Layer) + ' ' + LayerUtils.AsString(Layer) );
    end;


// Use of LayerObject method to display specific layers
    Var
       Board      : IPCB_Board;
       Stack      : IPCB_LayerStack;
       LyrObj     : IPCB_LayerObject;
       Layer      : TLayer;

    Begin
       Board := PCBServer.GetCurrentPCBBoard;
       Stack := Board.LayerStack;
       for Lyr := eMechanical1 to eMechanical16 do
    // but eMechanical17 - eMechanical32 are NOT defined ffs.
       begin
          LyrObj := Stack.LayerObject[Lyr];
          If LyrObj.MechanicalLayerEnabled then ShowInfo(LyrObj.Name);
       end;
    End;
}
{ //copper layers     below is for drill pairs need to get top & bottom copper.
     LowLayerObj  : IPCB_LayerObject;
     HighLayerObj : IPCB_LayerObject;
     LowPos       : Integer;
     HighPos      : Integer;
     LowLayerObj  := PCBBoard.LayerStack.LayerObject[PCBLayerPair.LowLayer];
     HighLayerObj := PCBBoard.LayerStack.LayerObject[PCBLayerPair.HighLayer];
     LowPos       := PCBBoard.LayerPositionInSet(SignalLayers, LowLayerObj);
     HighPos      := PCBBoard.LayerPositionInSet(SignalLayers, HighLayerObj);
}
{
Function  LayerPositionInSet(ALayerSet : TLayerSet; ALayerObj : IPCB_LayerObject)  : Integer;
 ex. where do layer consts come from??            VV             VV
      LowPos  := PCBBoard.LayerPositionInSet( SignalLayers + InternalPlanes, LowLayerObj);
      HighPos := PCBBoard.LayerPositionInSet( SignalLayers + InternalPlanes, HighLayerObj);
}
{   V7 LS:
    TheLayerStack := PCBBoard.LayerStack_V7;
    If TheLayerStack = Nil Then Exit;
    LS       := '';
    LayerObj := TheLayerStack.FirstLayer;
    Repeat
        LS       := LS + Layer2String(LayerObj.LayerID) + #13#10;
        LayerObj := TheLayerStack.NextLayer(LayerObj);
    Until LayerObj = Nil;
}


