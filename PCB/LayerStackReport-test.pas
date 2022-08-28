{.................................................................................
 Summary   Used to test LayerClass methods in AD17-22 & report into text file.
           Works on PcbDoc & PcbLib files.

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

         tbd : find way to fix short & mid names if wrong.
                Use Layer Classes test in AD17 & AD19
                get the matching stack region names for each substack.
                IPCB_BoardRegionManager
                ILayerStackProvider / ILayerStackInfo / GUID
                Not convinced about Board.LayerPositionInSet(AllLayers, LayerObj) as TV6_LayerSet junk.

More crappy Altium mess.

Note: can report all mech layers in AD17-AD22
..................................................................................}

{.................................................................................}
const
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;     // scripting API has broken consts from TV6_Layer
    AD19MaxMechLayers = 1024;
    NoMechLayerKind   = 0;      // enum const does not exist for AD17/18
    cPasteThick       = 4       // std stencil (mil)

    cPhysicalLSOnly   = true;   // only report the physical class.
    cCheckLayerNames  = false;  // but can NOT change short & mid names of signal, plane & dielectric.

var
    PCBSysOpts     : IPCB_SystemOptions;
    PCBLib         : IPCB_Library;
    Board          : IPCB_Board;
    MasterStack    : IPCB_MasterLayerStack;
    MechLayer      : IPCB_MechanicalLayer;
    MechLayer2     : IPCB_MechanicalLayer;
    MechLayerKind  : TMechanicalKind;
    MLayerKindStr  : WideString;
    MechLayerPairs : IPCB_MechanicalLayerPairs;
    MechLayerPair  : TMechanicalLayerPair;
    MechPairIndex  : integer;
    VerMajor       : WideString;
    LegacyMLS      : boolean;
    MaxMechLayers  : integer;
    Layer          : TLayer;
    Layer7         : TV7_Layer;
    ML1, ML2       : integer;
    slMechPairs    : TStringList;
    TempS          : TStringList;

function LayerClassName (LClass : TLayerClassID) : WideString;                  forward;
function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;       forward;
function LayerKindToStr(LK : TMechanicalLayerKind) : WideString;                forward;
function Version(const dummy : boolean) : TStringList;                          forward;
function FindAllMechPairLayers(LayerStack : IPCB_LayerStack;, MLPS : IPCB_MechanicalLayerPairs) : TStringList; forward;
function GetLayerSetCamViewNumber(Layer : Tlayer) : integer;  forward;
procedure ReportDrillPairs(Board : IPCB_Board, SubStack : IPCB_LayerStack); forward;
function DrillTypeToStr(DType : TDrillLayerPairType) : Widestring;    forward;

// WIP
function IsInLayerClass(LayerObj : IPCB_LayerObject, LClass : TLayerClassID) : boolean;
var
   LayerClass : TLayerClassID;
begin
    for LayerClass := eLayerClass_All to eLayerClass_PasteMask do
    begin
        LayerObj;
    end;
end;

function FindBoardStackRegions(Board : IPCB_Board) : TObjectList;
var
    BIterator : IPCB_BoardIterator;
    SR        : IPCB_Region;
    LS        : IPCB_LayerSet;
    BRM       : IPCB_BoardRegionsManager;
    BR        : IPCB_BoardRegion;
    i         : integer;

begin
    Result := TObjectList.Create;
    Result.OwnsObjects := false;
    LS := LayerSetUtils.EmptySet;
    LS.Include(eMultiLayer);
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_IPCB_LayerSet(LS);
    BIterator.AddFilter_ObjectSet(MkSet(eRegionObject));
    SR := Biterator.FirstPCBObject;
    while SR <> nil do
    begin
    // one stack has BoardRegion kind NamedRegion = 2
    // but substack regions seem to be kind = 3  eRegionKind_BoardCutout ??
    //  Default Layer Stack Region
        if (SR.Kind = eRegionKind_NamedRegion) or (SR.Kind = 3) then
        if (SR.Name <> '') then          // kludge hack ?
            Result.Add(SR);
        SR.InBoard;
        SR := Biterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);

{
    BRM := Board.BoardRegionsManager;
    BRM := IPCB_BoardRegionsManager;
    for i := 0 to (BRM.BoardRegionCount - 1) do
    begin
        BR := BRM.BoardRegion(i);
        BR.LayerStack.Name;    // match to get LS vs BR name
    end;
} //    eBoardOutlineObject, eBoardRegionLayerStack,
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
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadLeft(IntToStr(Layer), 9) + ' '
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

procedure ReportSubStack(StackIndex: integer, SubStack : IPCB_LayerStack);
var
    LayerObj    : IPCB_LayerObject;
    LayerClass  : TLayerClassID;
    LC1, LC2    : TLayerClass;
    Dielectric  : IPCB_DielectricLayer;
    Copper      : IPCB_ElectricalLayer;
    i           : Integer;
    temp        : integer;

    LayerPos    : WideString;
    Thickness   : WideString;
    DieType     : WideString;
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

begin

    TempS.Add(' Layers in stack: '    + IntToStr(SubStack.Count) );
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
            Layer := LayerObj.V7_LayerID.ID;
            LayerObj.IsInLayerStack;       // check always true.
// fight to get gerber index layer numbers.
            LSLIndex := GetLayerSetCamViewNumber(Layer);
            LAddress := LSLIndex;

{               ILayerStackProvider;
                LSI := ILayerStackProvider.GetLayerStackInfo(j);
                LSI.IsLayerInLayerStack(Layer);
                LSI.GetLayerInfo(Layer).GetState_GUID;
}
            LayerPos  := '';
            Thick     := 0;
            Thickness := '';
            DieType   := '';
            DieMatl   := '';
            DieConst  := '';     // as string for simplicity of reporting

            IsPlane  := LayerUtils.IsInternalPlaneLayer(Layer);
            IsSignal := LayerUtils.IsSignalLayer(Layer);

            if IsSignal or LayerUtils.IsElectricalLayer(Layer) or IsPlane then
            begin
                Copper    := LayerObj;
                Thick     := Copper.CopperThickness;
                Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
                DieMatl := 'foil';
            //  think this only applies to eLayerClass_Electrical
                LayerPos  := IntToStr(Board.LayerPositionInSet(AllLayers, LayerObj));
            end
            else if (Layer = eTopPaste) or (Layer = eBottomPaste) then
            begin
                LayerObj.Name ;             // TPasteMaskLayerAdapter()
                Thick     := LayerObj.CopperThickness;   // nonsense default value
                Thick     := MilsToCoord(cPasteThick);
                Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
            end
            else if (Layer = eTopOverlay) or (Layer = eBottomOverlay) then
            begin
                 Thick     := MilsToCoord(0.2);
                 Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
                 LayerObj.Name;
            end
            else
            begin   // dielectrics     eSurface eCore ePrepreg
                 Dielectric := LayerObj;  // .Dielectric Tv6
                 DieType    := kDielectricTypeStrings(Dielectric.DielectricType);
                 if (Dielectric.DielectricType = eSurfaceMaterial) then DieType := 'Surface';
                 if Dielectric.DielectricType = eCore then DieType := 'Core';
                 Thick     :=  Dielectric.DielectricHeight;
                 Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);

                 DieMatl   := Dielectric.DielectricMaterial;
                 DieConst  := FloatToStr(Dielectric.DielectricConstant);
            end;

         // sum class Physical thickness but do not sum pastemask..
            if (LayerClass = eLayerClass_Physical) then
            begin
                if (Layer = eTopPaste) or (Layer = eBottomPaste) then
                    Thick := 0;
                TotThick := TotThick + Thick;
            end;

   //     TLayernameDisplayMode: eLayerNameDisplay_Short/Medium/Long
            ShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);
            MidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
            LongLName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long) ;

            IsDisplayed := Board.LayerIsDisplayed(Layer);
       //     ColorToString(Board.LayerColor(Layer]));   // TV6_Layer
            LColour := ColorToString(PCBSysOpts.LayerColors(Layer));

            TempS.Add(Padright(IntToStr(LayerClass) + '.' + IntToStr(i),5) + ' | ' + PadRight(LayerPos,3) + ' ' + PadRight(LayerObj.Name, 20)
                      + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 13) // + '  ' + PadRight(LongLName, 20)
                      + '  ' + PadRight(BoolToStr(IsPlane,true), 6) + '  ' + PadRight(BoolToStr(IsDisplayed,true), 6) + '  ' + PadRight(LColour, 12)
                      + PadLeft(IntToStr(Layer), 9) + ' ' + PadRight(BoolToStr(LayerObj.UsedByPrims, true), 6)
                      + PadRight(DieType, 15) + PadRight(DieMatl, 15) + PadRight(Thickness, 10) + PadRight(DieConst,5) + ' GI:' + IntToStr(LAddress) + ':' + IntToHex(LAddress,7));

            LayerObj := SubStack.Next(Layerclass, LayerObj);
            Inc(i);
        end;
    end;

    TempS.Add('');
    TempS.Add('Sub Stack ' + IntToStr(StackIndex + 1) + ': Total Thickness : ' + CoordUnitToStringWithAccuracy(ToTThick, eMetric, 3, 4) );
end;

Procedure LayerStackInfoTest;
var
    BR          : IPCB_BoardRegion;
    SubStack    : IPCB_LayerStack;
    LayerStack  : IPCB_LayerStack_V7;
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
    LowPos, HighPos     : integer;
    i           : integer;
    FileName    : String;
    XLayers     : string;
    LSLIndex    : integer;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
    if Board = nil then exit;

    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    VerMajor := Version(true).Strings(0);
    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    MechLayerKind := NoMechLayerKind;
    if (StrToInt(VerMajor) >= AD19VersionMajor) then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    FileName := ExtractFilePath(FileName);

    MasterStack := Board.MasterLayerStack;
//    XLayers := WideStrAlloc(10000);
//    MasterStack.Export_ToParameters(XLayers);


    LSR := FindBoardStackRegions(Board);

    TempS := TStringList.Create;
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
        SubStack := Board.LayerStack;
        TempS.Add('Layer Stack: ' + PadRight(SubStack.Name, 30) + '  ID: ' + SubStack.ID);
        ReportSubStack(0, SubStack);
    end else
    begin
        TempS.Add('Stack Regions: ' + IntToStr(LSR.Count) );
        for i := 0 to (LSR.Count - 1) do
        begin
            BR := LSR.Items(i);
            BR.Descriptor;
            BR.Handle;
            BR.Identifier;
            BR.Index;
            BR.ObjectIDString;
            BR.Detail;
            TempS.Add('Stack Region ' + IntToStr(i + 1) + '  name: ' + PadRight(BR.Name,30) + ' LS: DNK          area: ' + FormatFloat(',0.###', BR.Area / c1_00MM / c1_00MM) + ' sq.mm ' );
        end;
        TempS.Add('');
        TempS.Add('Number of Sub Stacks: ' + IntToStr(MasterStack.SubstackCount) );
        for i := 0  to (MasterStack.SubstackCount - 1) do
        begin
            SubStack := MasterStack.SubStacks[i];
            TempS.Add('Sub Stack ' + IntToStr(i + 1) + '  name: ' + SubStack.Name + '  ID: ' + SubStack.ID);
            ReportSubStack(i, SubStack);
            TempS.Add('');

            ReportDrillPairs(Board, SubStack);
            TempS.Add('');
        end;

        if (cCheckLayerNames) then
        for i := 0  to (MasterStack.SubstackCount - 1) do
        begin
            SubStack := MasterStack.SubStacks[i];
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

    i := 0;
    LIterator := Board.MechanicalLayerIterator;
    While LIterator.Next Do
    Begin
        Inc(i);
        LayerObj := LIterator.LayerObject;
        Layer    := LIterator.Layer;

        LSLIndex := GetLayerSetCamViewNumber(Layer);

//    Old Methods for Mechanical Layers. Can list all disabled layers
//    LayerStack := Board.LayerStack_V7;
//    for i := 1 to 64 do
//    begin
//        ML1 := LayerUtils.MechanicalLayer(i);
//        LayerObj := LayerStack.LayerObject_V7[ML1];

        LayerName := 'broken method NO name';
        MechLayerKind := NoMechLayerKind;

//        if LayerObj <> Nil then
//        begin

            if ansipos(uppercase(Board.LayerStack.Name), Uppercase(LayerObj.Name)) > 0  then
            begin
                Dielectric := LayerObj;
//                DieMatl  := Dielectric.DielectricMaterial;
                LayerObj.IsInLayerStack;
            end;
            LayerName  := LayerObj.Name;
            ShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short);  // TLayernameDisplayMode: eLayerNameDisplay_Short/Medium
            MidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
            LongLName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);

            if not LegacyMLS then MechLayerKind := LayerObj.Kind;

//        end;

        TempS.Add(PadRight(IntToStr(i), 3) + PadRight(Layer, 10) + ' ' + PadRight(Board.LayerName(Layer), 20)
                  + ' ' + PadRight(LayerName, 20) + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 12) + '  ' + PadRight(LongLName, 20)
                  + ' ' + PadRight(LayerKindToStr(MechLayerKind),18) + ' ' + PadRight(BoolToStr(LayerObj.UsedByPrims, true),8)  + ' GI:' + IntToStr(LSLIndex) + ':' + IntToHex(LSLIndex,7) );
    end;

    TempS.Add('');
    TempS.Add('');
    TempS.Add(' ----- MechLayerPairs -----');
    TempS.Add('');

    MechLayerPairs := Board.MechanicalPairs;
    LayerStack := Board.LayerStack_V7;

// is this list always in the same order as MechanicalPairs ??
    slMechPairs := FindAllMechPairLayers(LayerStack, MechLayerPairs);

//    MechLayerPairs.LayerPair(0).L0;

    TempS.Add('Mech Layer Pair Count : ' + IntToStr(MechLayerPairs.Count));
    TempS.Add('');
    if (MechLayerPairs.Count > 0) then
        TempS.Add('Ind  LNum1 : LayerName1     <--> LNmum2 : LayerName2 ');

    if slMechPairs.Count <> MechLayerPairs.Count then
        ShowMessage('Failed to find all Mech Pairs ');

    for MechPairIndex := 0 to (slMechPairs.Count -1 ) do  //   (MechLayerPairs.Count - 1) do
    begin
        ML1 := slMechPairs.Names(MechPairIndex);
        ML2 := slMechPairs.ValueFromIndex(MechPairIndex);

        MechLayerPair := MechLayerPairs.LayerPair[MechPairIndex];   // __TMechanicalLayerPair__Wrapper()
        LayerKind := '';
        if not LegacyMLS then
        begin
            LayerKind := 'LayerPairKind : ' + LayerPairKindToStr( MechLayerPairs.LayerPairKind(MechPairIndex) );
        end;

        TempS.Add(PadRight(IntToStr(MechPairIndex),3) + PadRight(IntToStr(ML1),3) + ' : ' + PadRight(Board.LayerName(ML1),20) +
                                             ' <--> ' + PadRight(IntToStr(ML2),3) + ' : ' + PadRight(Board.LayerName(ML2),20) + LayerKind);
{ DNW
        LowLayer  := LayerStack.LayerObject_V7[ML1];
        HighLayer := LayerStack.LayerObject_V7[ML2];       // PCBLayerPair.HighLayer
        LowPos    := Board.LayerPositionInSet(MkSet(MechanicalLayers), LowLayer);
        HighPos   := Board.LayerPositionInSet(MkSet(MechanicalLayers), HighLayer);

        If LowPos <= HighPos Then
            LayerPairs.Add(LowLayer.Name + ' - ' + HighLayer.Name)
        Else
            LayerPairs.Add(HighLayer.Name + ' - ' + LowLayer.Name);
}

 //  broken because no wrapper function to handle TMechanicalLayerPair record.
{ LayerPair[I : Integer] property defines indexed layer pairs and returns a TMechanicalLayerPair record of two PCB layers.

  TMechanicalLayerPair = Record          // TCoordPoint/Rect are record; TPoint.x works.  TCoordRect.x1 works
    Layer1 : TLayer;
    Layer2 : TLayer;
  End;

try:-
  .LowLayer      DNW
  .HighLayer
}
    end;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
    if ExtractFilePath(FileName) = '' then FileName := SpecialFolder_Temporary;
    FileName := ExtractFilePath(FileName) + '\layerstacktests.txt';

    TempS.SaveToFile(FileName);
    Exit;
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

function Version(const dummy : boolean) : TStringList;
begin
    Result := TStringList.Create;
    Result.Delimiter := '.';
    Result.Duplicates := dupAccept;
    Result.DelimitedText := Client.GetProductVersion;
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
    else              Result := 'Unknown'
    end;
end;

function FindAllMechPairLayers(LayerStack : IPCB_LayerStack, MLPS : IPCB_MechanicalLayerPairs) : TStringList;
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

//    LayerStack := Board.LayerStack_V7;

    for i := 1 to MaxMechLayers do
    begin
        ML1       := LayerUtils.MechanicalLayer(i);
        MechLayer := LayerStack.LayerObject_V7(ML1);

        if MechLayer.MechanicalLayerEnabled then
        begin
            for j := (i + 1) to MaxMechLayers do
            begin
                ML2        := LayerUtils.MechanicalLayer(j);
                MechLayer2 := LayerStack.LayerObject_V7(ML2);
                if MechLayer2.MechanicalLayerEnabled then
                if MLPS.PairDefined(ML1, ML2) then
                if (MLPS.LayerUsed(ML1) and MLPS.LayerUsed(ML2)) then
                    Result.Add(IntToStr(ML1) + '=' + IntToStr(ML2));
            end;
        end;
    end;
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
    LSText := LayerSetutils.SerializeToString(ALayerSet);
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
//        If LowPos <= HighPos Then
//            TempS.Add(IntToStr(i+1) + ' | ' + IntToStr(LowPos)  + ':' + LowLayerObj.Name  + ' - ' + IntToStr(HighPos) + ':' + HighLayerObj.Name)
//        Else
//            TempS.Add(IntToStr(i+1) + ' | ' + IntToStr(HighPos) + ':' + HighLayerObj.Name + ' - ' + IntToStr(LowPos)  + ':' + LowLayerObj.Name);
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

