{ RunOutJobDocs.pas
    (from OJ-Dump.pas)
    runs all OutJobs in project
    runs the Containers (OutputMedium) that have connected Outputers.

Author : BL Miller
    The Server Process Parameters mostly derived from Kevin Benstead
    see https://forum.live.altium.com/#/posts/258115/832922

2024-06-05  v0.10 POC

}

const
    bOpenReport = true;
var
    Rpt : TStringList;

function ProcessOJDoc(OJDoc : TJobManagerDocument) : integer; forward;

Procedure Command_RunOutputJobs;   
Var
    WorkSpace   : IWorkspace;
    Project     : IProject;
    FilePath    : String;
    ProjectDoc  : IDocument;
    ServerDoc   : IServerDocument;
    i           : Integer;

Begin
    WorkSpace := GetWorkspace;
    If WorkSpace = Nil then Exit;
    Project := WorkSpace.DM_FocusedProject;
    If Project = Nil Then Exit;

    If Project.DM_NeedsCompile Then
        Project.DM_Compile;

    Rpt := TStringList.Create;

    For i := 0 To (Project.DM_LogicalDocumentCount - 1) Do
    Begin
        ProjectDoc := Project.DM_LogicalDocuments(i);

        If ProjectDoc.DM_DocumentKind = cDocKind_OutputJob Then
        Begin
            FilePath := ProjectDoc.DM_FullPath;
            ServerDoc  := Client.OpenDocument(cDocKind_OutputJob, FilePath);
            If ServerDoc = Nil Then continue;

            Rpt.Add(FilePath);
            Client.ShowDocument(ServerDoc);
            ProcessOJDoc(ServerDoc);
        End;
    End;

    FilePath := SpecialFolder_TemporarySlash + 'RunOJDocsReport1.txt';
    Rpt.SaveToFile(FilePath);
    Rpt.Free;

    if bOpenReport then
    begin
        ServerDoc  := Client.OpenDocument('Text', FilePath);
        If (ServerDoc <> Nil) Then
        begin
            Client.ShowDocument(ServerDoc);
            if (ServerDoc.GetIsShown <> 0 ) then
                ServerDoc.DoFileLoad;
        end;
    end;
End;

 // TJobManagerDocument;  IWSM_OutputJobDocument;
function ProcessOJDoc(OJDoc : TJobManagerDocument) : integer;
var
    OJContainer : IOutputMedium;
    Output      : IOutputer;
    i, j        : Integer;
    Process     : String;
    Parameters  : Widestring;
    OutCount    : integer;

begin
    Result := OJDoc.OutputMediumCount;

    For i := 0 to (Result - 1) Do
    Begin
        OJContainer := OJDoc.OutputMedium(i);

        OutCount := OJDoc.MediumOutputersCount(OJContainer);
        if OutCount < 1 then
        begin
            Rpt.Add('No Outputers connected to Container ' + OJContainer.Name + '  Type: ' + OJContainer.TypeString);
            Rpt.Add('');
            continue;
        end;

        Rpt.Add('Running container ' + OJContainer.Name + '  Type: ' + OJContainer.TypeString + '  Path: ' + OJContainer.Outputpath);
        for j := 0 to (OutCount - 1) do
        begin
            Output := OJDoc.MediumOutputer(OJContainer, j);
            Rpt.Add('  ' + IntToStr(j+1) + ' for Outputer ' + Output.DM_GeneratorName + '  var: ' + OutPut.VariantName);
        end;

        Case OJContainer.TypeString Of
           'Generate Files' :   // generate files e.g boms, gerbers etc
            Begin
                ResetParameters;
                AddStringParameter ('Action',        'Run');
                AddStringParameter ('ObjectKind',    'OutputBatch');
                AddStringParameter ('OutputMedium',  OJContainer.Name);
                AddStringParameter ('DisableDialog', 'True');
                RunProcess('WorkspaceManager:GenerateReport');
                Rpt.Add(OJContainer.Name + ' generated');
            End;
            'PDF' :              // generate PDF files e.g schematics, assembly drawings etc
            Begin
                ResetParameters;
                AddStringParameter ('Action',        'PublishToPDF');
                AddStringParameter ('ObjectKind',    'OutputBatch');
                AddStringParameter ('OutputMedium',  OJContainer.Name);
                AddStringParameter ('DisableDialog', 'True');
                RunProcess('WorkspaceManager:Print');
                Rpt.Add(OJContainer.Name + ' generated');
            End;
            'Print' :
            begin
                ResetParameters;
//                AddStringParameter ('Action',        'PrintDocument');
                AddStringParameter ('Action',        'Preview');
                AddStringParameter ('ObjectKind',    'OutputBatch');
                AddStringParameter ('OutputMedium',  OJContainer.Name);
                AddStringParameter ('DisableDialog', 'True');
                RunProcess('WorkspaceManager:Print');
                Rpt.Add(OJContainer.Name + ' generated');
            end;
        Else
            Rpt.Add('Unknown Container Type of Name: ' + OJContainer.Name + '  Type: ' + OJContainer.TypeString);
        End;

{
alt syntax.
        Process    := 'WorkspaceManager:Print';
        Parameters := 'Action=PublishToPDF|DisableDialog=True|ObjectKind=OutputBatch';
        // Parameters := 'Action=PublishMultimedia|DisableDialog=True|ObjectKind=OutputBatch';

         Client.SendMessage(Process, Parameters, 256, Client.CurrentView);
}
        Rpt.Add('');
    End;
end;

