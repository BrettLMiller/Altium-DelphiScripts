{ EmbedLayerColours.pas

store (& restore) PCB Board layer colours in/from the PcbDoc file.

Author BL Miller
20221120 : 0.1 POC Embed colours as text in EmbedObj.
}

const
    EOColour   = 'EmbeddedColours';     // specific private name of Colours

var
    Board       : IPCB_Board;
    PCBSysOpts  : IPCB_SystemOptions;
    LIterator   : IPCB_LayerObjectIterator;
    LayerObj    : IPCB_LayerObject;

function GetEmbeddedObj(Name : WideString) : IPCB_Embedded; forward;
function AddEmbeddedObj(Name : WideString, const Desc : WideString) : IPCB_Embedded; forward;

procedure RestoreColoursFromBoard;
var
    EmbedObj     : IPCB_Embedded;
    Name         : WideString;
    Layer        : TLayer;
    Data         : TStringList;
    I            : integer;
    Colour       : WideString;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    Name := EOColour;
    Data := TStringList.Create;
    Data.NameValueSeparator := '=';
    Data.Delimiter          := '|';

    EmbedObj := GetEmbeddedObj(Name);

    if EmbedObj <> nil then
        Data.DelimitedText := EmbedObj.Description
    else
        exit;

    LIterator := Board.LayerIterator;
    LIterator.First;
    While LIterator.Next Do
    Begin
        LayerObj := LIterator.LayerObject;
        Layer    := LayerObj.V7_LayerID.ID;
        I := -1;
        I := Data.IndexOfName('Layer' + IntToStr(Layer));
        if I > -1 then
        begin
            Colour := Data.ValueFromIndex(I);
            PCBSysOpts.LayerColors(Layer) := StrToInt(Colour);
        end;
    end;

    LIterator := Board.MechanicalLayerIterator;
    While LIterator.Next Do
    Begin
        Layer := LIterator.Layer;
        I := -1;
        I := Data.IndexOfName('MLayer' + IntToStr(Layer));
        if I > -1 then
        begin
            Colour := Data.ValueFromIndex(I);
            PCBSysOpts.LayerColors(Layer) := StrToInt(Colour);
        end;
    end;

    Board.ViewManager_UpdateLayerTabs;
    ShowInfo('Layer Colours updated.');
end;

procedure StoreColoursInBoard;
var
    EmbedObj     : IPCB_Embedded;
    Name         : WideString;
    Layer        : TLayer;
    Data         : TStringList;
    I            : integer;
    Colour       : WideString;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;
    PCBSysOpts := PCBServer.SystemOptions;
    If PCBSysOpts = Nil Then exit;

    Name := EOColour;
    Data := TStringList.Create;
    Data.NameValueSeparator := '=';
    Data.Delimiter          := '|';

    I := 0;
    LIterator := Board.LayerIterator;
    While LIterator.Next Do
    Begin
        LayerObj := LIterator.LayerObject;
        Layer := LayerObj.V7_LayerID.ID;
//        Layer    := LIterator.Layer;
        Colour := IntToStr(PCBSysOpts.LayerColors(Layer));
        Data.Add('Layer' + IntToStr(Layer) +'=' + Colour);
        inc(I);
    end;

    LIterator := Board.MechanicalLayerIterator;
    While LIterator.Next Do
    Begin
        Layer    := LIterator.Layer;
        Colour := IntToStr(PCBSysOpts.LayerColors(Layer));
        Data.Add('MLayer' + IntToStr(Layer) +'=' + Colour);
        inc(I);
    end;

    EmbedObj := GetEmbeddedObj(Name);

    Board.BeginModify;

    if EmbedObj <> nil then
        EmbedObj.Description := Data.DelimitedText
    else
        AddEmbeddedObj(Name, Data.DelimitedText);

    Board.EndModify;
end;

procedure RemoveColourEmbed;
var
    EmbedObj     : IPCB_Embedded;
    Name         : WideString;
begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowWarning('This document is not a PCB document!');
        Exit;
    End;

    Name := EOColour;
    EmbedObj := GetEmbeddedObj(Name);

    if EmbedObj <> nil then
    begin
        Board.BeginModify;
        EmbedObj.Description := '';
        Board.RemovePCBObject(EmbedObj);
        PCBServer.DestroyPCBObject(EmBedObj);
        Board.EndModify;
    end;
end;

//---------------------------------------------------------------------------------------
function GetEmbeddedObj(Name : WideString) : IPCB_Embedded;
Var
    EmbedObj  : IPCB_Embedded;
    BIterator : IPCB_BoardIterator;
    LayerSet  : IPCB_LayerSet;
    Primitive : IPCB_Primitive;
begin
    Result := nil;
    LayerSet := LayerSetUtils.CreateLayerSet.IncludeAllLayers;
    BIterator := Board.BoardIterator_Create;
    BIterator.AddFilter_ObjectSet(MkSet(eEmbeddedObject));
    BIterator.AddFilter_IPCB_LayerSet(LayerSet);
    BIterator.AddFilter_Method(eProcessAll);

    EmbedObj := BIterator.FirstPCBObject;
    while (EmbedObj <> Nil) do
    begin
        if EmbedObj.Name = Name then
            Result := EmbedObj;
        EmbedObj := BIterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(BIterator);
end;

function AddEmbeddedObj(Name : WideString, const Desc : WideString) : IPCB_Embedded;
Var
    EmbedObj  : IPCB_Embedded;
begin
    // Embedded object created.
    EmbedObj := PCBServer.PCBObjectFactory(eEmbeddedObject, eNoDimension, eCreate_Default);
    EmbedObj.Name        := Name;
    EmbedObj.Description := Desc;
    EmbedObj.Layer       := LayerUtils.MechanicalLayer(1);  // ??
    Board.AddPCBObject(EmbedObj);
    Result := EmbedObj;
end;



