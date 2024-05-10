{ CreateMechLayerMapping.pas                                                          }
{ Summary   Used to create a mapping ini file for mech layer from focused PcbLib      }
{           Works on PcbDoc & PcbLib files.                                           

    CreateMechLayerMappingFile()
      requires default import map inifile in same folder as PcbDoc/Lib
      requires focused target PcbDoc/Lib with configured mech layers: enabled names colours pairs kinds etc
      Outputs (write) an inifile with mapping info matching PcbDoc/Lib.

    External Text Editor:
      User must edit the created mapping file to set ImportMLayer.
      ImportMLayer values supports mechlayer cardinal value 1-1024 (AD19+)
      and supports N-1 mapping by listing multiple values with "|" delimiter.


    ReMapPcbLibMechLayers()
      uses focused PcbLib & prompts for mapping file (read)
      Creates a PcbLib copy with remapped FPs, PcbLib has names, colours, pairs & kinds set from mapping file.

 Author : BL Miller

Until TMechanicalLayerPair is solved..
Export: Can ONLY guess the Layer PairKind from LayerKinds & only assume Top & Bottom..
        User has to check/edit the ini file for the layer pair & set the PairKind.
Import: Can import Kinds PairKinds Top is always assumed at lower layer index than Bottom (listed first)

Legacy fallback for AD17/18; drop ML "kind" & MLPairKind but retain pairings & names etc.

TBD:
  explicit definition of top & bottom of each pair.

Notes:
*1 Board.LayerColor() strings are not right with AD21.
 NOT possible to eliminate use of LayerObject_V7() with MechPairs in AD17 because it fails over eMech16!
 AD17 works with 32 mechlayers but the part of API (& UX) do not.


 Date        Ver  Comment
 2024-04-14 0.10 POC Create mapping file from PcbDoc/Lib & default mapping file..
 2024-05-09 0.20 change INIFile section key ImportLayer to ImportMLayer

  TMechanicalLayerToKindItem

..................................................................................}

const
    NoColour          = 'ncol';
    AD19VersionMajor  = 19;
    AD17MaxMechLayers = 32;       // scripting API has consts for TV6_Layer
    AD19MaxMechLayers = 1024;
    AllLayerDataMax   = 16;       // after this mech layer index only report the actual active layers.
    NoMechLayerKind   = 0;        // enum const does not exist for AD17/18
    ctTop             = 'Top';    // text used denote mech layer kind pairs.
    ctBottom          = 'Bottom';
    cNumPairKinds     = 12;       // number of layerpair kinds (inc. "Not Set")
    cStatusUpdate     = 1;        // statusbar refresh every n FPs.

    cDefaultInputMap  = 'PCBLibrariesDefault01.ini';
    cExportMLMapFile  = '-ML_Map.ini';
    cTmpPcbLibFile    = '_script_tmp.PcbLib';

var
    ServerDoc         : IServerDocument;
    PCBSysOpts        : IPCB_SystemOptions;
    GUIMan            : IGUIManager;
    Board             : IPCB_Board;
    PCBLib            : IPCB_Library;
    MLayerKind        : TMechanicalLayerKind;
    MLayerPairKind    : TMechanicalLayerPairKind;
    MLayerKindStr     : WideString;
    MLayerPairKindStr : WideString;
    MechLayerPair     : TMechanicalLayerPair;       // IPCB_MechanicalLayerPairs.LayerPair(MechPairIdx)
    MechPairIdx       : integer;                    // index of above
    VerMajor          : integer;
    LegacyMLS         : boolean;
    MaxMechLayers     : integer;
    FileName          : String;
    FilePath          : String;
    FolderPath        : WideString;
    Flag              : Integer;
    IsLib             : boolean;

function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;   forward;
function LayerStrToPairKind(LPKS : WideString) : TMechanicalLayerPairKind;  forward;
function LayerKindToStr(LK : TMechanicalLayerKind) : WideString;            forward;
function LayerStrToKind(LKS : WideString) : TMechanicalLayerKind;           forward;
function FindAllMechPairLayers(LayerStack : IPCB_LayerStack, MLPS : IPCB_MechanicalLayerPairs) : TStringList; forward;
function FindUsedPairKinds(MLPS : IPCB_MechanicalLayerPairs) : TStringList;                forward;
function FindUsedLayerKinds(LayerStack : IPCB_LayerStack) : TStringList;                   forward;
function GuessLayerPairKind(MLayerKind : TMechanicalLayerKind) : TMechanicalLayerPairKind; forward;
Procedure ConvertMechLayerKindToLegacy_Wrapped(Board : IPCB_Board);                        forward;
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) :IPCB_MechanicalLayer;            forward;
function GetMechLayerObjectFromLID7(LS: IPCB_MasterLayerStack, var I : integer, MLID : TLayer) : IPCB_MechanicalLayer; forward;
function ShowHideMechLayers(const ShowUsed : boolean) : TLayer; forward;
function FindMLInIniFile(INIFile2 : TIniFile, const LayerName : WideString) : integer; forward;
procedure ConfigureMechLayers(Board : IPCB_Board, IniFile : TIniFile); forward;
function CreateFreeSourceDoc(DocPath : WideString, DocName : WideString, const DocKind : TDocumentKind) : IServerDocument; forward;
function GetMechLayerCardinal(const MLID : TLayer) : integer; forward;


{.........................................................................................................}

Procedure ShowUsedMechLayers;
begin
    ShowHideMechLayers(true);
end;
Procedure HideUnusedMechLayers;
begin
    ShowHideMechLayers(false);
end;

Procedure UnPairCurrentMechLayer;
var
    LayerStack       : IPCB_MasterLayerStack;
    MechLayerPairs   : IPCB_MechanicalLayerPairs;
    ML1              : integer;
    i                : Integer;
    CurrLayer        : TLayer;
begin
    IsLib := false;
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if VerMajor >= AD19VersionMajor then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    MechLayerPairs := Board.MechanicalPairs;
    CurrLayer      := Board.CurrentLayer;

    for i := 1 To MaxMechLayers do
    begin
        ML1 := LayerUtils.MechanicalLayer(i);
        if MechLayerPairs.PairDefined(CurrLayer, ML1) then
        begin
             MechLayerPairs.RemovePair(CurrLayer, ML1);
             ShowInfo('UnPaired Mechanical Layers :' + Board.LayerName(CurrLayer) + ' and ' + Board.LayerName(ML1) );
             break;
        end;
    end;

    Board.ViewManager_UpdateLayerTabs;
end;

Procedure CreateMechLayerMappingFile;
var
    LayerStack       : IPCB_MasterLayerStack;
    MechLayerPairs   : IPCB_MechanicalLayerPairs;
    MechLayer        : IPCB_MechanicalLayer;
    dConfirm         : boolean;
//    slMechLayerPairs : TStringList;
    slUsedPairKinds  : TStringList;
    ML1, ML2         : integer;
    i, j             : Integer;
    sColour          : WideString;
    bHasPairKinds    : boolean;
    INIFile1         : TIniFile;
    INIFile2         : TIniFile;
    LayerName        : WideString;
    ImportIndex      : integer;
    FileName2        : String;

begin
    IsLib := true;
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board
    else IsLib := false;
    if Board = nil then exit;

    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    bHasPairKinds := false;
    if VerMajor >= AD19VersionMajor then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    FilePath := ExtractFilePath(Board.FileName);
    FileName2 := FilePath + cDefaultInputMap;
    if not FileExists(Filename2, false) then
    begin
        ShowMessage('default ini file not found');
        exit;
    end;
    

    FileName := ExtractFileName(Board.FileName);
    FileName := FilePath + ExtractFileNameFromPath(FileName) + cExportMLMapFile;
//    FileName := ChangeFileExt(FileName, '.ini');

    if FileExists(Filename, false) then
    begin
       dConfirm := ConfirmNoYesWithCaption('File of that name already exists.. ','Overwrite ' + ExtractFileName(Filename) + ' ?');
       if dConfirm then
           DeleteFile(FileName)
       else
           exit;
    end;

    IniFile1 := TIniFile.Create(FileName);
    IniFile2 := TIniFile.Create(FileName2);
    BeginHourGlass(crHourGlass);

    LayerStack     := Board.MasterLayerStack;
    MechLayerPairs := Board.MechanicalPairs;

    slUsedPairKinds  := FindUsedPairKinds(MechLayerPairs);
    if slUsedPairKinds.Count > 0 then bHasPairKinds := true;

    for i := 1 to MaxMechLayers do
    begin
//                               i: cardinal,  ML1: LayerID
        MechLayer := GetMechLayerObject(LayerStack, i, ML1);
        LayerName := Board.LayerName(ML1);

        if MechLayer.MechanicalLayerEnabled then
        begin
//   find layer cardinal with layername match 
            ImportIndex := FindMLInIniFile(IniFile2, LayerName);

            MLayerKind := NoMechLayerKind;
            if not LegacyMLS then
                MLayerKind := MechLayer.Kind;
            MLayerKindStr := LayerKindToStr(MLayerKind);

            sColour := ColorToString( PCBSysOpts.LayerColors(ML1) );

            IniFile1.WriteString ('MechLayer' + IntToStr(i), 'Name',        LayerName );       // MechLayer.Name);
            IniFile1.WriteString ('MechLayer' + IntToStr(i), 'ImportMLayer', IntToStr(ImportIndex) );     // MechLayer.Layer cardinal
            IniFile1.WriteBool   ('MechLayer' + IntToStr(i), 'Enabled',     MechLayer.MechanicalLayerEnabled);
            IniFile1.WriteString ('MechLayer' + IntToStr(i), 'Kind',        MLayerKindStr);
            IniFile1.WriteBool   ('MechLayer' + IntToStr(i), 'Show',        MechLayer.IsDisplayed[Board]);
            IniFile1.WriteString ('MechLayer' + IntToStr(i), 'Color',       sColour);

// if layer has valid "Kind", STILL need (our) explicit pairing to be set.
            for j := 1 to MaxMechLayers do
            begin
                ML2 := LayerUtils.MechanicalLayer(j);
                if MechLayerPairs.PairDefined(ML1, ML2) then
                begin
// can NOT determine the LayerPair layers from PairIndex because TMechanicalLayerPair wrapper is borked so can NOT determine the PairKinds.
// if only .PairDefined(L1,L2) had returned the PairIndex instead of boolean.
// but then NO guarantee ML1 is comp top or bottom side!

// make a guess for PairKind from single layer Kind.
                    MLayerPairKindStr := LayerPairKindToStr(NoMechLayerKind);
// don't assume a pair kind unless they are already used in PcbDoc.
                    if bHasPairKinds then
                    begin
                        MLayerPairKindStr := LayerPairKindToStr( GuessLayerPairKind(MLayerKind) );
                        if (slUsedPairKinds.IndexOf(MLayerPairKindStr) < 0) then
                            MLayerPairKindStr := LayerPairKindToStr(NoMechLayerKind);
                    end;

                    IniFile1.WriteString ('MechLayer' + IntToStr(i), 'Pair',      Board.LayerName(ML2) );
                    IniFile1.WriteInteger('MechLayer' + IntToStr(i), 'PairLayer', ML2 );
                    IniFile1.WriteString ('MechLayer' + IntToStr(i), 'PairKind',  MLayerPairKindStr );
                end;
            end;
        end;
    end;
    IniFile1.Free;
    IniFile2.Free;
    slUsedPairKinds.Free;
    EndHourGlass;
    ShowMessage('Warning: LayerPair Top & Bottom are ONLY a best guess. ' + #13
                +' Check the inifile LayerPairs. ');
end;

function SourceToDestinationsMapping(slMLayerMapping: TStringList) : TStringList;
// Make Reverse mapping S1=D1|D2 of mech layer MLIDs from cardinal numbers: (1 - max).
var
    MLD, MLS    : integer;
    i, j, k     : integer;
    Destin      : WideString;
    tempstr     : WideString;
    SourceList  : TStringList;
    SourceLayer : WideString;
begin
    Result := TStringList.Create;
    Result.NameValueSeparator := '=';
    SourceList := TStringList.Create;
    SourceList.Delimiter := '|';
    for i := 0 to (slMLayerMapping.Count - 1) do
    begin
        Destin  := slMLayerMapping.Names(i);            // Destination ML
        MLD := LayerUtils.MechanicalLayer(Destin);
        tempstr := slMLayerMapping.ValueFromIndex(i);   // list of import source layer
        SourceList.DelimitedText := tempstr;
        for j := 0 to (SourceList.Count -1) do
        begin
            SourceLayer := SourceList.Strings(j);
            MLS := LayerUtils.MechanicalLayer(SourceLayer);
            k := Result.IndexofName(IntToStr(MLS));
            if k > -1 then
            begin
                tempstr := Result.ValueFromIndex(k);
                tempstr := tempstr + '|' + IntToStr(MLD);
                Result.Strings(k) :=  IntToStr(MLS) + '=' + tempstr;
            end else
                Result.Add(IntToStr(MLS) + '=' + IntToStr(MLD));
        end;
    end;
    SourceList.Free;
end;

function FindMLInIniFile(INIFile : TIniFile, const LayerName : WideString) : integer;
var
    i     : integer;
    Name  : WideString;

begin
    Result := 0;
    for i := 1 to MaxMechLayers do
    begin
        Name := INIFile.ReadString('MechLayer' + IntToStr(i), 'Name', '');
        if Name = LayerName then
            Result := i; 
        if Result <> 0 then break;
    end;
end;

function GetAllSectionKeysValInIniFile(INIFile : TIniFile, const SectionKey : WideString) : TStringList;
var
    i          : integer;
    KeyValue   : WideString;

begin
    Result := TStringList.Create;
    Result.NameValueSeparator := '=';
    for i := 1 to MaxMechLayers do
    begin
        KeyValue := INIFile.ReadString('MechLayer' + IntToStr(i), SectionKey, '');

        if KeyValue <> '' then
            Result.Add(IntToStr(i) + '=' + KeyValue); 
    end;
end;

function GetDestinListForSource(slMLayerMapSD : TStringList, MLID : integer) : TStringList;
var
    index     : integer;
    MapLine   : WideString;

begin
    Result := TStringList.Create;
    Result.Delimiter := '|';
    Result.StrictDelimiter := true;
    MapLine := '';

    index := slMLayerMapSD.IndexofName(MLID);
    if index > -1 then
    begin
        MapLine := slMLayerMapSD.ValueFromIndex(index);
        Result.DelimitedText := MapLine;
    end;
end;
  
Procedure ReMapPcbLibMechLayers;
var
    NewPcbLib          : IPCB_Library;
    TmpPcbLib          : IPCB_Library;
    Footprint          : IPCB_LibComponent;
    DumFootprint       : IPCB_LibComponent;
    TmpFootprint       : IPCB_LibComponent;
    NewFootprint       : IPCB_LibComponent;
    GIterator          : IPCB_GroupIterator;
    Prim, Prim2        : IPCB_Primitive;
    OpenDialog         : TOpenDialog;
    INIFile1           : TIniFile;
    ML1, ML2           : integer;
    i, j, k            : Integer;
    slMLayerMapping    : TStringList;   // DestinationMLx=SourceMLm|SourceMLn|..
    slMLayerMapSD      : Tstringlist;   // reversed SourceMLIDx=DestinMLIDn|...
    FPrimList          : TObjectList;
    slMapLine          : TStringList;

    sStatusBar         : WideString;
    iStatusBar         : integer;
    TotalFPs           : integer;
    StartTime          : TDateTime;
    StopTime           : TDateTime;

begin
    IsLib := true;
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board
    else
        IsLib := false;
    if Board = nil then exit;

    GUIMan := Client.GUIManager;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if VerMajor >= AD19VersionMajor then
    begin
        MaxMechLayers := AD19MaxMechLayers;
        LegacyMLS     := false;
    end;

    OpenDialog        := TOpenDialog.Create(Application);
    OpenDialog.Title  := 'Mech Layer ReMapping from *.ini file';
    OpenDialog.Filter := 'INI file (*.ini)|*.ini';
//    OpenDialog.InitialDir := ExtractFilePath(Board.FileName);
    OpenDialog.FileName := '';
    Flag := OpenDialog.Execute;
    if (Flag = 0) then exit;

    FileName := OpenDialog.FileName;

    if SameString(ExtractFileName(FileName), cDefaultInputMap, false) then
    begin
        ShowMessage('Mapping file can NOT be same file as inital mapfile! Exiting. ');
        exit;
    end;

    StartTime := Time;
    BeginHourGlass(crHourGlass);
    IniFile1 := TIniFile.Create(FileName);

//    Read in mapping file
//    Store ImportLayer in StringList name by cardinal ML index,  ImportMLayer (value) can = '1|3|45'
    slMLayerMapping := GetAllSectionKeysValInIniFile(IniFile1, 'ImportMLayer');
    if slMLayerMapping.Count < 1 then
    begin
        ShowMessage('No ReMapping found in file! Exiting. ');
        IniFile1.Free;
        EndHourGlass;
        exit;
    end;

// Generate Reverse/inverse mapping using MLIDs is easier than cardinals later on..
    slMLayerMapSD := SourceToDestinationsMapping(slMLayerMapping);

//    Create new Destination PcbLib named from mapping filename.
    FolderPath := ExtractFilePath(Board.FileName);
    FileName   := ExtractFileName(FileName);
    ServerDoc  := CreateFreeSourceDoc(FolderPath, ChangefileExt(FileName,''), cDocKind_PcbLib);
    NewPcbLib  := PcbServer.LoadPCBLibraryByPath(ServerDoc.FileName);

// attempts to be "clever" with the default empty FP caused one missing FP & one empty FP copy.
    DumFootprint := NewPcbLib.GetComponent(0);

//    Clear all Set all layers kinds pairs colours?
    if Not LegacyMLS then
        ConvertMechLayerKindToLegacy_Wrapped(NewPcbLib.Board);

    slMapLine := TStringList.Create;

    FPrimList := TObjectList.Create;            // hold a list of Comp Prims to delete.
    FPrimList.OwnsObjects := false;

    TotalFPs := PcbLib.ComponentCount;

    for i := 0 to (TotalFPs - 1)  do
    begin
        DeleteFile(SpecialFolder_Temporary + cTmpPcbLibFile);

        Footprint := PcbLib.GetComponent(i);
        Footprint.SaveToFile(SpecialFolder_Temporary + cTmpPcbLibFile);
        TmpPcbLib := PcbServer.LoadPCBLibraryByPath(SpecialFolder_Temporary + cTmpPcbLibFile);
        Board := TmpPcbLib.Board;

// statusbar text is covered by file loading progressbar
        if (i MOD cStatusUpdate) = 0 then
        begin
            iStatusBar := Int(i / TotalFPs * 100);
            sStatusBar := ' remapping.. : ' + IntToStr(iStatusBar) + '% done';
            GUIMan.StatusBar_SetState (1, sStatusBar);
        end;

        if not LegacyMLS then
            ConvertMechLayerKindToLegacy_Wrapped(Board);

        TmpFootprint := TmpPcbLib.GetComponentByName(Footprint.Name);
        TmpFootprint.BeginModify;

//  get FP prim list for remapped layers
//  Replicate (& delete) prims on used mech-layers of TmpFootprint and move back to mapped layers
        FPrimList.Clear;
        GIterator := TmpFootprint.GroupIterator_Create;
        Prim      := GIterator.FirstPCBObject;
        while Prim <> Nil Do
        begin
            ML1 := Prim.Layer;

// check if ML is ImportLayer mapping value
            k := slMLayerMapSD.IndexOfName(ML1);
            if k > -1 then
                FPrimList.Add(Prim);

            Prim := GIterator.NextPCBObject;
        end;
        TmpFootprint.GroupIterator_Destroy(GIterator);

        for j := 0 to (FPrimList.Count -1) do
        begin
            Prim := FPrimList.Items(j);
            ML1  := Prim.Layer;
// delete prims.
            TmpFootprint.RemovePCBObject(Prim);

// list of destination layers MLD1|MLDn from name match source MLS
            slMapLine := GetDestinListForSource(slMLayerMapSD, ML1);

// Add back prims
            for k := 0 to (slMapLine.Count - 1) do
            begin
                if k = 0 then
                    Prim2 := Prim
                else
                    Prim2 := Prim.Replicate;

                ML2 := slMapLine.Strings(k);
                Prim2.Layer := ML2;
                if k <> 0 then
                    Board.AddPCBObject(Prim2);
                TmpFootPrint.AddPCBObject(Prim2);
            end;
            slMapLine.Clear;
        end;

        TmpFootprint.EndModify;
        FPrimList.Clear;

        NewFootPrint := NewPcbLib.CreateNewComponent;
//  this was making duplicates on default inital FP before use of DumFP !
//        NewFootPrint.Name := NewPcbLib.GetUniqueCompName(Footprint.Name);
        NewFootPrint.Name := Footprint.Name;

        TmpFootprint.CopyTo(NewFootPrint, eFullCopy);
        NewPcbLib.RegisterComponent(NewFootprint);
    end;

// remove default empty FP of new created PcbLib
    NewPcbLib.DeRegisterComponent(DumFootprint);
    NewPcbLib.RemoveComponent(DumFootprint);

    FPrimList.Destroy;
    slMapLine.Free;

//    Set all layers kinds pairs colours as defined in mapping file.
    Board := NewPCBLib.Board;
    ConfigureMechLayers(Board, IniFile1);
    Board.ViewManager_UpdateLayerTabs;
    IniFile1.Free;
    NewPcbLib.Board.ViewManager_FullUpdate;
    NewPcbLib.Board.GraphicalView_ZoomRedraw;
    NewPcbLib.RefreshView;

    StopTime := Time;
    EndHourGlass;

    NewPcbLib.Board.SetState_DocumentHasChanged;
    ShowInfo('Remapped ' + IntToStr(TotalFPs) + ' footprints in '+ IntToStr((StopTime-StartTime)*24*3600) +' sec ');
end;

procedure ConfigureMechLayers(Board : IPCB_Board, IniFile : TIniFile);
var
    LayerStack         : IPCB_MasterLayerStack;
    MechLayer          : IPCB_MechanicalLayer;
    MechLayer2         : IPCB_MechanicalLayer;
    MechLayerPairs     : IPCB_MechanicalLayerPairs;
    MPairLayer         : WideString;
    MLayerKind2        : TMechanicalLayerKind;
    MLayerPairKind2    : TMechanicalLayerPairKind;
    MLayerKindStr2     : WideString;
    MLayerPairKindStr2 : WideString;
    LayerName1         : WideString;
    LayerName2         : WideString;
    Pair2LID           : integer;
    LColour            : TColor;
    ML1, ML2           : integer;
    i, j, k            : Integer;
    slUsedLPairKinds   : TStringList;
    slUsedLayerKinds   : TStringList;

begin
    PCBSysOpts := PCBServer.SystemOptions;
//    If PCBSysOpts = Nil Then exit;

    LayerStack := Board.MasterLayerStack;
    slUsedLPairKinds := TStringList.Create;
    slUsedLayerKinds := TStringList.Create;
// no pairs in AD17 PcbLib
    if not (LegacyMLS and IsLib) then
    begin
        MechLayerPairs    := Board.MechanicalPairs;
        slUsedLPairKinds  := FindUsedPairKinds(MechLayerPairs);
    end;
    if not LegacyMLS then
        slUsedLayerKinds  := FindUsedLayerKinds(LayerStack);

// remove any existing pairs connected to all layers listed in inifile.
// set all new layer names
// no pairs in AD17 PcbLib
    if not (LegacyMLS and IsLib) then
    for i := 1 To MaxMechLayers do
    begin
        MechLayer :=  GetMechLayerObject(LayerStack, i, ML1);

        if IniFile.SectionExists('MechLayer' + IntToStr(i)) then
        begin
            LayerName1 := IniFile.ReadString('MechLayer' + IntToStr(i), 'Name', 'eMech' + IntToStr(i));
            MechLayer.Name := LayerName1;

            for j := i to MaxMechLayers do
            begin
                ML2 := LayerUtils.MechanicalLayer(j);
//        remove any pair including same layer & backwards ones !
                if MechLayerPairs.PairDefined(ML2, ML1) then
                    MechLayerPairs.RemovePair(ML2, ML1);
                if MechLayerPairs.PairDefined(ML1, ML2) then
                    MechLayerPairs.RemovePair(ML1, ML2);
            end;
        end;
    end;

// add single settings & new pairs
    for i := 1 To MaxMechLayers do
    begin
        MLayerKind := NoMechLayerKind;
        MechLayer  :=  GetMechLayerObject(LayerStack, i, ML1);

        if IniFile.SectionExists('MechLayer' + IntToStr(i)) then
        begin
            LayerName1 := IniFile.ReadString('MechLayer' + IntToStr(i), 'Name', 'eMech' + IntToStr(i));
            MechLayer.Name := LayerName1;

//    allow turn Off -> ON only, default Off for missing entries
            If Not MechLayer.MechanicalLayerEnabled then
                MechLayer.MechanicalLayerEnabled := IniFile.ReadBool ('MechLayer' + IntToStr(i), 'Enabled',   False);

            MLayerKindStr                      := IniFile.ReadString ('MechLayer' + IntToStr(i), 'Kind',      LayerKindToStr(NoMechLayerKind) );
            MPairLayer                         := IniFile.ReadString ('MechLayer' + IntToStr(i), 'Pair',      '');
            Pair2LID                           := IniFile.ReadInteger('MechLayer' + IntToStr(i), 'PairLayer', 0);
            MLayerPairKindStr                  := IniFile.ReadString ('MechLayer' + IntToStr(i), 'PairKind',  LayerPairKindToStr(NoMechLayerKind) );
            MechLayer.LinkToSheet              := IniFile.ReadBool   ('MechLayer' + IntToStr(i), 'Sheet',     False);
            MechLayer.DisplayInSingleLayerMode := IniFile.ReadBool   ('MechLayer' + IntToStr(i), 'SLM',       False);
            MechLayer.IsDisplayed[Board]       := IniFile.ReadBool   ('MechLayer' + IntToStr(i), 'Show',      True);
            LColour                            := IniFile.ReadString ('MechLayer' + IntToStr(i), 'Color',     NoColour);
            if LColour <> NoColour then
            begin
                PCBSysOpts.LayerColors(ML1) := StringToColor( LColour);
//                if Board.LayerColor(ML1) <> StringToColor(LColour) then
//                    showmessage('mismatch');
            end;

// check if layerkind is used by other layer & remove.
            j := slUsedLayerKinds.IndexOfName(MLayerKindStr);
            if j > -1 then
            begin
                ML2 := slUsedLayerKinds.ValueFromIndex(j);
                if ML2 <> ML1 then
                begin
                     k := 0;
                     MechLayer2 := GetMechLayerObjectFromLID7(LayerStack, k, ML2);
                     MechLayer2.Kind := NoMechLayerKind;
//                 remove confusing name with reserved keywords.
                     MechLayer2.Name := 'Mech Layer ' + IntToStr(k);
                end;
            end;

            MLayerKind     := LayerStrToKind(MLayerKindStr);
            MLayerPairKind := LayerStrToPairKind(MLayerPairKindStr);
//    new "kind" pairs is a separate property & single layers each have a Kind
            if not LegacyMLS then
                MechLayer.Kind  := MLayerKind;

//   if no key for any Pair then go around.
            if MPairLayer = '' then continue;

//    ignore already processed layers.
            for j := (i + 1) to MaxMechLayers do
            begin
                if i = j then continue;

                MLayerKind2     := NoMechLayerKind;
                MLayerPairKind2 := NoMechLayerKind;
                MechLayer2      :=  GetMechLayerObject(LayerStack, j, ML2);

                LayerName2         := IniFile.ReadString('MechLayer' + IntToStr(j), 'Name', 'Mechanical ' + IntToStr(j));
                MLayerKindStr2     := IniFile.ReadString('MechLayer' + IntToStr(j), 'Kind',      LayerKindToStr(NoMechLayerKind) );
                MLayerPairKindStr2 := IniFile.ReadString('MechLayer' + IntToStr(j), 'PairKind',  LayerPairKindToStr(NoMechLayerKind) );
                MLayerKind2        := LayerStrToKind(MLayerKindStr2);
                MLayerPairKind2    := LayerStrToPairKind(MLayerPairKindStr2);

//    if 2nd of the pair is not listed in initfile
//                if not IniFile.SectionExists('MechLayer' + IntToStr(j)) then
//                begin
//                     use new Layer number
//                end;

// does ML2 name (from file) match ML1 paired layer name
// simple layername text match for bottom vs top.
                MechPairIdx := -1;
                if not (LegacyMLS and IsLib) then
                if (MPairLayer = LayerName2) and not MechLayerPairs.PairDefined(ML1, ML2) then
                begin
                    if (Pos(ctTop, LayerName2) > 0)  and (Pos(ctBottom, LayerName1) > 0) then
                        MechPairIdx := MechLayerPairs.AddPair(ML2, ML1)
                    else
                        MechPairIdx := MechLayerPairs.AddPair(ML1, ML2);    // (i, j)       // index? to what FFS
                end;
                if not LegacyMLS then
                begin
                    MechLayer2.Kind := MLayerKind2;
                    if (MechPairIdx > -1) then
                    begin
                        MechLayerPair := MechLayerPairs.LayerPair(MechPairIdx);
                        MechLayerPairs.LayerPairKind(MechPairIdx) := MLayerPairKind;

                        if MLayerPairKind <> MLayerPairKind2 then
                            ShowMessage('mismatch pair kinds ' + LayerName1 + '---' + LayerName2);
                    end;
                end;

// Creating pairs automatically changes the names to Top & Bottom keywords first!
// Altium tries to force/dictate its naming convention Top Bottom first so rewrite our names.
                if (MechPairIdx > -1) then
                begin
                    MechLayer.Name  := LayerName1;
                    MechLayer2.Name := LayerName2;
                    break;
                end;
            end;
        end; // section exists
    end;

    slUsedLPairKinds.Free;
    slUsedLayerKinds.Free;
end;

Procedure ConvertMechLayerKindToLegacy;
begin
    IsLib := true;
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board
    else
        IsLib := false;
    if Board = nil then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    MLayerKind := NoMechLayerKind;
    if VerMajor >= AD19VersionMajor then
    begin
        MaxMechLayers := AD19MaxMechLayers;
        LegacyMLS     := false;
    end else
    begin
        ShowMessage('Requires AD19 or later to convert ');
        exit;
    end;
    if (LegacyMLS And IsLib) then
    begin
        ShowMessage('AD17/18 PcbLib does NOT support ');
        exit;
    end;

    ConvertMechLayerKindToLegacy_Wrapped(Board);
    Board.ViewManager_UpdateLayerTabs;
    ShowInfo('Converted Mechanical Layer Kinds To Legacy ..');
end;

Procedure ConvertMechLayerKindToLegacy_Wrapped(Board : IPCB_Board);
var
    LayerStack     : IPCB_MasterLayerStack;
    MechLayerPairs : IPCB_MechanicalLayerPairs;
    MechLayer      : IPCB_MechanicalLayer;
    ML1            : integer;
    i              : Integer;

begin

    LayerStack     := Board.MasterLayerStack;
    MechLayerPairs := Board.MechanicalPairs;

// Could check a "PairKind" pair does have legacy "Pair" set..
// MechLayerPairs.PairKind(index) ; need index ?? no solution.. can not do this.
    for i:= 0 to (MechLayerPairs.Count - 1) do
    begin
        MechLayerPair := MechLayerPairs.LayerPair(i);
        MechLayerPairs.SetState_LayerPairKind(i) := NoMechLayerKind;
    end;

    for i := 1 To MaxMechLayers do
    begin
        MechLayer :=  GetMechLayerObject(LayerStack, i, ML1);
        MechLayer.Kind := NoMechLayerKind;       //  'Not Set'
    end;
end;

{------------------------------------------------------------------------------------}
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

function LayerStrToPairKind(LPKS : WideString) : TMechanicalLayerPairKind;
var
    I : integer;
begin
    Result := -1;
    for I := 0 to 18 do
    begin
         if LayerPairKindToStr(I) = LPKS then
         begin
             Result := I;
             break;
         end;
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

function GetMechLayerCardinal(const MLID : TLayer) : integer;
var
    MLID2 : TLayer;
    i     : integer;
begin
    Result := 0;
    for i := 1 to MaxMechLayers do
    begin
        MLID2 := LayerUtils.MechanicalLayer(i);
        if MLID = MLID2 then
        begin
            Result := i;
            break;
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
        MLID := Result.V7_LayerID.ID;             // .LayerID  stops working at i=16
    end;
end;
                                                            // cardinal      V7 LayerID
function GetMechLayerObjectFromLID7(LS: IPCB_MasterLayerStack, var I : integer, MLID : TLayer) : IPCB_MechanicalLayer;
var
    AMLID      : TLayer;
begin
    Result := nil;
    AMLID  := 0;

    I      := GetMechLayerCardinal(MLID);
    Result := GetMechLayerObject(LS, I, AMLID);
end;

function LayerStrToKind(LKS : WideString) : TMechanicalLayerKind;
var
    I : integer;
begin
    Result := -1;
    for I := 0 to 45 do
    begin
         if LayerKindToStr(I) = LKS then
         begin
             Result := I;
             break;
         end;
    end;
end;

function FindAllMechPairLayers(LayerStack : IPCB_LayerStack, MLPS : IPCB_MechanicalLayerPairs) : TStringList;
// is this list always in the same order as MechanicalPairs ??
// no it is NOT & higher layer number can be top side layer !!
var
    MechLayer1    : IPCB_MechanicalLayer;
    MechLayer2    : IPCB_MechanicalLayer;
    ML1, ML2      : integer;
    i, j          : Integer;
begin
    Result := TStringList.Create;
    Result.StrictDelimiter := true;
    Result.Delimiter := '|';
    Result.NameValueSeparator := '=';

    for i := 1 to MaxMechLayers do
    begin
        MechLayer1 :=  GetMechLayerObject(LayerStack, i, ML1);

        if MechLayer1.MechanicalLayerEnabled then
        begin
            for j := (i + 1) to MaxMechLayers do
            begin
                MechLayer2 :=  GetMechLayerObject(LayerStack, j, ML2);

                if MechLayer2.MechanicalLayerEnabled then
                if MLPS.PairDefined(ML1, ML2) then
//                if (MLPS.LayerUsed(ML1) and MLPS.LayerUsed(ML2)) then
                    Result.Add(IntToStr(ML1) + '=' + IntToStr(ML2));
            end;
        end;
    end;
end;

function FindUsedLayerKinds(LayerStack : IPCB_LayerStack) : TStringList;
var
    MechLayer   : IPCB_MechanicalLayer;
    ML1         : integer;
    i           : integer;
begin
    Result := TStringList.Create;
    Result.NameValueSeparator := '=';

    if LegacyMLS then exit;

    for i := 1 To MaxMechLayers do
    begin
        MechLayer :=  GetMechLayerObject(LayerStack, i, ML1);

        MLayerKind := MechLayer.Kind;
        if MLayerKind <> NoMechLayerKind then
            Result.Add(LayerKindToStr(MLayerKind) + '=' + IntToStr(ML1) );
    end;
end;

function FindUsedPairKinds(MLPS : IPCB_MechanicalLayerPairs) : TStringList;
var
    i        : integer;
    PairKind : TMechanicalLayerPairKind;
begin
    Result := TStringList.Create;
    if LegacyMLS then exit;

    for i:= 0 to (MLPS.Count - 1) do
    begin
        PairKind := MLPS.LayerPairKind(i);
        Result.Add(LayerPairKindToStr(PairKind));
    end;
end;

function GuessLayerPairKind(MLayerKind : TMechanicalLayerKind) : TMechanicalLayerPairKind;
var
    MLayerKindStr : WideString;
    MLPK          : WideString;
    I             : integer;
begin
    Result        := NoMechLayerKind;
    MLayerKindStr := LayerKindToStr(MLayerKind);
    for I := 0 to cNumPairKinds do
    begin
        MLPK := LayerPairKindToStr(I);
        if (MLPK <> '') and (MLPK <> ' ') then
        if ansipos(MLPK, MLayerKindStr) > 0 then
        begin
            Result := I;
            break;
        end;
    end;
end;

// unused fn
function GetMechLayerPairKind(LKS : WideString) : TMechanicalLayerPairKind;
// RootKind : basename of layer kind (Assembly Top, Coating, Courtyard etc)
var
    WPos : integer;
    I    : integer;
begin
    Result := -1;
// must contain top or bottom
    WPos := AnsiPos(ctTop,LKS);
    if WPos < 1 then
    begin
        WPos := AnsiPos(ctBottom,LKS);
        if WPos < 1 then exit;
    end;

// must contain PairKind
    for I := 0 to 12 do
    begin
         if ansipos(LayerPairKindToStr(I), LKS) = 1 then
         begin
             Result := I;
             break;
         end;
    end;
end;

function ShowHideMechLayers(const ShowUsed : boolean) : TLayer;
var
    MechLayer  : IPCB_MechanicalLayer;
    ML1        : integer;
    i          : Integer;

begin
    Result := 0;
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
    if Board = nil then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if VerMajor >= AD19VersionMajor then
    begin
        LegacyMLS     := false;
        MaxMechLayers := AD19MaxMechLayers;
    end;

    LayerStack := Board.MasterLayerStack;

    for i := 1 To MaxMechLayers do
    begin
        MechLayer := GetMechLayerObject(LayerStack, i, ML1);

        if MechLayer.UsedByPrims = ShowUsed then
        begin
            MechLayer.IsDisplayed(Board) := ShowUsed;
            Result := ML1;
        end;
    end;

    if ShowUsed and (Result > 0) then
        Board.CurrentLayer := Result;
    Board.ViewManager_UpdateLayerTabs;
end;

function CreateFreeSourceDoc(DocPath : WideString, DocName : WideString, const DocKind : TDocumentKind) : IServerDocument;
var
   LibFullPath  : WideString;
   FileExten    : WideString;
   Success      : boolean;
begin
    Result := nil;
    FileExten := '.txt';
    FileExten := Client.GetDefaultExtensionForDocumentKind(DocKind);
    LibFullPath := DocPath + '\' + DocName + cDotChar + FileExten;

    if FileExists(LibFullPath, false) then
        DeleteFile(LibFullPath);

//  an example default new name is SchLib1.SchLib
    Result := CreateNewFreeDocumentFromDocumentKind(DocKind, true);
    Success := Result.DoSafeChangeFileNameAndSave(LibFullPath, DocKind);
end;