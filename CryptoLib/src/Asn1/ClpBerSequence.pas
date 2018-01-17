{ *********************************************************************************** }
{ *                              CryptoLib Library                                  * }
{ *                    Copyright (c) 2018 Ugochukwu Mmaduekwe                       * }
{ *                 Github Repository <https://github.com/Xor-el>                   * }

{ *  Distributed under the MIT software license, see the accompanying file LICENSE  * }
{ *          or visit http://www.opensource.org/licenses/mit-license.php.           * }

{ *                              Acknowledgements:                                  * }
{ *                                                                                 * }
{ *        Thanks to Sphere 10 Software (http://sphere10.com) for sponsoring        * }
{ *                        the development of this library                          * }

{ * ******************************************************************************* * }

(* &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& *)

unit ClpBerSequence;

{$I ..\Include\CryptoLib.inc}

interface

uses
  Classes,
  SysUtils,
  ClpIProxiedInterface,
  ClpAsn1Tags,
  ClpDerSequence,
  ClpIAsn1OutputStream,
  ClpIBerOutputStream,
  ClpIAsn1EncodableVector,
  ClpIBerSequence;

type
  TBerSequence = class(TDerSequence, IBerSequence)

  strict private

    class var

      FEmpty: IBerSequence;

    class constructor BerSequence();
    class function GetEmpty: IBerSequence; static; inline;

  public

    class function FromVector(v: IAsn1EncodableVector): IBerSequence; static;

    /// <summary>
    /// create an empty sequence
    /// </summary>
    constructor Create(); overload;

    /// <summary>
    /// create a sequence containing one object
    /// </summary>
    constructor Create(obj: IAsn1Encodable); overload;

    constructor Create(v: array of IAsn1Encodable); overload;

    /// <summary>
    /// create a sequence containing a vector of objects.
    /// </summary>
    constructor Create(v: IAsn1EncodableVector); overload;

    destructor Destroy(); override;

    /// <summary>
    /// A note on the implementation: <br />As Der requires the constructed,
    /// definite-length model to <br />be used for structured types, this
    /// varies slightly from the <br />ASN.1 descriptions given. Rather than
    /// just outputing Sequence, <br />we also have to specify Constructed,
    /// and the objects length. <br />
    /// </summary>
    procedure Encode(derOut: IDerOutputStream); override;

    class property Empty: IBerSequence read GetEmpty;

  end;

implementation

{ TBerSequence }

constructor TBerSequence.Create(obj: IAsn1Encodable);
begin
  Inherited Create(obj);
end;

constructor TBerSequence.Create;
begin
  Inherited Create();
end;

constructor TBerSequence.Create(v: IAsn1EncodableVector);
begin
  Inherited Create(v);
end;

destructor TBerSequence.Destroy;
begin

  inherited Destroy;
end;

constructor TBerSequence.Create(v: array of IAsn1Encodable);
begin
  Inherited Create(v);
end;

class constructor TBerSequence.BerSequence;
begin
  FEmpty := TBerSequence.Create();
end;

procedure TBerSequence.Encode(derOut: IDerOutputStream);
var
  o: IAsn1Encodable;
begin

  if ((Supports(derOut, IAsn1OutputStream)) or
    (Supports(derOut, IBerOutputStream))) then
  begin
    derOut.WriteByte(TAsn1Tags.Sequence or TAsn1Tags.Constructed);
    derOut.WriteByte($80);

    for o in Self do
    begin
      derOut.WriteObject(o);
    end;

    derOut.WriteByte($00);
    derOut.WriteByte($00);
  end
  else
  begin
    (Inherited Encode(derOut));
  end;

end;

class function TBerSequence.FromVector(v: IAsn1EncodableVector): IBerSequence;
begin
  if v.Count < 1 then
  begin
    result := Empty;
  end
  else
  begin
    result := TBerSequence.Create(v);
  end;

end;

class function TBerSequence.GetEmpty: IBerSequence;
begin
  result := FEmpty;
end;

end.