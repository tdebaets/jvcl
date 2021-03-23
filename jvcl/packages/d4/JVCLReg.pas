unit JVCLReg;

interface

procedure Register;

implementation

uses
  Classes,
  Controls,
  JvHidControllerClass;

procedure Register;
begin
  RegisterComponents('System', [TJvHidDeviceController]);
end;

end.
