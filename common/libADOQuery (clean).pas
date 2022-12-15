{ libADOQuery.pas

Author BL Miller

29/09/2020  0.10 rework as shared libADOQuery
05/10/2020  0.12 Just use variable to hold last Databasefile as connection string is changed (made useless) by provider / something..
            0.13 just pass dummy to libADOclose() so can call from external unit
09/10/2020  0.14 tweak column query to mimick select x from dbt where RC = val
10/10/2020  0.15 try to use TADODataset to modify table data. DNW: not in edit or insert mode.
11/10/2020  0.16 Use TADOQuery & ExecSQL to bulk UPDATE query.
23/10/2020  0.17 Move the ConnStr to DBfile func to this unit.
30/10/2020  0.18 Warn about Mode=Read with UPDATE SQL.
15/12/2022  0.19 Add dblib file exists sanity check

Unit self test:
- tries to write report files to c:\temp\ folder.
- Four constants must be preset to match your DBLib config.

Write access not resolved with Access64 ??

Historical Connection Strings
-  Altium H Provider=MICROSOFT.JET.OLEDB.4.0;Data Source=P:\DB-Libraries\test.mdb;Persist Security Info=False
-  Altium W Provider=MICROSOFT.JET.OLEDB.4.0;Data Source=C:\Altium Projects\TestingStuff\dB-Libraries\Inductor.MDB;Persist Security Info=False
-  Excel  W Provider=Microsoft.ACE.OLEDB.12.0;User ID=Admin;Data Source=C:\Altium Projects\TestingStuff\dB-Libraries\Inductor.MDB;Mode=Share Deny Write;Extended Properties="";Jet OLEDB:System database="";Jet

Note:
 There is a connection string related to Altium's DBLib open in the GUI
 There's another connection string for this (libADO) connection.

Functions use read only queries.
- need to change Altium DBLib ConnectionString to 'Mode = Read' to use fn libADOQueryUpdate()

 below code is useless as Conn Str is changed after connection.
        ConnectStr := 'no connection';

            ADOConn := libADOQuery.Connection;
            ADOConn.ConnectionString;
            libADOQuery.Connection;
            ADOConn.Provider;
            ADOConn.DefaultDatabase;
            libADOQuery.Parameters.ParamByName('iD');
            ConnectStr := ADOConn.ConnectionString;

        ADOConn.DefaultDatabase := dbLibraryFile;
}

const
{
// Jet  32bit
    dbConnectionStr1 = 'Provider=MICROSOFT.JET.OLEDB.4.0;Data Source=';
    dbConnectionStr2 = ';Persist Security Info=False';
    dbConnectionStr3 = ';Mode=Read';          // read mode
//    dbConnectionStr3 = '';                  // full R/W mode
}
//  Access64 works in Read mode only
    dbConnectionStr1 = 'Provider=Microsoft.ACE.OLEDB.12.0;User ID=Admin;Data Source=';
    dbConnectionStr2 = ';Mode=Read';
    dbConnectionStr3 = ';Extended Properties="";Jet OLEDB:System database="";Jet';

// Only used for unit self test
    cdbLibraryName   = 'C:\Altium Projects\dB-Libraries\Inductor.MDB';
    cdbTableName     = 'Inductor';
    cdbCompName      = 'IND_100NH_0A03_0402_2%';
    cdbPrimaryKey    = 'Part Number';

    clibADOError           = 2;
    clibADOOpen            = 1;
    clibADOClosed          = 0;
    clibADOConnStringDS    = 'Data Source';
    clibADOConnStringMode  = 'Mode';
    cLibADOConnStrModeRead = 'Read';

// pseudo static vars ; Connection String is modified/stripped when connected to provider
var
    libADOConn      : TADOConnection;
    libADOQuery     : TADOQuery;        // queries to MS access database library
    libADODataset   : TADODataSet;
    libADOstate     : Integer;
    libADOActiveDB  : WideString;
    libADOConnStr   : WideString;      // scripts ADO DB connection
    libADOConnStrA  : WideString;      // Altiums' internal DB connection

function libADOQueryGetDBLibDataBaseFile(ConnString : WideString) : WideString;
var
    DBConnString   : TStringList;
begin
    Result := '';
    DBConnString := TStringList.Create;
    DBConnString.Delimiter := ';';
    DBConnString.NameValueSeparator := '=';
    DbConnString.StrictDelimiter := true;
    DBConnString.DelimitedText := ConnString;
    Result := DBConnString.ValueFromIndex( DBConnString.IndexOfName(clibADOConnStringDS) );
    DBConnString.Free;

    libADOConnStrA := ConnString;
end;

function libADOConnMode(ConnString : WideString) : WideString;
var
    DBConnString : TStringList;
    I            : integer;
begin
    Result := '';
    DBConnString := TStringList.Create;
    DBConnString.Delimiter := ';';
    DBConnString.NameValueSeparator := '=';
    DbConnString.StrictDelimiter := true;
    DBConnString.DelimitedText := ConnString;
    I := DBConnString.IndexOfName(clibADOConnStringMode);
    if I > -1 then Result := DBConnString.ValueFromIndex( I );
    DBConnString.Free;
end;

procedure libADOclose (dummy : integer);
Begin
     if( libADOstate <> cLibADOClosed ) then
         libADOConn.Free;
     libADOstate := cLibADOClosed;
     libADOConnStr := '';
end;

// Connection to database not closed unless Lib name changes or libADOclose()
function libADOinit ( dbLibraryFile : WideString ) : TADOConnection;
begin
    if libADOQuery <> nil then
        Result := libADOConn
    else
        libADOstate := cLibADOClosed;

// if conn query open check the conn str (name)
    if not SameString( dbLibraryFile, libADOActiveDB, true )  then
        libADOclose (1);

    if (libADOConnStr = '') then
    if not FileExists(dbLibraryFile, false) then
    begin
        libADOstate := cLibADOClosed; // clibADOError
        ShowMessage('dblib file / path error ');
        exit;
    end;

    if( libADOstate = clibADOClosed ) then
    begin
        libADOstate := clibADOOpen;

        libADOConn := TADOConnection.Create(nil);
        libADOConnStr := dbConnectionStr1 + dbLibraryFile + dbConnectionStr2 + dbConnectionStr3;
        libADOConn.ConnectionString := libADOConnStr;
        libADOConn.LoginPrompt := False;
        try
            libADOConn.Connected := True;
        except
            begin
                ShowMessage('connection error ');
                libADOstate := clibADOError;
                exit;
            end;
        end;

        libADOActiveDB := dbLibraryFile;   // can't find/return this in ADOQuery. so have to store it here!
        libADOQuery := TADOQuery.Create(nil);   // Self
        libADOQuery.Connection := libADOConn;
        Result := libADOConn;
//        libADODataset := TADODataSet.Create(nil);
//        libADODataset.Connection := libADOConn;
    end;
end;

// local query always get something for fields..
procedure libADOFieldQueryInit( dbLibraryName, dbTableName : wideString );
begin
    libADOinit(dbLibraryName);
    libADOQuery.SQL.Clear;
    libADOQuery.SQL.Add('SELECT * FROM ' + dbTableName + ' LIMIT 2');
    libADOQuery.Open;
End;

{ // local query get one row for col=value
procedure libADORowQueryInit( dbLibraryName, dbTableName, matchColumn, matchVal : WideString );
begin
    libADOinit( dbLibraryName );
    libADOQuery.SQL.Clear;
    libADOQuery.SQL.Add('SELECT * FROM ' + dbTableName + ' WHERE [' + matchColumn + ']= :val');
    libADOQuery.Parameters.ParamByName('val').Value := matchVal;
    libADOQuery.Open;
End;
}

// local query get one column for dblib         table        where        =val       select
procedure libADOColumnQueryInit( dbLibraryName, dbTableName, matchColumn, matchVal, retColumn : WideString );
begin
    libADOinit( dbLibraryName );
    libADOQuery.SQL.Clear;
    if retColumn <> '*' then
    begin
        if matchVal <> '*' then        // simple WHERE clause bypass for * all values..
        begin
            libADOQuery.SQL.Add('SELECT [' + retColumn + '] FROM ' + dbTableName + ' WHERE [' + matchColumn + '] = :val');
            libADOQuery.Parameters.ParamByName('val').Value := matchVal;
        end else
            libADOQuery.SQL.Add('SELECT ['+retColumn+'] FROM ' + dbTableName );
    end
    else   //  simple select *
    begin
        if matchVal <> '*' then        // simple WHERE clause bypass for * all values..
        begin
            libADOQuery.SQL.Add('SELECT * FROM ' + dbTableName + ' WHERE [' + matchColumn + '] = :val');
            libADOQuery.Parameters.ParamByName('val').Value := matchVal;
        end else
            libADOQuery.SQL.Add('SELECT * FROM ' + dbTableName );
    end;

    libADOQuery.Open;
End;

// returns list of values from one specific row of the req. result column(s)
function libADORowQuery( dbLibraryName, dbTableName, matchColumn, matchVal : WideString, returnColumns : TStringList ) : TStringList;
var
    Field : TField;
    I     : integer;
begin
    Result := TStringList.Create;

    libADOColumnQueryInit( dbLibraryName, dbTableName, matchColumn, matchVal, '*' );

    for I := 0 to (returnColumns.Count - 1) do
    begin
        Field := libADOQuery.FieldByName( returnColumns.Strings(I) );
        libADOQuery.First;
        Result.Add( Field.AsString );
    end;

    libADOQuery.Close;
End;

// return list of table field (column) names.
function libADOTableFields( dbLibraryName, dbTableName : WideString ) : TStringList;
var
    I : integer;
begin
    Result := TStringlist.Create;

    libADOFieldQueryInit(dbLibraryName, dbTableName );
    libADOQuery.Parameters.Count;

    for I := 0 to (libADOQuery.FieldCount - 1) do
        Result.Add( libADOQuery.Fields[I].DisplayName );              // these are the column field names.

//      Result.Add(libADOQuery.Fields.FieldByNumber(I).AsString);  // this is the row data
    libADOQuery.Close;
end;

// return one whole column with field name match.
function libADOColumnQuery( dbLibraryName, dbTableName, const matchColumn, matchVal, retColumn : WideString ) : TStringList;
var
    Field : TField;
begin
    libADOColumnQueryInit( dbLibraryName, dbTableName, matchColumn, matchVal, retColumn );

    Result := TStringlist.Create;
    Field := libADOQuery.FieldByName( retColumn );
    libADOQuery.First;
    while not libADOQuery.Eof do
    begin
//        if (matchVal = '*') or (matchVal = Field.AsString) then
            Result.Add( Field.AsString );
        libADOQuery.Next;
    end;
    libADOQuery.Close;
end;

function libADOQueryUpdate( dbLibraryName, dbTableName, const matchColumn, matchVal, targetColumn, newVal : WideString ) : integer;
var
    Field : TField;
begin
    Result := false;

// check this connection is NOT Mode=Read but Altium is
    if (libADOConnMode(libADOConnStr) = cLibADOConnStrModeRead) then
    begin
        ShowMessage('Mode=Read for ADOQuery; UPDATE not possible');
        exit;
    end;
    if (libADOConnMode(libADOConnStrA) <> cLibADOConnStrModeRead) then
    begin
        ShowMessage('Mode<>Read for DBLib; ADOQuery UPDATE not possible');
        exit;
    end;

    libADOinit( dbLibraryName );
    libADOQuery.SQL.Clear;
    libADOQuery.Prepared := true;
    libADOQuery.SQL.Add('UPDATE ' + dbTableName + ' SET [' + targetColumn + '] = :newVal WHERE [' + matchcolumn + '] = :matchVal');
    libADOQuery.ParamCheck := true;
    libADOQuery.Parameters.ParamByName('newVal').Value := newVal;
    libADOQuery.Parameters.ParamByName('matchVal').Value := matchVal;
    libADOQuery.Prepared := true;
    Result := libADOQuery.ExecSQL;
    libADOQuery.Close;
end;

// function DNW due to edit or insert mode error
function libADODataSetUpdate( dbLibraryName, dbTableName, const matchColumn, matchVal, targetColumn, newVal : WideString ) : boolean;
var
    Field : TField;
begin
    Result := false;

    libADOinit( dbLibraryName );

    libADODataset.CommandType := cmdText;

{// can't get WHERE clause to return anything!
    libADODataset.CommandText := 'SELECT * FROM ' + dbTableName + ' WHERE [' + matchColumn + '] = :val';
    libADODataset.Parameters.ParamByName('val').Value := matchVal;
}
    libADODataset.CommandText := 'SELECT * FROM ' + dbTableName;
    libADODataset.Open;
    libADODataset.FieldCount;

    libADODataset.Edit;
    libADODataset.State;        //dsInsert = 3
    libADODataset.RecordCount;

//    Field := libADODataset..FieldByName( targetColumn );
    libADODataset.First;
    while not libADODataset.Eof do
    begin
//    Field := libADODataset..FieldByName( targetColumn );
        if libADODataset.FieldByName( matchColumn ).AsString := matchVal then
        begin
            libADODataset.Edit;
//            libADODataset.FieldValues( targetColumn ) := newVal;
            libADODataset.FieldByName( targetColumn ).AsString := newVal;
            libADODataset.Post;
        end;

        libADODataset.Next;
        Result := true;
    end;

    libADODataset.Close;
end;


// no proper var init & no static local vars in Delphiscript so try hide the shared vars
function libADOStaticInit( const dummy : integer);
begin
    libADOstate    := clibADOClosed;
    libADOConn     := nil;
    libADOQuery    := nil;
    libADODataset  := nil;
    libADOActiveDB := 'Not Connected';
    libADOConnStr  := '';
    libADOConnStrA := '';
end;

// local self unit test.
procedure libADOUnitTest;
var
    dbTableName   : WideString;
    dbLibraryName : WideString;      // full path file name
    AllPKList     : TStringList;
    FieldsList    : TStringList;
    TStart, TStop : TDateTime;

begin
    dbTableName   := cdbTableName;
    dbLibraryName := cdbLibraryName;

    if not FileExists(dbLibraryName, false) then
    begin
        libADOstate := clibADOError;
        ShowMessage('dblib file / path error ');
        exit;
    end;

    libADOStaticInit(1);

    TStart := Time;         //                              Where   = val   Select
    AllPKList := libADOColumnQuery( dbLibraryName, dbTableName, '', '*', cdbPrimaryKey );
    TStop := Time;

    ShowMessage(TimeToStr((TStop-TStart)*1000));
    ShowMessage( IntToStr(AllPKList.Count) );

    AllPKList.SaveToFile('c:\temp\allkeys.txt');
    AllPKList.Clear;

    FieldsList := TStringList.Create;
    FieldsList.Add('Footprint Path');
    FieldsList.Add('Footprint Ref');
//                                                              Where        =Value      Select []
    AllPKList := libADORowQuery( dbLibraryName, dbTableName, cdbPrimaryKey, cdbCompName, FieldsList );
    if  AllPKList.Count < 1 then
        ShowMessage( 'count of row fields ' + IntToStr(AllPKList.Count) )
    else
        ShowMessage( 'count of row fields ' + IntToStr(AllPKList.Count) + ' ' + FieldsList.Strings(0) + ' = ' + AllPKList.Strings(0) + ' ' + FieldsList.Strings(1) + ' = ' + AllPKList.Strings(1) );


// should close before attempting conn on another library.
    libADOClose(1);

    AllPKList.Insert(0, 'fields: ' + FieldsList.DelimitedText);
    AllPKList.Insert(0, 'part:   ' + cdbCompName);
    AllPKList.SaveToFile('c:\temp\rowvalues.txt');
    AllPKList.Clear;
end;

