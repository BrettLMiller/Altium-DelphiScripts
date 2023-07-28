{ ExtractTemplate.pas

 from TemplateTool/SaveTemplate.pas

Original: circa Dec 2007

Modified:
 B Miller
 16/05/2021 v2.0  Fix some object stuff so objs can be selected without closing/opening etc.
 10/12/2021 v2.1  removed (unnecessary?) obj.GraphicallyInvalidate
 02/08/2022 v2.2  TObjectList --> TList; remove automatic template in new doc creation.
 2023-07-06 v2.3  Add AddAllToTemplate(): add all sheet objects into template (create if required).

 Not supported in AD20+
    .UnRegisterSchObjectFromContainer()
    .DeleteAll

saving template containing a component caused exception but works.
tbd: unsure why recusive search must be used. Is it the ObjectID test ?
}

const
    cMaxIterationLevels = 5;       // recursive protection.
    cDefaultTemplate    = 'C:\Altium Projects\Templates\_Template_A2.SchDot';

{..............................................................................}
function GetWorkingSheet(const dummy : boolean) : ISch_Document;
begin
    Result := nil;
    if (SchServer <> nil) then
        Result := SchServer.GetCurrentSchDocument;
end;
{..............................................................................}
{..............................................................................}
function GetNewSheet(const dummy : boolean) : ISch_Document;
var
    new_doc : IServerDocument;
begin
    new_doc := CreateNewDocumentFromDocumentKind(cDocKind_Sch);
    if (new_doc <> nil) then
        Result := SchServer.GetCurrentSchDocument;
end;
{..............................................................................}
{..............................................................................}
function GetTemplate(const Sheet : ISch_Document) : ISch_Template;
var
    iter : ISch_Iterator;
    obj  : ISch_BasicContainer;
begin
    Result := nil;
    if Sheet = nil then exit;

    iter := Sheet.SchIterator_Create;
    iter.SetState_FilterAll;
    iter.SetState_IterationDepth(eIterateFirstLevel);
    obj  := iter.FirstSchObject;
    while (obj <> nil) do
    begin
        if obj.ObjectId = eTemplate then
        begin
            Result := obj;
            break;
        end;
        obj := iter.NextSchObject;
    end;
    Sheet.SchIterator_Destroy(iter);
end;
{..............................................................................}
{..............................................................................}
function GetContainedObjects(Container         : ISch_BasicContainer;
                             obj_list          : TList;
                             Recursively       : Boolean;
                             var level         : integer) : TList;
var
    iter   : ISch_Iterator;
    child  : ISch_BasicContainer;
begin
    Result := obj_list;
    if level > cMaxIterationLevels then exit;
    inc(level);

    iter := Container.SchIterator_Create;
    iter.SetState_FilterAll;
// must be firstLevel to work with components etc
    iter.SetState_IterationDepth(eIterateFirstLevel);    // eIterate[All,First,Filtered]Level[s]
    child  := iter.FirstSchObject;
    while (child <> nil) do
    begin
        if (Recursively)  and (Container.ObjectID = child.ObjectID) then
            Result := GetContainedObjects(child, obj_list, true, level)
        else
            Result.Add(child);
        child := iter.NextSchObject;
    end;
    Container.SchIterator_Destroy(iter);
end;
{..............................................................................}
{..............................................................................}
function MoveContainedObjects(FromContainer : ISch_BasicContainer;
                              ToContainer   : ISch_BasicContainer) : boolean;
var
    obj_list : TList;
    obj      : ISch_BasicContainer;
    new_obj  : ISch_BasicContainer;
    i        : Integer;
    level    : integer;

begin
    Result := false;
    obj_list := TList.Create;

    level := 0;
    obj_list :=  GetContainedObjects(FromContainer, obj_list, true, level);

    for i := 0 to (obj_list.count - 1) do
    begin
        obj := obj_list.Items(i);

//  one container can be inside the other.
//  do not move ToContainer self (template) else stuff vanishes!
        if obj = ToContainer then continue;
        if obj = FromContainer then continue;

        new_obj := obj.Replicate;
        FromContainer.RemoveSchObject(obj);
        if ToContainer.ObjectID <> eTemplate then
            ToContainer.RegisterSchObjectInContainer(new_obj)
        else
            ToContainer.AddSchObject(new_obj);

        Result := true;
    end;
    obj_list.Free;
end;
{..............................................................................}
{..............................................................................}
procedure CopyContainedObjects(FromContainer : ISch_BasicContainer;
                               ToContainer   : ISch_BasicContainer);
var
    obj_list : TList;
    obj      : ISch_BasicContainer;
    new_obj  : ISch_BasicContainer;
    i        : Integer;
    level    : integer;

begin
    obj_list := TList.Create;

    level := 0;
    obj_list := GetContainedObjects(FromContainer, obj_list, true, level);
    for i := 0 to (obj_list.count - 1) do
    begin
        obj := obj_list.Items(i);
        new_obj := obj.Replicate;
        if ToContainer.ObjectID <> eTemplate then
            ToContainer.RegisterSchObjectInContainer(new_obj)
        else
            ToContainer.AddSchObject(new_obj);
    end;
    obj_list.free;
end;
{..............................................................................}
{..............................................................................}
procedure ExplodeTemplate;
var
    template  : ISch_Template;
    sheet     : ISch_Document;
begin
    sheet := GetWorkingSheet(true);
    if (sheet = nil) then exit;

    SchServer.ProcessControl.PreProcess(sheet, '');

    template := GetTemplate(sheet);
    if template <> nil then
    begin
        if MoveContainedObjects(template, sheet) then
        begin
            sheet.RemoveSchObject(template);
            SchServer.DestroySchObject(template);
            sheet.GraphicallyInvalidate;
        end else
            ShowMessage('failed to move any objects ');
    end else
        ShowMessage('No template in sheet ');

    SchServer.ProcessControl.PostProcess(sheet, '');
End;
{..............................................................................}
{..............................................................................}
function GetAllTemplates(const Sheet : ISch_Document) : TList;
var
    iter : ISch_Iterator;
    obj  : ISch_BasicContainer;
begin
    Result := TList.Create;
    if Sheet = nil then exit;

    iter := Sheet.SchIterator_Create;
    iter.SetState_IterationDepth(eIterateAllLevels);
    obj  := iter.FirstSchObject;
    while (obj <> nil) do
    begin
        if obj.ObjectId = eTemplate then
        begin
            Result.Add(obj);
        end;
        obj := iter.NextSchObject;
    end;
    Sheet.SchIterator_Destroy(iter);
end;
{..............................................................................}
{..............................................................................}
procedure AddAllToSheetTemplate;
var
    template   : ISch_Template;
    templates  : TList;
    sheet      : ISch_Document;
    Success    : boolean;
begin
    sheet := GetWorkingSheet(true);
    if (sheet = nil) then exit;

    templates := GetAllTemplates(sheet);
    if templates <> nil then
    begin
        if templates.Count = 0 then
            ShowMessage('no existing template, will create ');
        if templates.Count > 1 then
            ShowMessage('found multiple templates, explode & check : ' + IntToStr(templates.Count));
        if templates.Count > 1 then exit;    
    end;

    SchServer.ProcessControl.PreProcess(sheet, '');

    if templates.Count = 0 then
    begin
        template := Schserver.SchObjectFactory(eTemplate, eCreate_GlobalCopy);
        sheet.AddSchObject(template);
        sheet.RegisterSchObjectInContainer(template);
    end else
        template := templates.Items(0);

    templates.free;

    Success := MoveContainedObjects(sheet, template);
    sheet.GraphicallyInvalidate;
    SchServer.ProcessControl.PostProcess(sheet, '');

    if not Success then
        ShowMessage('failed to move objs into new template ');
end;
{..............................................................................}
{..............................................................................}
procedure ReportNumOfTemplatesInSheet;
var
    sheet     : ISch_Document;
    templates : TList;
begin
    sheet := GetWorkingSheet(true);
    if (sheet = nil) then exit;

    templates := GetAllTemplates(sheet);
    if templates <> nil then
        ShowMessage('num templates ' + IntToStr(templates.count));

    templates.free;
end;

procedure DeleteAllTemplatesInsheet;
var
    sheet     : ISch_Document;
    template  : ISch_Template;
    templates : TList;
    I         : integer;
begin
    sheet := GetWorkingSheet(true);
    if (sheet = nil) then exit;

    SchServer.ProcessControl.PreProcess(sheet, '');

    // Get the top level template in sheet
    templates := GetAllTemplates(sheet);
    for I := 0 to (templates.Count - 1) do
    begin
        template := templates.Items(I);
        template.FreeAllContainedObjects;
        sheet.RemoveSchObject(template);
        SchServer.DestroySchObject(template);
    end;
    templates.free;

    SchServer.ProcessControl.PostProcess(sheet, '');
    sheet.GraphicallyInvalidate;

    ShowMessage('deleted ' + IntToStr(I) + ' templates ');
end;

{..............................................................................}
procedure SaveTemplateToNewSheet;
var
    template      : ISch_Template;
    new_template  : ISch_Template;
    sheet         : ISch_Document;
    new_sheet     : ISch_Document;
    i             : Integer;
begin
    sheet := GetWorkingSheet(true);
    if (sheet = nil) then exit;

    // Get the top level template in sheet
    template := GetTemplate(sheet);
    if template <> nil then
    begin
//        Schserver.Preferences.DefaultTemplateFileName := cDefaultTemplate;
        new_sheet := GetNewSheet(true);

        if new_sheet <> nil then
        begin
            SchServer.ProcessControl.PreProcess(new_sheet, '');
//    remove any automatic template with the new doc.
            new_template := GetTemplate(new_sheet);
            if new_template <> nil then
            begin
                new_sheet.RemoveSchObject(new_template);
                SchServer.DestroySchObject(new_template);
            end;

            // Set up the new sheet size
            new_sheet.TitleBlockOn     := False;
            new_sheet.ReferenceZonesOn := False;
            if sheet.UseCustomSheet then
            begin
                new_sheet.UseCustomSheet := true;
                new_sheet.CustomX := sheet.CustomX;
                new_sheet.CustomY := sheet.CustomY;
            end else
            begin
                new_sheet.SheetSizeX := sheet.SheetSizeX;
                new_sheet.SheetSizeY := sheet.SheetSizeY;
            end;

            CopyContainedObjects(template, new_sheet);

            new_sheet.UpdateDocumentProperties;
            new_sheet.GraphicallyInvalidate;
            SchServer.ProcessControl.PostProcess(new_sheet, '');
        end;
    end else
        ShowMessage('No template in sheet ');
End;
{..............................................................................}
