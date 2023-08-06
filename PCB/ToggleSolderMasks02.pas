{ ToogleSolderMasks02.pas


PCB:SetupPreferences
PositiveTopSolderMask=Toggle
}

procedure ToggleSM;
var
    Board        : IPCB_Board;
    
begin
    If PcbServer = Nil Then Exit;
    Board := PcbServer.GetCurrentPCBBoard;

    Client.SendMessage('PCB:SetupPreferences', 'PositiveTopSolderMask=Toggle', 256, Client.CurrentView);
    Client.SendMessage('PCB:SetupPreferences', 'PositiveBottomSolderMask=Toggle', 256, Client.CurrentView);

// required AD17
    Client.SendMessage('PCB:Zoom', 'Action = Redraw', 256, Client.CurrentView);

// more required AD21.9
    Board.ViewManager_UpdateLayerTabs;
// is this enough to replace above ?    
    PcbServer.RefreshDocumentView(Board.FileName);
end;
