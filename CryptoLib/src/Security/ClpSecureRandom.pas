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

unit ClpSecureRandom;

{$I ..\Include\CryptoLib.inc}

interface

uses
  Math,
{$IFDEF DELPHI}
  SyncObjs,
{$ENDIF DELPHI}
  HlpIHash,
  SysUtils,
  StrUtils,
  ClpBits,
  ClpCryptoLibTypes,
  ClpTimes,
  ClpIRandomGenerator,
  ClpRandom,
  ClpDigestUtilities,
  ClpCryptoApiRandomGenerator,
  ClpDigestRandomGenerator,
  ClpIDigestRandomGenerator,
  ClpISecureRandom;

resourcestring
  SUnrecognisedPRNGAlgorithm = 'Unrecognised PRNG Algorithm: %s "algorithm"';
  SCannotBeNegative = 'Cannot be Negative  "maxValue"';
  SInvalidMaxValue = 'maxValue Cannot be Less Than minValue';

type
  TSecureRandom = class(TRandom, ISecureRandom)

  strict private
  class var

    FCounter: Int64;
    Fmaster: ISecureRandom;
    FDoubleScale: Double;

    class function GetMaster: ISecureRandom; static; inline;

    class function NextCounterValue(): Int64; static; inline;

    class function CreatePrng(const digestName: String; autoSeed: Boolean)
      : IDigestRandomGenerator; static; inline;

    class property Master: ISecureRandom read GetMaster;

    class constructor SecureRandom();

  strict protected
    Fgenerator: IRandomGenerator;

  public
    /// <summary>Use the specified instance of IRandomGenerator as random source.</summary>
    /// <remarks>
    /// This constructor performs no seeding of either the <c>IRandomGenerator</c> or the
    /// constructed <c>SecureRandom</c>. It is the responsibility of the client to provide
    /// proper seed material as necessary/appropriate for the given <c>IRandomGenerator</c>
    /// implementation.
    /// </remarks>
    /// <param name="generator">The source to generate all random bytes from.</param>
    constructor Create(generator: IRandomGenerator); overload;
    constructor Create(); overload;

    function GenerateSeed(length: Int32): TCryptoLibByteArray; virtual;
    procedure SetSeed(seed: TCryptoLibByteArray); overload; virtual;
    procedure SetSeed(seed: Int64); overload; virtual;

    procedure NextBytes(buf: TCryptoLibByteArray); overload; override;
    procedure NextBytes(buf: TCryptoLibByteArray; off, len: Int32);
      overload; virtual;
    function NextInt32(): Int32; virtual;
    function NextInt64(): Int64; virtual;

    function NextDouble(): Double; override;

    function Next(): Int32; overload; override;
    function Next(maxValue: Int32): Int32; overload; override;
    function Next(minValue, maxValue: Int32): Int32; overload; override;

    class function GetNextBytes(SecureRandom: ISecureRandom; length: Int32)
      : TCryptoLibByteArray; static;

    /// <summary>
    /// Create and auto-seed an instance based on the given algorithm.
    /// </summary>
    /// <remarks>Equivalent to GetInstance(algorithm, true)</remarks>
    /// <param name="algorithm">e.g. "SHA256PRNG"</param>
    class function GetInstance(const algorithm: String): ISecureRandom;
      overload; static; inline;
    /// <summary>
    /// Create an instance based on the given algorithm, with optional auto-seeding
    /// </summary>
    /// <param name="algorithm">e.g. "SHA256PRNG"</param>
    /// <param name="autoSeed">If true, the instance will be auto-seeded.</param>
    class function GetInstance(const algorithm: String; autoSeed: Boolean)
      : ISecureRandom; overload; static; inline;

    class procedure Boot(); static;

  end;

implementation

{ TSecureRandom }

constructor TSecureRandom.Create(generator: IRandomGenerator);
begin
  Inherited Create(0);
  Fgenerator := generator;
end;

class function TSecureRandom.GetMaster: ISecureRandom;
begin
  Result := Fmaster;
end;

class function TSecureRandom.GetNextBytes(SecureRandom: ISecureRandom;
  length: Int32): TCryptoLibByteArray;
begin
  System.SetLength(Result, length);
  SecureRandom.NextBytes(Result);
end;

function TSecureRandom.Next(maxValue: Int32): Int32;
var
  bits: Int32;
begin
  if (maxValue < 2) then
  begin
    if (maxValue < 0) then
      raise EArgumentOutOfRangeCryptoLibException.CreateRes(@SCannotBeNegative);

    Result := 0;
    Exit;
  end;

  // Test whether maxValue is a power of 2
  if ((maxValue and (maxValue - 1)) = 0) then
  begin
    bits := NextInt32() and System.High(Int32);
    Result := Int32(TBits.Asr64((Int64(bits) * maxValue), 31));
    Exit;
  end;

  repeat
    bits := NextInt32() and System.High(Int32);
    Result := bits mod maxValue;
    // Ignore results near overflow
  until (not((bits - (Result + (maxValue - 1))) < 0));

end;

function TSecureRandom.Next(minValue, maxValue: Int32): Int32;
var
  diff, i: Int32;
begin
  if (maxValue <= minValue) then
  begin
    if (maxValue = minValue) then
    begin
      Result := minValue;
      Exit;
    end;

    raise EArgumentCryptoLibException.CreateRes(@SInvalidMaxValue);
  end;

  diff := maxValue - minValue;
  if (diff > 0) then
  begin
    Result := minValue + Next(diff);
    Exit;
  end;

  while True do

  begin
    i := NextInt32();

    if ((i >= minValue) and (i < maxValue)) then
    begin
      Result := i;
      Exit;
    end;
  end;

  Result := 0; // to make FixInsight Happy :)

end;

function TSecureRandom.Next: Int32;
begin
  Result := NextInt32() and System.High(Int32);
end;

procedure TSecureRandom.NextBytes(buf: TCryptoLibByteArray);
begin
  Fgenerator.NextBytes(buf);

end;

procedure TSecureRandom.NextBytes(buf: TCryptoLibByteArray; off, len: Int32);
begin
  Fgenerator.NextBytes(buf, off, len);
end;

class function TSecureRandom.NextCounterValue: Int64;
{$IFDEF FPC}
var
  LCounter: UInt32;
{$ENDIF FPC}
begin
{$IFDEF DELPHI}
  Result := TInterlocked.Increment(FCounter);
{$ELSE}
  LCounter := UInt32(FCounter);
  Result := InterLockedIncrement(LCounter);
  FCounter := Int64(LCounter);
{$ENDIF DELPHI}
end;

function TSecureRandom.NextDouble: Double;
begin
  Result := UInt64(NextInt64()) / FDoubleScale;
end;

function TSecureRandom.NextInt32: Int32;
var
  tempRes: UInt32;
  bytes: TCryptoLibByteArray;
begin
  System.SetLength(bytes, 4);
  NextBytes(bytes);

  tempRes := bytes[0];
  tempRes := tempRes shl 8;
  tempRes := tempRes or bytes[1];
  tempRes := tempRes shl 8;
  tempRes := tempRes or bytes[2];
  tempRes := tempRes shl 8;
  tempRes := tempRes or bytes[3];
  Result := Int32(tempRes);
end;

function TSecureRandom.NextInt64: Int64;
begin
  Result := (Int64(UInt32(NextInt32())) shl 32) or (Int64(UInt32(NextInt32())));
end;

class constructor TSecureRandom.SecureRandom;
begin
  TSecureRandom.Boot;
end;

procedure TSecureRandom.SetSeed(seed: Int64);
begin
  Fgenerator.AddSeedMaterial(seed);
end;

procedure TSecureRandom.SetSeed(seed: TCryptoLibByteArray);
begin
  Fgenerator.AddSeedMaterial(seed);
end;

class function TSecureRandom.CreatePrng(const digestName: String;
  autoSeed: Boolean): IDigestRandomGenerator;
var
  digest: IHash;
  prng: IDigestRandomGenerator;
begin
  digest := TDigestUtilities.GetDigest(digestName);
  if (digest = Nil) then
  begin
    Result := Nil;
    Exit;
  end;
  digest.Initialize(); // initialize digest state
  prng := TDigestRandomGenerator.Create(digest);
  if (autoSeed) then
  begin
    prng.AddSeedMaterial(NextCounterValue());
    prng.AddSeedMaterial(GetNextBytes(Master, digest.HashSize));
  end;
  Result := prng;
end;

class procedure TSecureRandom.Boot;
begin
  FCounter := TTimes.NanoTime();
  Fmaster := TSecureRandom.Create(TCryptoApiRandomGenerator.Create());
  FDoubleScale := Power(2.0, 64.0);
end;

constructor TSecureRandom.Create;
begin
  Create(CreatePrng('SHA256', True));
end;

class function TSecureRandom.GetInstance(const algorithm: String)
  : ISecureRandom;
begin
  Result := GetInstance(algorithm, True);
end;

function TSecureRandom.GenerateSeed(length: Int32): TCryptoLibByteArray;
begin
  Result := GetNextBytes(Master, length);
end;

class function TSecureRandom.GetInstance(const algorithm: String;
  autoSeed: Boolean): ISecureRandom;
var
  upper, digestName: String;
  prng: IDigestRandomGenerator;
begin
  upper := AnsiUpperCase(algorithm);
  if AnsiEndsStr('PRNG', upper) then
  begin
    digestName := System.Copy(upper, 1, System.length(upper) -
      System.length('PRNG'));

    prng := CreatePrng(digestName, autoSeed);
    if (prng <> Nil) then
    begin
      Result := TSecureRandom.Create(prng);
      Exit;
    end;
  end;

  raise EArgumentCryptoLibException.CreateResFmt(@SUnrecognisedPRNGAlgorithm,
    [algorithm]);

end;

end.