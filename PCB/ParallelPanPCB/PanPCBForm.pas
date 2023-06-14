{ PanPCBForm.pas
 part of PanPCB.PrjScr
 linked with PanPCBForm.dfm
 20230614   0.23

object sbStatusBar : TStatusBar
sbStatusBar.Panels.Items(0).Text := IntToStr(Key);
}
Interface    // this is ignored in delphiscript.
type
    TPanPCBForm = class(TForm)
    editboxSelectRow     : TEdit;
    editboxCurrentPcbDoc : TEdit;
    cbOriginMode         : TComboBox;
    btnSpareButton       : TButton;
end;

const
    fMouseOverForm = 0;
    fMouseOverTarget = 1;

var
    fState : integer;
    sEntry : WideString;

procedure TPanPCBForm.PanPCBFormShow(Sender: TObject);
begin
    PanPCBForm.cbOriginMode.Items.AddStrings(slBoardRef);
    fState := fMouseOverForm;
    PanPCBForm.Timer1.Enabled := false;
end;

procedure TPanPCBForm.PanPCBFormClose(Sender: TObject; var Action: TCloseAction);
begin
    PanPCBForm.Timer1.Enabled := false;
end;

procedure TPanPCBForm.Timer1Timer(Sender: TObject);
var
    VC : TcoordPoint;
begin
    VC := nil;
    If not FocusedPCB(1) then exit;

    VC := GetViewCursor(1);
    if VC <> nil then
    begin
        sEntry := 'X' + CoordUnitToString(VC.X, eMM) + '  Y ' + CoordUnitToString(VC.Y, eMM);
        PanPCBForm.editboxSelectRow.Text  := sEntry;
        PanPCBForm.editboxCurrentPcbDoc.Text := CurrentPCB.FileName;
    end;
    PanOtherPCBDocs(1);
end;

procedure TPanPCBForm.cbOriginModeChange(Sender: TObject);
begin
    iBoardRef := cbOriginMode.ItemIndex;
end;

procedure TPanPCBForm.editboxCurrentPcbDocClick(Sender: TObject);
begin
end;

procedure TPanPCBForm.PanPCBFormMouseLeave(Sender: TObject);
begin
    cbOriginMode.ItemIndex := iBoardRef;
    PanPCBForm.Timer1.Enabled := true;
end;

procedure TPanPCBForm.PanPCBFormMouseEnter(Sender: TObject);
begin
    PanPCBForm.Timer1.Enabled := false;
end;
