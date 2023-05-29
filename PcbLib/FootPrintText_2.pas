{ AddFootPrintText_2.pas

 PcbLib

 Add string/text to PCBLib footprints
 Could be extended to support PcbDoc.

 Warning:
 using copper layers NOT ALREADY in target PCB stack could have very BAD consequences.
 Need to save library before direct placement is working 100% (first FP is wrong).

tbd
 check for pre-existing string; but what criteria?.
 Find bottom left line/track on specific layer
 Add text in cnr, scale to fit if required

Author BLM
 from AddFootPrintText with forms nonsense ripped out
30/05/2020  v0.10  POC works
23/09/2021  v0.11  added extract FP strings for a specified layer

...................................................................................}
const
    bMechLayer = true;            // Mechancial Layers if false then copper 1 - 32
// if bMechLayer then iLayerNum is mechlayer number from 1 to 1024
//               else iLayerNum is copper layer num 1 to 32

    iLayerNum  = 21;                   // Mech21 = 21 targetlayer integer index number;
    sSizeText  = 'U13';                // dummy text for centering.
    sNewText   = '.Pattern';           // '.Designator';        // for adding
    sMatchText = '.Pattern';           // for converting

var
    Board             : IPCB_Board;
    CurrentLib        : IPCB_Library;
    Rpt               : TStringList;
    FileName          : TPCBString;
    Document          : IServerDocument;

function AddText(Footprint : IPCB_LibComponent, Layer : TLayer) : IPCB_Text; forward;

procedure ExtractFootPrintText;
var
    FPIterator  : IPCB_LibraryIterator;
    GIterator   : IPCB_GroupIterator;
    Footprint   : IPCB_Component;
    TextObj     : IPCB_Text;
    Layer       : TLayer;
    NewText     : IPCBString;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB Library document');
        Exit;
    End;

    Layer := iLayerNum;
    if bMechLayer then
        Layer := LayerUtils.MechanicalLayer(iLayerNum);

    Board := CurrentLib.Board;
    Board.LayerIsDisplayed[Layer] := True;
    Board.CurrentLayer := Layer;                // change current layer
    Board.ViewManager_UpdateLayerTabs;          // make GUI match the current layer.
    CurrentLib.RefreshView;

    Filename := ExtractFilePath(Board.FileName) + 'PcbLib_ExtractedFPText.txt';
    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('Layer : ' + Board.LayerName(Layer));
    Rpt.Add('');
    Rpt.Add('Current Footprint         | UnderlyingString ');     //            | ConvertedString ');

    FPIterator := CurrentLib.LibraryIterator_Create;
    FPIterator.SetState_FilterAll;
    FPIterator.AddFilter_LayerSet(AllLayers);
    Footprint := FPIterator.FirstPCBObject;
    While Footprint <> Nil Do
    Begin
        Board := CurrentLib.Board;
    //  one of the next 2 or 3 lines seems to fix the erronous bounding rect of the alphabetic first item in Lib list
    //  suspect it changes the Pad.Desc text as well
        CurrentLib.SetState_CurrentComponent (Footprint);
        Board.ViewManager_FullUpdate;                // makes a slideshow
        Board.GraphicalView_ZoomRedraw;


        GIterator := Footprint.GroupIterator_Create;
        GIterator.AddFilter_ObjectSet(MkSet(eTextObject));  //  MkSet(ePadObject, eViaObject));

        TextObj := GIterator.FirstPCBObject;
        while (TextObj  <> Nil) Do
        begin
        // not really relevent as PcbLib does not evaluate strings strings.
            NewText := TextObj.ConvertedString;

            if (Layer = TextObj.Layer) then
                Rpt.Add(Padright(Footprint.Name, 30) + ' | ' + PadRight(TextObj.UnderlyingString,30) );   // + ' | ' +  NewText);

            TextObj  := GIterator.NextPCBObject;
        end;
        Footprint.GroupIterator_Destroy(GIterator);
        Footprint := FPIterator.NextPCBObject;
    End;

    CurrentLib.LibraryIterator_Destroy(FPIterator);
    CurrentLib.Navigate_FirstComponent;
    CurrentLib.Board.GraphicalView_ZoomRedraw;
    CurrentLib.RefreshView;

    Rpt.SaveToFile(Filename);
    Rpt.Free;
    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
end;


procedure ConvertText;
var
    FPIterator  : IPCB_LibraryIterator;
    GIterator   : IPCB_GroupIterator;
    Footprint   : IPCB_Component;
    TextObj     : IPCB_Text;
    Layer       : TLayer;
    NewText     : IPCBString;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB Library document');
        Exit;
    End;

    Layer := iLayerNum;
    if bMechLayer then
        Layer := LayerUtils.MechanicalLayer(iLayerNum);

    Board := CurrentLib.Board;
    Board.LayerIsDisplayed[Layer] := True;
    Board.CurrentLayer := Layer;                // change current layer
    Board.ViewManager_UpdateLayerTabs;          // make GUI match the current layer.
// does not work in library!
//    Client.SendMessage('PCB:SetCurrentLayer', 'Layer=' + IntToStr(Layer) , 255, Client.CurrentView);
    CurrentLib.RefreshView;

    Filename := ExtractFilePath(Board.FileName) + 'PcbLib_ConvertFPText.txt';
    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('Layer : ' + Board.LayerName(Layer));
    Rpt.Add('');
    //Rpt.Add('Current Footprint : ' + CurrentLib.CurrentComponent.Name);

    FPIterator := CurrentLib.LibraryIterator_Create;
    FPIterator.SetState_FilterAll;
    FPIterator.AddFilter_LayerSet(AllLayers);
    Footprint := FPIterator.FirstPCBObject;
    While Footprint <> Nil Do
    Begin
        Board := CurrentLib.Board;
    //  one of the next 3 or 4 lines seems to fix the erronous bounding rect of the alphabetic first item in Lib list
    //  suspect it changes the Pad.Desc text as well
        CurrentLib.SetState_CurrentComponent (Footprint);
        Board.ViewManager_FullUpdate;                // makes a slideshow
        Board.GraphicalView_ZoomRedraw;

        Rpt.Add('Current Footprint : ' + Footprint.Name);

        GIterator := Footprint.GroupIterator_Create;
        GIterator.AddFilter_ObjectSet(MkSet(eTextObject));  //  MkSet(ePadObject, eViaObject));

        TextObj := GIterator.FirstPCBObject;
        while (TextObj  <> Nil) Do
        begin
            TextObj.BeginModify;

            NewText := TextObj.ConvertedString;
            If (sMatchText = '.Designator') then
                NewText := Footprint.Name;
            If (sMatchText = '.Pattern') then
                NewText := Footprint.Name;      //   PcbDoc  Footprint.Pattern

            if (Layer = TextObj.Layer) then
            if (sMatchText = TextObj.UnderlyingString) or (QuoteWith(sMatchText, '''') = TextObj.UnderlyingString) then
            begin
                TextObj.SetState_Text(NewText);
                TextObj.SetState_XSizeYSize;
            end;
            TextObj.EndModify;

            TextObj  := GIterator.NextPCBObject;
        end;
        Footprint.GroupIterator_Destroy(GIterator);

//        if TextObj.IsHidden then
//            Board.ShowPCBObject(TextObj);
//        Rpt.Add('');

        Footprint := FPIterator.NextPCBObject;
    End;

    CurrentLib.LibraryIterator_Destroy(FPIterator);
    CurrentLib.Navigate_FirstComponent;
    CurrentLib.Board.GraphicalView_ZoomRedraw;
    CurrentLib.RefreshView;

    Rpt.SaveToFile(Filename);
    Rpt.Free;
    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
end;

Procedure AddFootPrintText;   // to run directly..
Var
    FootprintIterator : IPCB_LibraryIterator;
//    Iterator          : IPCB_GroupIterator;
    Footprint         : IPCB_Component;
    TextObj           : IPCB_Text;

    Layer             : TLayer;
    Box               : TCoordRect;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    CurrentLib := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB Library document');
        Exit;
    End;

    Layer := iLayerNum;
    if bMechLayer then
        Layer := LayerUtils.MechanicalLayer(iLayerNum);

    Board := CurrentLib.Board;
    Board.LayerIsDisplayed[Layer] := True;
    Board.CurrentLayer := Layer;                // change current layer
    Board.ViewManager_UpdateLayerTabs;          // make GUI match the current layer.
// does not work in library!
//    Client.SendMessage('PCB:SetCurrentLayer', 'Layer=' + IntToStr(Layer) , 255, Client.CurrentView);
    CurrentLib.RefreshView;

    FootprintIterator := CurrentLib.LibraryIterator_Create;
    FootprintIterator.SetState_FilterAll;
    FootprintIterator.AddFilter_LayerSet(AllLayers);

    Filename := ExtractFilePath(Board.FileName) + 'PcbLib_AddFPText.txt';
    Rpt := TStringList.Create;
    Rpt.Add(ExtractFileName(Board.FileName));
    Rpt.Add('Layer : ' + Board.LayerName(Layer));
    Rpt.Add('');
    //Rpt.Add('Current Footprint : ' + CurrentLib.CurrentComponent.Name);

    // A footprint is a IPCB_LibComponent inherited from
    Footprint := FootprintIterator.FirstPCBObject;
    While Footprint <> Nil Do
    Begin
        Board := CurrentLib.Board;
    //  one of the next 3 or 4 lines seems to fix the erronous bounding rect of the alphabetic first item in Lib list
    //  suspect it changes the Pad.Desc text as well
        CurrentLib.SetState_CurrentComponent (Footprint);
        Board.ViewManager_FullUpdate;                // makes a slideshow
        Board.GraphicalView_ZoomRedraw;

        Rpt.Add('Current Footprint : ' + Footprint.Name);

        Box := Footprint.BoundingRectangle;
      //   RectToCoordRect(Footprint.BoundingRectangleNoNameComment);  // PCB only

      // CoordUnitToString(Footprint.Height, eImperial) = '0mil'
      // StringToCoordUnit(GeometryHeight, NewHeight, eImperial);


        TextObj := AddText(Footprint, Layer);

        if TextObj.IsHidden then
            Board.ShowPCBObject(TextObj);
        Rpt.Add('');

        Footprint := FootprintIterator.NextPCBObject;
    End;

    CurrentLib.LibraryIterator_Destroy(FootprintIterator);

    CurrentLib.Navigate_FirstComponent;
    CurrentLib.Board.GraphicalView_ZoomRedraw;
    CurrentLib.RefreshView;

    Rpt.SaveToFile(Filename);
    Rpt.Free;
    Document  := Client.OpenDocument('Text', FileName);
    If Document <> Nil Then
    begin
        Client.ShowDocument(Document);
        if (Document.GetIsShown <> 0 ) then
            Document.DoFileLoad;
    end;
End;

function AddText(Footprint : IPCB_LibComponent, Layer : TLayer) : IPCB_Text;
begin
    PCBServer.PreProcess;
    Result := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);

    Result.XLocation  := Board.XOrigin + MilsToCoord(-10);
    Result.YLocation  := Board.YOrigin + MilsToCoord(-10);
    Result.Layer      := Layer;
//    Result.IsHidden := false;
    Result.UseTTFonts := false;
    Result.UnderlyingString  := sNewText;
    Result.Size       := MilsToCoord(10);    // sets the height of the text.
    Result.Width      := MilsToCoord(1);;

    Footprint.AddPCBObject(Result);       // this DNW; not enough in PcbLib
    Board.AddPCBObject(Result);           // each board is the FP in library

    PCBServer.SendMessageToRobots(Footprint.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);
// using below ONLY results in odd placement behaviour: first placed FP has NO extra text ??
// if you don't save the library BEFORE placing FP the first placed FP has NO text
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Result.I_ObjectAddress);

    PCBServer.PostProcess;
end;
{..............................................................................}

