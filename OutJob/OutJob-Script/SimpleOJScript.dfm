object FormPickFromList: TFormPickFromList
  Left = 500
  Top = 600
  Align = alCustom
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  BorderWidth = 2
  Caption = 'Pick Option'
  ClientHeight = 213
  ClientWidth = 299
  Color = clBtnFace
  Constraints.MaxHeight = 250
  Constraints.MaxWidth = 350
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poDefaultSizeOnly
  OnCreate = FormPickFromListCreate
  PixelsPerInch = 96
  TextHeight = 13
  object ComboBoxFiles: TComboBox
    Left = 40
    Top = 24
    Width = 184
    Height = 21
    TabOrder = 0
    Text = 'Pick a listed item'
  end
  object ButtonExit: TButton
    Left = 56
    Top = 160
    Width = 104
    Height = 24
    Caption = 'Done'
    TabOrder = 1
    OnClick = ButtonExitClick
  end
end
