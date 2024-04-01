{ ShowClassConnections.pas / ClassConnForm.pas
  Form & event code ONLY.
}

Interface    // this is ignored in delphiscript.
type
    TCCForm      = class(TForm)
    ComboBox1    : TComboBox;
    ComboBox2    : TComboBox;
    butLogic     : TButton;
    butShow      : TButton;
    butHide      : TButton;
    butShowAll   : TButton;
    butHideAll   : TButton;
    butColour    : TButton;
    butDefColour : TButton;
    ColorDialog1 : TColorDialog;
end;

procedure FormReloadDialogs(dummy : integer); forward;

function TCCForm.ShowForm(dummy : integer) : boolean;
begin
    CCForm.FormStyle := fsStayOnTop;
    CCForm.Show;
end;

function TCCForm.FormCreate(Sender: TObject);
begin
    CCForm.Caption := CCForm .Caption + '_V0.22';
    CCForm.butLogic.Caption := SetOperation(false);
    CCForm.ColorDialog1.Color := clRed;
End;

function TCCForm.FormShow(Sender: TObject);
begin
    RefreshBoard(1);
    FormReloadDialogs(1);

    CCForm.ComboBox1.Text := CCForm.ComboBox1.Items(0);
    CCForm.ComboBox2.Text := CCForm.ComboBox2.Items(0);
End;

procedure TCCForm.CCFormMouseEnter(Sender: TObject);
begin
    RefreshBoard(1);
    FormReloadDialogs(1);
end;

procedure FormReloadDialogs(dummy : integer);
var
    NetClass  : IPCB_ObjectClass;
    I         : integer;
    ItemIndex : integer;
begin
// could check if existing .Text exists in new "collection" & reset it ?
// check/fix the index
    ItemIndex := ComboBox1.ItemIndex;
    if not (ItemIndex < NetClasses.Count) then
    begin
        ComboBox1.ItemIndex := 0;
        NetClass := NetClasses.Items(0);
        CCForm.ComboBox1.Text := NetClass.Name;
    end;
// trim the top
    while (CCForm.ComboBox1.Items.Count > NetClasses.Count) do
        CCForm.ComboBox1.Items.Delete(CCForm.ComboBox1.Items.Count - 1);
// refresh & add
    for I := 0 to (NetClasses.Count - 1) do
    begin
        NetClass := NetClasses.Items(I);
        if I < CCForm.ComboBox1.Items.Count then
            CCForm.ComboBox1.Items(I) := NetClass.Name
        else
            CCForm.ComboBox1.Items.Add(NetClass.Name);
    end;
    if CCForm.ComboBox1.Items.Count = 0 then
        CCForm.ComboBox1.Text := 'no Net Classes';

    ItemIndex := ComboBox2.ItemIndex;
    if not (ItemIndex < CMPClasses.Count) then
    begin
        ComboBox2.ItemIndex := 0;
        NetClass := CMPClasses.Items(0);
        CCForm.ComboBox2.Text := NetClass.Name;
    end;

    while (CCForm.ComboBox2.Items.Count > CMPClasses.Count) do
        CCForm.ComboBox2.Items.Delete(CCForm.ComboBox2.Items.Count - 1);

    for I := 0 to (CMPClasses.Count - 1) do
    begin
        NetClass := CMPClasses.Items(I);
        if I < CCForm.ComboBox2.Items.Count then
            CCForm.ComboBox2.Items(I) := NetClass.Name
        else
            CCForm.ComboBox2.Items.Add(NetClass.Name);
    end;
    if CCForm.ComboBox2.Items.Count = 0 then
        CCForm.ComboBox2.Text := 'no CMP classes';

    NetClass := nil;
end;

procedure TCCForm.butShowClick(Sender);   // Show Connections
begin
    ActionRatNests(ComboBox1.Text, ComboBox2.Text, 1);
End;

procedure TCCForm.butHideClick(Sender);  // Hide Connections
begin
    ActionRatNests(ComboBox1.Text, ComboBox2.Text, 0);
End;

procedure TCCForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    CCForm.ComboBox1.Free;
    CCForm.ComboBox2.Free;
    CCForm.ColorDialog1.Free;
    CleanExit(1);
end;

procedure TCCForm.butLogicClick(Sender: TObject);
begin
    CCForm.butLogic.Caption := SetOperation(true);
end;

procedure TCCForm.butShowAllClick(Sender: TObject);
begin
    ActionRatNests(cAllNetsClass, cAllCMPsClass, 1);
end;

procedure TCCForm.butHideAllClick(Sender: TObject);
begin
    ActionRatNests(cAllNetsClass, cAllCMPsClass, 0);
end;

procedure TCCForm.butColourClick(Sender: TObject);
var
    Colour : TColor;
begin
    if CCForm.ColorDialog1.Execute then
    begin
        Colour := CCForm.ColorDialog1.Color;
        ActionColour(ComboBox1.Text, ComboBox2.Text, Colour, 1);
    end;
end;

procedure TCCForm.butDefColourClick(Sender: TObject);
var
    Colour : TColor;
begin
    Colour := cDefaultColour;
    ActionColour(ComboBox1.Text, ComboBox2.Text, Colour, 1);
end;


