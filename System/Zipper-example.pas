
procedure TestZipper;
var
    Zip            : TXceedZip;
    PrjFileName    : string;
    ZipFileName    : string;
    ProjectPath    : string;
    GeneratedFiles : TStringList;
    FilePath       : WideString;
    I              : Integer;
begin

    ZipFileName := 'C:\Altium\TestZip.ZIP';
    ProjectPath := 'C:\Altium\TestZIP\';

    Zip := TXCeedZip.Create(ZipFileName);

  // Setup Zipper, dont want to generate a temporary folder/file
    Zip.UseTempFile       := False;
    Zip.BasePath          := RemoveSlash(ProjectPath, cPathSeparator);

// can use FindFiles(subfolders=true) and/or ProcessSubFolders=true.
    Zip.ProcessSubfolders := false;

    GeneratedFiles := TStringList.Create;
// FileFiles() returns filenames in UPPERCASE.
    FindFiles(ProjectPath, '*.*', faAnyFile, true, GeneratedFiles);

// This returns correct case & not '.' or '..' files.
    GeneratedFiles.Clear;
    GetAllFilePathsMatchingMask(GeneratedFiles, ProjectPath, '*.*', true);

    If GeneratedFiles.Count > 0 Then
    For I := 0 to GeneratedFiles.Count - 1 Do
    begin
        FilePath := GeneratedFiles.Strings[I];

// require relative path for files & subfolders.
        FilePath := ExtractRelativePath(ProjectPath, FilePath);

// FileFiles() cleanup, not really required.
        if (FilePath = cFilename_CurrentDir) or (FilePath = cFilename_ParentDir)  then
            continue;

        Zip.AddFilesToProcess(FilePath);
    end;

    I := Zip.Zip;

    GeneratedFiles.Free;
//    Zip.CompressionLevel;
    Zip.InstanceSize;
    ShowMessage('.Zip returns: ' + IntToStr(I) + '  size:' + IntToStr(Zip.InstanceSize) );   // + '   compress:' + IntToStr(Zip.CompressionLevel));
    Zip.Free;
//    Close;
end;
