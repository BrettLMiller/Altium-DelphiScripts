{  ToggleModels.pas

   Cycles thru the 4 possible states of the (2) settings for ShowBodies (extruded) & ShowStepModels

   Many options/pref settings are missing in API so just retrieve from source.

   If just need to toggle one value then do not need to read existing.
     Client.SendMessage('Pcb:SetupPreferences','ShowComponentStepModels=toggle', 255, Client.CurrentView);

   Write back to registry to cache current settings as no obvious way to trigger Altium to do this
   or to trigger a refresh of server if we change the registry.

06/06/2021  BLM  v0.10  POC works in AD17.
}

const
    cNameOfServer  = 'AdvPCB';
    cSectionName   = 'SystemOptions';
    cIniFileName   = 'Pcb_Display.ini';
// [PcbPref_Display]
    cShowComponentBodies     = 'ShowComponentBodies';
    cShowComponentStepModels = 'ShowComponentStepModels';

var
    Board      : IPCB_Board;
    Reader     : IOptionsReader;
    Writer     : IOptionsWriter;

procedure ToogleCompBodyAndModel;
var
    CurrentStep     : boolean;
    CurrentExtruded : boolean;

begin
//    If PcbServer = Nil Then
//    Client.StartServer('PCB');
    If PcbServer = Nil Then Exit;

//    Board := PcbServer.GetCurrentPCBBoard;
//    If Board = Nil Then Exit;

    CurrentExtruded := false;
    CurrentStep     := false;

    Reader := Client.OptionsManager.GetOptionsReader(cNameOfServer,'');
    if not (Reader.SectionExists(cSectionName) = -1) then exit;

    CurrentExtruded := StrToBool(Reader.ReadString(cSectionName, cShowComponentBodies, '0'));
    CurrentStep     := StrToBool(Reader.ReadString(cSectionName, cShowComponentStepModels, '0'));

    Writer := Client.OptionsManager.GetOptionsWriter(cNameOfServer);

    Client.SendMessage('PCB:SwitchTo3D', '', 255, Client.CurrentView);    //     SwitchTo2D3D

    if (not CurrentStep) and (not CurrentExtruded) then
    begin
        Client.SendMessage('Pcb:SetupPreferences','ShowComponentStepModels=true', 255, Client.CurrentView);
        Writer.WriteString(cSectionName, cShowComponentStepModels, '1');
    end;

    if (CurrentStep) and (not CurrentExtruded) then
    begin
        Client.SendMessage('Pcb:SetupPreferences','ShowComponentBodies=true', 255, Client.CurrentView);
        Writer.WriteString(cSectionName, cShowComponentBodies, '1');
    end;

    if (CurrentStep and CurrentExtruded) then
    begin
        Client.SendMessage('Pcb:SetupPreferences','ShowComponentStepModels=false', 255, Client.CurrentView);
        Client.SendMessage('Pcb:SetupPreferences','ShowComponentBodies=false', 255, Client.CurrentView);
        Writer.WriteString(cSectionName, cShowComponentStepModels, '0');
        Writer.WriteString(cSectionName, cShowComponentBodies,     '0');
    end;

//    PcbServer.SystemOptions.ShowComponentBodies     := CurrentExtruded;

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);

end;
