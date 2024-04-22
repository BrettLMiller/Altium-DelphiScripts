object CCForm: TCCForm
  Left = 0
  Top = 0
  Caption = 'Class Connections'
  ClientHeight = 160
  ClientWidth = 308
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnMouseEnter = CCFormMouseEnter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ComboBox1: TComboBox
    Left = 23
    Top = 17
    Width = 184
    Height = 21
    TabOrder = 0
    Text = 'cb1-NetClasses'
  end
  object butShow: TButton
    Left = 20
    Top = 90
    Width = 60
    Height = 25
    Caption = 'Show'
    TabOrder = 1
    OnClick = butShowClick
  end
  object butHide: TButton
    Left = 95
    Top = 90
    Width = 60
    Height = 25
    Caption = 'Hide'
    TabOrder = 2
    OnClick = butHideClick
  end
  object ComboBox2: TComboBox
    Left = 23
    Top = 49
    Width = 184
    Height = 21
    TabOrder = 3
    Text = 'cb1-CMPClasses'
  end
  object butLogic: TButton
    Left = 228
    Top = 13
    Width = 60
    Height = 25
    Caption = 'AND/OR'
    Style = bsSplitButton
    TabOrder = 4
    OnClick = butLogicClick
  end
  object butShowAll: TButton
    Left = 20
    Top = 125
    Width = 60
    Height = 25
    Caption = 'Show All'
    TabOrder = 5
    OnClick = butShowAllClick
  end
  object butHideAll: TButton
    Left = 95
    Top = 125
    Width = 60
    Height = 25
    Caption = 'Hide All'
    TabOrder = 6
    OnClick = butHideAllClick
  end
  object butColour: TButton
    Left = 248
    Top = 90
    Width = 45
    Height = 25
    Caption = 'Colour'
    TabOrder = 7
    OnClick = butColourClick
  end
  object butDefColour: TButton
    Left = 248
    Top = 125
    Width = 45
    Height = 25
    Caption = 'Default'
    TabOrder = 8
    OnClick = butDefColourClick
  end
  object butHighlight: TButton
    Left = 170
    Top = 90
    Width = 60
    Height = 25
    Caption = 'Hi-Lite'
    TabOrder = 9
    OnClick = butHighlightClick
  end
  object ColorDialog1: TColorDialog
    Left = 264
    Top = 52
  end
end
