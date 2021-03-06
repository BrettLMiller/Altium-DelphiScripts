{ ExtractTemplate.pas
  
 from TemplateTool/SaveTemplate.pas

Original: circa Dec 2007

Modified:
 B Miller
 16/05/2021 v2.0  Fix some object stuff so objs can be selected without closing/opening etc.

 Not supported in AD20+
    .UnRegisterSchObjectFromContainer()
    .DeleteAll
}

const
    cMaxIterationLevels = 5;       // recursive protection.

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
    if new_doc <> nil then
    begin
        Result := SchServer.GetCurrentSchDocument;
    end;
end;
{..............................................................................}

{..............................................................................}
function GetTemplate(const Sheet : ISch_Document) : ISch_Template;
var
    iter : ISch_Iterator;
    obj  : ISch_BasicContainer;
begin
    Result := nil;
    if Sheet <> nil then
    begin
        iter := Sheet.SchIterator_Create;
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
end;
{..............................................................................}

{..............................................................................}
function GetContainedObjects(Container   : ISch_BasicContainer;
                             obj_list    : TObjectList;
                             Recursively : Bool;
                             var level : integer) : TObjectList;
var
    iter   : ISch_Iterator;
    child  : ISch_BasicContainer;
begin
    Result := obj_list;
    if level > cMaxIterationLevels then exit;
    inc(level);

    iter := Container.SchIterator_Create;
    iter.SetState_IterationDepth(eIterateAllLevels);
    child  := iter.FirstSchObject;
    while (child <> nil) do
    begin
        if (Recursively) and (Container.ObjectId = child.ObjectId) then
            Result := GetContainedObjects(child, obj_list, true, level)
        else
            Result.Add(child);
        child := iter.NextSchObject;
    end;
    Container.SchIterator_Destroy(iter);
end;
{..............................................................................}

{..............................................................................}
procedure MoveContainedObjects(FromContainer : ISch_BasicContainer;
                               ToContainer   : ISch_BasicContainer);
var
    obj_list : TObjectList;
    obj      : ISch_BasicContainer;
    new_obj  : ISch_BasicContainer;
    i        : Integer;
    level    : integer;

begin
// default is TObjectList owns the objects so are deleted with objectList .. BE WARNED !!
    obj_list := TObjectList.Create;
    obj_list.OwnsObjects := false;

    level := 0;
    obj_list :=  GetContainedObjects(FromContainer, obj_list, true, level);

//    ShowMessage('max iter depth : ' + IntToStr(level) );

    for i := 0 to (obj_list.count - 1) do
    begin
        obj := obj_list.Items(i);
        new_obj := obj.Replicate;
        FromContainer.RemoveSchObject(obj);
        ToContainer.RegisterSchObjectInContainer(new_obj);
        new_obj.GraphicallyInvalidate;
    end;
    obj_list.Free;
end;
{..............................................................................}

{..............................................................................}
procedure CopyContainedObjects(FromContainer : ISch_BasicContainer;
                               ToContainer   : ISch_BasicContainer);
var
    obj_list : TObjectList;
    obj      : ISch_BasicContainer;
    new_obj  : ISch_BasicContainer;
    i        : Integer;
    level    : integer;

begin
// default is TObjectList owns the objects so are deleted with objectList .. BE WARNED !!
    obj_list := TObjectList.Create;
    obj_list.OwnsObjects := false;

    level := 0;
    obj_list := GetContainedObjects(FromContainer, obj_list, true, level);
    for i := 0 to (obj_list.count - 1) do
    begin
        obj := obj_list.Items[i];
        new_obj := obj.Replicate;
        ToContainer.RegisterSchObjectInContainer(new_obj);
        new_obj.GraphicallyInvalidate;
    end;
    obj_list.free;
end;
{..............................................................................}

{..............................................................................}
procedure ExplodeTemplate;
var
    template  : ISch_Template;
    sheet     : ISch_Document;
    i         : Integer;
begin
    sheet := GetWorkingSheet(true);
    if (sheet <> nil) then
    begin
        template := GetTemplate(sheet);
        if template <> nil then
        begin
            MoveContainedObjects(template, sheet);
            sheet.RemoveSchObject(template);
            SchServer.DestroySchObject(template);
            sheet.GraphicallyInvalidate;
        end
        else
            ShowMessage('No template in sheet ');

    end;
End;
{..............................................................................}

{..............................................................................}
procedure SaveTemplate;
var
    template      : ISch_Template;
    sheet         : ISch_Document;
    new_sheet     : ISch_Document;
    i             : Integer;
begin
    sheet := GetWorkingSheet(true);
    if (sheet <> nil) then
    begin
        // Get the top level template in sheet
        template := GetTemplate(sheet);
        if template <> nil then
        begin
            new_sheet := GetNewSheet(true);
            if new_sheet <> nil then
            begin
                // Set up the new sheet size
                new_sheet.TitleBlockOn     := False;
                new_sheet.ReferenceZonesOn := False;
                if sheet.UseCustomSheet then
                begin
                    new_sheet.UseCustomSheet := true;
                    new_sheet.CustomX := sheet.CustomX;
                    new_sheet.CustomY := sheet.CustomY;
                end
                else
                begin
                    new_sheet.SheetSizeX := sheet.SheetSizeX;
                    new_sheet.SheetSizeY := sheet.SheetSizeY;
                end;

                CopyContainedObjects(template, new_sheet);

                new_sheet.UpdateDocumentProperties;
                new_sheet.GraphicallyInvalidate
            end;
        end
        else
            ShowMessage('No template in sheet ');
    end;
End;
{..............................................................................}

