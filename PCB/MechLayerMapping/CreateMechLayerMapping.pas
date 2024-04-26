{ CreateMechLayerMapping.pas                                                          }
{ Summary   Used to create a mapping ini file for mech layer from focused PcbLib      }
{           Works on PcbDoc & PcbLib files.                                           

    CreateMechLayerMappingFile
      requires default import map inifile in same folder as PcbDoc/Lib
      requires focused target PcbDoc/Lib with configured mech layers: enabled names colours pairs kinds etc
      Outputs an inifile with mapping info matching PcbDoc/Lib.


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

 AD21 Layer UI "Create CompLayer Pair" grabs the first free layers & then after you select target mech layer pair numbers..
      it leaves the defaults with same new mech layer names!!  At least they are not pairs!

 NOT possible to eliminate use of LayerObject_V7() with MechPairs in AD17 because it fails over eMech16!
 AD17 works with 32 mechlayers but the part of API (& UX) do not.


 Date        Ver  Comment
 2024-04-14 0.10 POC Create mapping file from PcbDoc/Lib & default mapping file..

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
    cNumPairKinds     = 12;        // number of layerpair kinds (inc. "Not Set")

    cDefaultInputMap  = 'PCBLibrariesDefault01.ini';
    cExportMLMapFile  = '-ML_Map.ini';

var
    PCBSysOpts        : IPCB_SystemOptions;
    Board             : IPCB_Board;
    PCBLib            : IPCB_Library;
    LayerStack        : IPCB_MasterLayerStack;
    MLayerKind        : TMechanicalLayerKind;
    MLayerPairKind    : TMechanicalLayerPairKind;
    MLayerKindStr     : WideString;
    MLayerPairKindStr : WideString;
    MechLayerPairs    : IPCB_MechanicalLayerPairs;
    MechLayerPair     : TMechanicalLayerPair;       // IPCB_MechanicalLayerPairs.LayerPair(MechPairIdx)
    MechPairIdx       : integer;                    // index of above
    VerMajor          : integer;
    LegacyMLS         : boolean;
    MaxMechLayers     : integer;
    FileName          : String;
    FilePath          : String;
    Flag              : Integer;

function LayerPairKindToStr(LPK : TMechanicalLayerPairKind) : WideString;   forward;
function LayerStrToPairKind(LPKS : WideString) : TMechanicalLayerPairKind;  forward;
function LayerKindToStr(LK : TMechanicalLayerKind) : WideString;            forward;
function LayerStrToKind(LKS : WideString) : TMechanicalLayerKind;           forward;
function FindAllMechPairLayers(LayerStack : IPCB_LayerStack, MLPS : IPCB_MechanicalLayerPairs) : TStringList; forward;
function FindUsedPairKinds(MLPS : IPCB_MechanicalLayerPairs) : TStringList;                forward;
function FindUsedLayerKinds(LayerStack : IPCB_LayerStack) : TStringList;                   forward;
function GuessLayerPairKind(MLayerKind : TMechanicalLayerKind) : TMechanicalLayerPairKind; forward;
Procedure ConvertMechLayerKindToLegacy_Wrapped(dummy : integer);                           forward;
function GetMechLayerObject(LS: IPCB_MasterLayerStack, i : integer, var MLID : TLayer) :IPCB_MechanicalLayer;            forward;
function GetMechLayerObjectFromLID7(LS: IPCB_MasterLayerStack, var I : integer, MLID : TLayer) : IPCB_MechanicalLayer; forward;
function ShowHideMechLayers(const ShowUsed : boolean) : TLayer; forward;
function FindInIniFile(INIFile2 : TIniFile, LayerName : WideString) : integer; forward;

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
    ML1        : integer;
    i          : Integer;
    CurrLayer  : TLayer;
begin
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

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
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
    FileName := FilePath + cDefaultInputMap;
    if not FileExists(Filename, false) then
    begin
        ShowMessage('default ini file not found');
        exit;
    end;
    IniFile2 := TIniFile.Create(FileName);
    

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
            ImportIndex := FindInIniFile(IniFile2, LayerName);

            MLayerKind := NoMechLayerKind;
            if not LegacyMLS then
                MLayerKind := MechLayer.Kind;
            MLayerKindStr := LayerKindToStr(MLayerKind);

            sColour := ColorToString( PCBSysOpts.LayerColors(ML1) );

            IniFile1.WriteString ('MechLayer' + IntToStr(i), 'Name',        LayerName );       // MechLayer.Name);
            IniFile1.WriteInteger('MechLayer' + IntToStr(i), 'ImportLayer', ImportIndex );     // MechLayer.Layer cardinal
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

function FindInIniFile(INIFile2 : TIniFile, LayerName : WideString) : integer;
var
    i     : integer;
    Name  : WideString;

begin
    Result := 0;
    for i := 1 to MaxMechLayers do
    begin
        Name := INIFile2.ReadString('MechLayer' + IntToStr(i), 'Name', '');
        if Name = LayerName then
            Result := i; 
        if Result <> 0 then break;
    end;
end;
  
Procedure ImportMechLayerInfo(dum : integer);
var
    OpenDialog         : TOpenDialog;
    MechLayer          : IPCB_MechanicalLayer;
    MechLayer2         : IPCB_MechanicalLayer;
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
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
    if Board = nil then exit;

    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    VerMajor := GetBuildNumberPart(Client.GetProductVersion, 0);

    MaxMechLayers := AD17MaxMechLayers;
    LegacyMLS     := true;
    if VerMajor >= AD19VersionMajor then
    begin
        MaxMechLayers := AD19MaxMechLayers;
        LegacyMLS     := false;
    end;

    OpenDialog        := TOpenDialog.Create(Application);
    OpenDialog.Title  := 'Import Mech Layer Names from *.ini file';
    OpenDialog.Filter := 'INI file (*.ini)|*.ini';
//    OpenDialog.InitialDir := ExtractFilePath(Board.FileName);
    OpenDialog.FileName := '';
    Flag := OpenDialog.Execute;
    if (Flag = 0) then exit;

    FileName := OpenDialog.FileName;
    IniFile := TIniFile.Create(FileName);
    BeginHourGlass(crHourGlass);

    LayerStack := Board.MasterLayerStack;

    MechLayerPairs    := Board.MechanicalPairs;
    slUsedLPairKinds  := FindUsedPairKinds(MechLayerPairs);
    slUsedLayerKinds  := FindUsedLayerKinds(LayerStack);
    slUsedLPairKinds.Count;
    slUsedLayerKinds.Count;

// remove any existing pairs connected to all layers listed in inifile.
// set all new layer names
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

    EndHourGlass;
    IniFile.Free;
    slUsedLPairKinds.Free;
    slUsedLayerKinds.Free;
    Board.ViewManager_UpdateLayerTabs;
    ShowInfo('Mechanical Layer Names & Colours (& pairs) updated.');
end;

Procedure ConvertMechLayerKindToLegacy;
begin
    ConvertMechLayerKindToLegacy_Wrapped(1);
    Board.ViewManager_UpdateLayerTabs;
    ShowInfo('Converted Mechanical Layer Kinds To Legacy ..');
end;

Procedure ConvertMechLayerKindToLegacy_Wrapped(dummy : integer);
var
    MechLayer  : IPCB_MechanicalLayer;
    ML1        : integer;
    i          : Integer;

begin
    Board  := PCBServer.GetCurrentPCBBoard;
    PCBLib := PCBServer.GetCurrentPCBLibrary;
    if PCBLib <> nil then
        Board := PCBLib.Board;
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

