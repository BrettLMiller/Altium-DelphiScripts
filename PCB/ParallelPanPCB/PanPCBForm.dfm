object PanPCBForm: TPanPCBForm
  Left = 0
  Top = 0
  Hint = 'v0.11'
  Caption = 'Parallel Pan PCBs'
  ClientHeight = 213
  ClientWidth = 312
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = False
  OnClose = PanPCBFormClose
  OnMouseEnter = PanPCBFormMouseEnter
  OnMouseLeave = PanPCBFormMouseLeave
  OnShow = PanPCBFormShow
  PixelsPerInch = 96
  TextHeight = 13
  object editboxCurrentPcbDoc: TEdit
    Left = 32
    Top = 80
    Width = 168
    Height = 21
    Hint = 'Current PcbDoc'
    TabOrder = 1
    Text = 'editboxCurrentPcbDoc'
  end
  object btnSpareButton: TButton
    Left = 152
    Top = 160
    Width = 75
    Height = 25
    Caption = 'SpareButton'
    TabOrder = 2
  end
  object editboxSelectRow: TEdit
    Left = 32
    Top = 32
    Width = 160
    Height = 21
    Hint = 'Enter or Clipboard'
    TabOrder = 0
    Text = 'editboxSelectRow'
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 24
    Top = 168
  end
end
