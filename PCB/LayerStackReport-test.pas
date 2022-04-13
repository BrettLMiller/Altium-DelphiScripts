{.................................................................................
 Summary   Used to test LayerClass methods in AD17-19 & report into text file.
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

         tbd :  Use Layer Classes test in AD17 & AD19
                get the stack region names for each substack.
                IPCB_BoardRegionManager
                ILayerStackProvider / ILayerStackInfo / GUID

Note: can export 1 to 64 mech layers in AD17/18/19

..................................................................................}

{.................................................................................}
const
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;     // scripting API has broken consts from TV6_Layer
    AD19MaxMechLayers = 1024;
    NoMechLayerKind   = 0;      // enum const does not exist for AD17/18
    cPasteThick       = 4       // std stencil (mil)

var
    PCBSysOpts     : IPCB_SystemOptions;
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

function LayerClassName (LClass : TLayerClassID) : WideString;                  forward;
function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;       forward;
function Version(const dummy : boolean) : TStringList;                          forward;
function FindAllMechPairLayers(LayerStack : IPCB_LayerStack;, MLPS : IPCB_MechanicalLayerPairs) : TStringList; forward;

function IsLayerClass(LayerObj : IPCB_LayerObject, LClass : TLayerClassID) : boolean;
var
   LayerClass : TLayerClassID;
begin
    for LayerClass := eLayerClass_All to eLayerClass_PasteMask do
    begin
        LayerObj;
    end;
end;

function FindBoardStackRegions(Board : IPCB_Board) : TStringList;
var
    BIterator : IPCB_BoardIterator;
    SR        : IPCB_Region;
    LS        : IPCB_LayerSet;
    BRM       : IPCB_BoardRegionsManager;
    BR        : IPCB_BoardRegion;
    i         : integer;

begin
    Result := TStringList.Create;
    LS := LayerSetUtils.EmptySet;
    LS.Include(eMultiLayer);
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_IPCB_LayerSet(LS);
    BIterator.AddFilter_ObjectSet(MkSet(eRegionObject));
    SR := Biterator.FirstPCBObject;
    while SR <> nil do
    begin
        if SR.Kind := eRegionKind_NamedRegion then
            Result.Add(SR.Name);        // Default Layer Stack Region
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

Procedure LayerStackInfoTest;
var
    SubStack    : IPCB_LayerStack;
    LayerStack  : IPCB_LayerStack_V7;
    LIterator   : IPBC_LayerObjectIterator;
    LayerObj    : IPCB_LayerObject;
    LayerClass  : TLayerClassID;
    Dielectric  : IPCB_DielectricObject;
    Copper      : IPCB_ElectricalLayer;
    i, j        : Integer;
    FileName    : String;
    TempS       : TStringList;
    LSR         : TStringList;
    temp        : integer;
    LayerName   : WideString;
    LayerKind   : WideString;
    LayerPos    : WideString;
    Thickness   : WideString;
    DieType     : WideString;
    DieMatl     : WideString;
    DieConst    : WideString;
    LColour     : WideString;
    ShortLName  : WideString;
    MidLName    : WideString;
    LongLName   : WideString;
    IsDisplayed : boolean;
    TotThick    : TCoord;
    Thick       : TCoord;
    LAddress    : integer;
    Param       : PWideChar;
    WS : widestring;

begin
    Board := PCBServer.GetCurrentPCBBoard;
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
    LSR := FindBoardStackRegions(Board);

    TempS := TStringList.Create;
    TempS.Add(Client.GetProductVersion);
    TempS.Add('');
    TempS.Add('-- Master Stack Info -- ');
    TempS.Add('Number of Sub Stacks: ' + IntToStr(MasterStack.SubstackCount) );
    TempS.Add('');



    for j := 0  to (MasterStack.SubstackCount - 1) do
    begin
        SubStack := MasterStack.SubStacks[j];
        TempS.Add('Sub Stack: ' + IntToStr(j) + '  ' + SubStack.Name + '  ID: ' + SubStack.ID);
        TempS.Add(' Layers in sub stack: '    + IntToStr(SubStack.Count) );
        TempS.Add('  is flex layer? :    '    + BoolToStr(SubStack.IsFlex, true) );

{ Type: TLayerStackStyle
  eLayerStack_Pairs
  eLayerStacks_InsidePairs
  eLayerStackBuildup
  eLayerStackCustom
}
        TempS.Add('');
        TempS.Add(' ----- LayerStack(eLayerClass) ------');

        TotThick := 0;

// LayerClass methods    Mechanical is strangely absent/empty.

        for LayerClass := eLayerClass_All to eLayerClass_PasteMask do
        begin
            TempS.Add('eLayerClass ' + IntToStr(LayerClass) + '  ' + LayerClassName(LayerClass));
            if (LayerClass = eLayerClass_Dielectric) or (LayerClass = eLayerClass_SolderMask) then
                TempS.Add('lc.i  |     LO name             short  mid           long          IsDisplayed? Colour     V7_LayerID Used? Dielectric : Type    Matl    Thickness  Const ')
            else if (LayerClass = eLayerClass_Electrical) or (LayerClass = eLayerClass_Signal)
                 or (LayerClass = eLayerClass_PasteMask) or (LayerClass = eLayerClass_InternalPlane) then
                TempS.Add('lc.i  | Pos LO name             short  mid           long          IsDisplayed? Colour     V7_LayerID Used?                              Thickness (Cu)')
            else
                TempS.Add('lc.i  |     LO name             short  mid           long          IsDisplayed? Colour     V7_LayerID Used? ');

            i := 1;
            LayerObj := SubStack.First(LayerClass);

            While (LayerObj <> Nil ) do
            begin
                Layer := LayerObj.V7_LayerID.ID;
                 LayerObj.IsInLayerStack;       // check always true.

{                ILayerStackProvider;
                LSI := ILayerStackProvider.GetLayerStackInfo(j);
                LSI.IsLayerInLayerStack(Layer);
                LSI.GetLayerInfo(Layer).GetState_GUID;
}
                LAddress := LayerObj.I_ObjectAddress;

                LayerPos  := '';
                Thick     := 0;
                Thickness := '';
                DieType   := '';
                DieMatl   := '';
                DieConst  := '';     // as string for simplicity of reporting

                if LayerUtils.IsSignalLayer(Layer) or LayerUtils.IsElectricalLayer(Layer) or LayerUtils.IsInternalPlaneLayer(Layer) then
                begin
                    Copper    := LayerObj;
                    Thick     := Copper.CopperThickness;
                    Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);
                //  think this only applies to eLayerClass_Electrical
                    LayerPos  := IntToStr(Board.LayerPositionInSet(AllLayers, LayerObj));
                end
                else if (Layer = eTopPaste) or (Layer = eBottomPaste) then
                begin
                    LayerObj.Name ;             // TPasteMaskLayerAdapter()
                    Thick     := LayerObj.CopperThickness;
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
                begin   // dielectrics
                    Dielectric := LayerObj;  // .Dielectric Tv6
                    DieType    := kDielectricTypeStrings(Dielectric.DielectricType);
                    if DieType = 'Surface Material' then DieType := 'Surface';
                    Thick     :=  Dielectric.DielectricHeight;
                    Thickness := CoordUnitToStringWithAccuracy(Thick, eMetric, 3, 4);

                    DieMatl   := Dielectric.DielectricMaterial;
                    DieConst  := FloatToStr(Dielectric.DielectricConstant);
                end;

             // sum thickness but do not sum paste thick.
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
                          + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 13) + '  ' + PadRight(LongLName, 15)
                          + '  ' + PadRight(BoolToStr(IsDisplayed,true), 6) + '  ' + PadRight(LColour, 12)
                          + PadLeft(IntToStr(Layer), 9) + ' ' + PadRight(BoolToStr(LayerObj.UsedByPrims, true), 6)
                          + PadRight(DieType, 15) + PadRight(DieMatl, 15) + PadRight(Thickness, 10) + PadRight(DieConst,5) + ' LP:' + IntToStr(LAddress) );

                LayerObj := SubStack.Next(Layerclass, LayerObj);
                Inc(i);
            end;
        end;

        TempS.Add('');
        TempS.Add('Sub Stack ' + IntToStr(j) + ': Total Thickness : ' + CoordUnitToStringWithAccuracy(ToTThick, eMetric, 3, 4) );
        TempS.Add('');
    end;

    TempS.Add('');
    TempS.Add('API Layers constants: (all obsolete)');
    TempS.Add('MaxRouteLayer = ' +  IntToStr(MaxRouteLayer) +' |  MaxBoardLayer = ' + IntToStr(MaxBoardLayer) );
    TempS.Add(' MinLayer = ' + IntToStr(MinLayer) + '   | MaxLayer = ' + IntToStr(MaxLayer) );
    TempS.Add(' MinMechanicalLayer = ' + IntToStr(MinMechanicalLayer) + '  | MaxMechanicalLayer =' + IntToStr(MaxMechanicalLayer) );
    TempS.Add('');
    TempS.Add(' ----- .LayerObject(index) Mechanical ------');
    TempS.Add('');
    TempS.Add('Calc LayerID   boardlayername       layername           short mid            long             kind  UsedByPrims ');

    i := 0;
    LIterator := Board.MechanicalLayerIterator;
    While LIterator.Next Do
    Begin
        Inc(i);
        LayerObj := LIterator.LayerObject;
        Layer    := LIterator.Layer;

//    Old Methods for Mechanical Layers. Can list all disabled layers
//    LayerStack := Board.LayerStack_V7;
//    for i := 1 to 64 do
//    begin
//        ML1 := LayerUtils.MechanicalLayer(i);
//        LayerObj := LayerStack.LayerObject_V7[ML1];

        LayerName := 'broken method NO name';
        MechLayerKind := NoMechLayerKind;

        if LayerObj <> Nil then                     // 2 different indices for the same object info, Fg Madness!!!
        begin
            LayerName  := LayerObj.Name;
            ShortLName := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Short); // TLayernameDisplayMode: eLayerNameDisplay_Short/Medium
            MidLName   := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Medium);
            LongLName  := LayerObj.GetState_LayerDisplayName(eLayerNameDisplay_Long);

            if not LegacyMLS then MechLayerKind := LayerObj.Kind;

        end;

        TempS.Add(PadRight(IntToStr(i), 3) + ' ' + PadRight(Layer, 10) + ' ' + PadRight(Board.LayerName(Layer), 20)
                  + ' ' + PadRight(LayerName, 20) + PadRight(ShortLName, 5) + ' ' + PadRight(MidLName, 12) + '  ' + PadRight(LongLName, 20)
                  + ' ' + PadRight(IntToStr(MechLayerKind), 3) + ' ' + BoolToStr(LayerObj.UsedByPrims, true) );
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
    TempS.Add('Ind  LNum1 : LayerName1     <--> LNmum2 : LayerName2 ');

    if slMechPairs.Count <> MechLayerPairs.Count then
        ShowMessage('Failed to find all Mech Pairs ');

    for MechPairIndex := 0 to (slMechPairs.Count -1 ) do  //   (MechLayerPairs.Count - 1) do
    begin
        ML1 := slMechPairs.Names(MechPairIndex);
        ML2 := slMechPairs.ValueFromIndex(MechPairIndex);

        MechLayerPair := MechLayerPairs.LayerPair[MechPairIndex];
        LayerKind := '';
        if not LegacyMLS then
        begin
            LayerKind := 'LayerPairKind : ' + LayerPairKindToStr( MechLayerPairs.LayerPairKind(MechPairIndex) );
        end;

        TempS.Add(PadRight(IntToStr(MechPairIndex),3) + PadRight(IntToStr(ML1),3) + ' : ' + PadRight(Board.LayerName(ML1),20) +
                                             ' <--> ' + PadRight(IntToStr(ML2),3) + ' : ' + PadRight(Board.LayerName(ML2),20) + LayerKind);

 //  broken because no wrapper function to handle TMechanicalLayerPair record.
{ LayerPair[I : Integer] property defines indexed layer pairs and returns a TMechanicalLayerPair record of two PCB layers.

  TMechanicalLayerPair = Record          // TCoordPoint/Rect are record; TPoint.x works.  TCoordRect.x1 works
    Layer1 : TLayer;
    Layer2 : TLayer;
  End;

try:-
  .LowLayer
  .HighLayer
}

    end;

    FileName := GetWorkSpace.DM_FocusedDocument.DM_FullPath;
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

function LayerPairKindToStr(LayerStack  : IPCB_LayerStack_V7, LPK : TMechanicalLayerPairKind) : WideString;
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

    LayerStack := Board.LayerStack_V7;

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

{
// Use of LayerObject method to display specific layers
    Var
       Board      : IPCB_Board;
       Stack      : IPCB_LayerStack;
       LyrObj     : IPCB_LayerObject;
       Layer        : TLayer;

    Begin
       Board := PCBServer.GetCurrentPCBBoard;
       Stack := Board.LayerStack;
       for Lyr := eMechanical1 to eMechanical16 do
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
{   TheLayerStack := PCBBoard.LayerStack_V7;
    If TheLayerStack = Nil Then Exit;
    LS       := '';
    LayerObj := TheLayerStack.FirstLayer;
    Repeat
        LS       := LS + Layer2String(LayerObj.LayerID) + #13#10;
        LayerObj := TheLayerStack.NextLayer(LayerObj);
    Until LayerObj = Nil;
}

{  // better to use later method ??
   Stack      : IPCB_LayerStack;
   Lyr        : TLayer;
   for Lyr := eTopLayer to eBottomLayer do
   for Lyr := eMechanical1 to eMechanical16 do  // but eMechanical17 - eMechanical32 are NOT defined ffs.
       LyrObj := Stack.LayerObject[Lyr];
}

{
Function  LayerPositionInSet(ALayerSet : TLayerSet; ALayerObj : IPCB_LayerObject)  : Integer;
 ex. where do layer consts come from??            VV             VV
      LowPos  := PCBBoard.LayerPositionInSet( SignalLayers + InternalPlanes, LowLayerObj);
      HighPos := PCBBoard.LayerPositionInSet( SignalLayers + InternalPlanes, HighLayerObj);
}
