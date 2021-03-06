unit ProcDeclaration;

interface

uses
  Classes, Types, CodeElement, DataType, VarDeclaration, Generics.Collections, WriterIntf;

type
  TArguments = array of TVarDeclaration;

  TProcDeclaration = class(TCodeElement)
  private
    FResultType: TDataType;
    FParameters: TObjectList<TCodeElement>;
    FLocals: TObjectList<TCodeElement>;
    FStartLine: Integer;
    FEndLine: Integer;
    FIsDummy: Boolean;
    function GetIsFunction: Boolean;
  public
    constructor Create(const AName: string);
    procedure AddResultValue();
    procedure AddLocal(AVar: TVarDeclaration);
    procedure GetDCPUSource(AWriter: IWriter); override;
    function GetElement(AName: string; AType: TCodeElementClass): TCodeElement;
    function GetCurrentWordSpaceOfLocals(): Integer;
    function ParameterMatches(AProc: TProcDeclaration): Boolean;
    function DeclarationMatches(AProc: TProcDeclaration): Boolean;
    property IsFunction: Boolean read GetIsFunction;
    property ResultType: TDataType read FResultType write FResultType;
    property Parameters: TObjectList<TCodeElement> read FParameters;
    property Locals: TObjectList<TCodeElement> read FLocals;
    property StartLine: Integer read FStartLine write FStartLine;
    property EndLine: Integer read FEndLine write FEndLine;
    property IsDummy: Boolean read FIsDummy write FIsDummy;
  end;

implementation

uses
  SysUtils, Optimizer;

{ TProcDeclaration }


{ TProcDeclaration }

procedure TProcDeclaration.AddLocal(AVar: TVarDeclaration);
var
  LElement: TCodeElement;
begin
  for LElement in FParameters do
  begin
    if TVarDeclaration(LElement).ParamIndex > 3 then
    begin
      TVarDeclaration(LElement).ParamIndex := TVarDeclaration(LElement).ParamIndex +1;
    end;
  end;
  for LElement in FLocals do
  begin
    TVarDeclaration(LElement).ParamIndex := TVarDeclaration(LElement).ParamIndex  - AVar.DataType.GetRamWordSize();
  end;
  AVar.ParamIndex := -1;
  FLocals.Add(AVar);
end;

procedure TProcDeclaration.AddResultValue;
begin
  AddLocal(TVarDeclaration.Create('Result', ResultType));
end;

constructor TProcDeclaration.Create(const AName: string);
begin
  inherited Create(AName);
  FParameters := TObjectList<TCodeElement>.Create();
  FLocals := TObjectList<TCodeElement>.Create();
  FIsDummy := False;
end;

function TProcDeclaration.DeclarationMatches(AProc: TProcDeclaration): Boolean;
begin
  Result := SameText(Name, AProc.Name) and (IsFunction = AProc.IsFunction);
  if Result then
  begin
    Result := ParameterMatches(AProc);
  end;
end;

function TProcDeclaration.GetCurrentWordSpaceOfLocals: Integer;
var
  LElement: TCodeElement;
begin
  Result := 0;
  for LElement in FLocals do
  begin
    Result := Result + TVarDeclaration(LElement).DataType.GetRamWordSize();
  end;
end;

procedure TProcDeclaration.GetDCPUSource;
begin
  if Self.IsDummy then Exit; // a dummy NEVER produces source, but is used by the compiler for ahead declaration
  
  AWriter.Write(':' + Name);
  if (FParameters.Count > 3) or (FLocals.Count > 0) then
  begin
    AWriter.AddMapping(Self, StartLine - Line, False);//mark the entryline of prolog
    AWriter.Write('set push, j');
    if FLocals.Count > 0 then
    begin
      AWriter.Write('sub sp, ' + IntToStr(GetCurrentWordSpaceOfLocals()));
    end;
    AWriter.Write('set j, sp');
  end;
  inherited GetDCPUSource(AWriter);
  AWriter.AddMapping(Self, EndLine - Line, True);//mark the entryline of epilog
  if IsFunction and (FLocals.Count > 0) then
  begin
    AWriter.Write('set a, [' +
      TVarDeclaration(GetElement('Result', TVarDeclaration)).GetAccessIdentifier() + ']');
  end;
  if (FParameters.Count > 3) or (FLocals.Count > 0) then
  begin
    AWriter.Write('set sp, j');
    if FLocals.Count > 0 then
    begin
      AWriter.Write('add sp, ' + IntToStr(GetCurrentWordSpaceOfLocals()));
    end;
    AWriter.Write('set j, pop');
  end;
  AWriter.Write('set pc, pop');
  //Result := SimpleOptimizeDCPUCode(Result);
end;

function TProcDeclaration.GetElement(AName: string;
  AType: TCodeElementClass): TCodeElement;
var
  LElement: TCodeElement;
begin
  Result := nil;
  for LElement in FParameters do
  begin
    if SameText(LElement.Name, AName) and LElement.InheritsFrom(AType) then
    begin
      Result := LElement;
      Exit;
    end;
  end;

  for LElement in FLocals do
  begin
    if SameText(LElement.Name, AName) and LElement.InheritsFrom(AType) then
    begin
      Result := LElement;
      Exit;
    end;
  end;
  if not Assigned(Result) then
  begin
    Result := inherited;
  end;
end;

function TProcDeclaration.GetIsFunction: Boolean;
begin
  Result := Assigned(FResultType);
end;

function TProcDeclaration.ParameterMatches(AProc: TProcDeclaration): Boolean;
var
  i: Integer;
begin
  Result := Parameters.Count = AProc.Parameters.Count;
  if Result then
  begin
    for i := 0 to Parameters.Count - 1 do
    begin
      Result := SameText(Parameters[i].Name, AProc.Parameters[i].Name)
        and (TVarDeclaration(Parameters[i]).DataType = TVarDeclaration(AProc.Parameters[i]).DataType);

      if not Result then Break;
    end;
  end;
end;

end.
