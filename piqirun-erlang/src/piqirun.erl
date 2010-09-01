%% Copyright 2009, 2010 Anton Lavrik
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% This code is based on Protobuffs library.
%% The original code was taken from here:
%%      http://github.com/ngerakines/erlang_protobuffs
%%
%% Below is the original copyright notice and the license:
%%
%% Copyright (c) 2009 
%% Nick Gerakines <nick@gerakines.net>
%% Jacob Vorreuter <jacob.vorreuter@gmail.com>
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%%
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.

%%
%% @doc Piqi runtime library
%%
-module(piqirun).
-compile(export_all).

-include("../include/piqirun.hrl").


-define(TYPE_VARINT, 0).
-define(TYPE_64BIT, 1).
-define(TYPE_STRING, 2).
-define(TYPE_START_GROUP, 3).
-define(TYPE_END_GROUP, 4).
-define(TYPE_32BIT, 5).


-type(field_type() ::
    ?TYPE_VARINT | ?TYPE_64BIT | ?TYPE_STRING |
    ?TYPE_START_GROUP | ?TYPE_END_GROUP | ?TYPE_32BIT
).


% TODO: specs


%% @hidden
-spec encode_field_tag/2 :: (
    Code :: piqirun_code(),
    FieldType :: field_type()) -> binary().

encode_field_tag(Code, FieldType) when Code band 16#3fffffff =:= Code ->
    encode_varint((Code bsl 3) bor FieldType).


%% @hidden
%% NOTE: `Integer` MUST be >= 0
-spec encode_varint_field/2 :: (
    Code :: piqirun_code(),
    Integer :: non_neg_integer()) -> iolist().

encode_varint_field(Code, Integer) ->
    [encode_field_tag(Code, ?TYPE_VARINT), encode_varint(Integer)].


%% @hidden
%% NOTE: `I` MUST be >= 0
-spec encode_varint/1 :: (
    I :: non_neg_integer()) -> binary().

encode_varint(I) ->
    encode_varint(I, []).


%% @hidden
encode_varint(I, Acc) when I =< 16#7f ->
    iolist_to_binary(lists:reverse([I | Acc]));
encode_varint(I, Acc) ->
    Last_Seven_Bits = (I - ((I bsr 7) bsl 7)),
    First_X_Bits = (I bsr 7),
    With_Leading_Bit = Last_Seven_Bits bor 16#80,
    encode_varint(First_X_Bits, [With_Leading_Bit|Acc]).


%% @hidden
decode_varint(Bytes) ->
    decode_varint(Bytes, []).
decode_varint(<<0:1, I:7, Rest/binary>>, Acc) ->
    Acc1 = [I|Acc],
    Result = 
        lists:foldl(
            fun(X, Acc0) ->
                (Acc0 bsl 7 bor X)
            end, 0, Acc1),
    {Result, Rest};
decode_varint(<<1:1, I:7, Rest/binary>>, Acc) ->
    decode_varint(Rest, [I | Acc]).


-spec gen_record/2 :: (
    Code :: piqirun_code(),
    Fields :: [iolist()] ) -> iolist().

-spec gen_variant/2 :: (
    Code :: piqirun_code(),
    X :: iolist() ) -> iolist().

-spec gen_list/3 :: (
    Code :: piqirun_code(),
    GenValue :: encode_fun(),
    L :: [any()] ) -> iolist().


gen_record(Code, Fields) ->
    Header =
        case Code of
            'undefined' -> []; % do not generate record header
            _ ->
                [ encode_field_tag(Code, ?TYPE_STRING),
                  encode_varint(iolist_size(Fields)) ]
        end,
    [ Header, Fields ].


gen_variant(Code, X) ->
    gen_record(Code, [X]).


gen_list(Code, GenValue, L) ->
    % NOTE: using "1" as list element's code
    gen_record(Code, [GenValue(1, X) || X <- L]).



-type encode_fun() ::
     fun( (Code :: piqirun_code(), Value :: any()) -> iolist() ).

-spec gen_req_field/3 :: (
    Code :: piqirun_code(),
    GenValue :: encode_fun(),
    X :: any() ) -> iolist().

-spec gen_opt_field/3 :: (
    Code :: piqirun_code(),
    GenValue :: encode_fun(),
    X :: 'undefined' | any() ) -> iolist().

-spec gen_rep_field/3 :: (
    Code :: piqirun_code(),
    GenValue :: encode_fun(),
    X :: [any()] ) -> iolist().


gen_req_field(Code, GenValue, X) ->
    GenValue(Code, X).


gen_opt_field(_Code, _GenValue, 'undefined') -> [];
gen_opt_field(Code, GenValue, X) ->
    GenValue(Code, X).


gen_rep_field(Code, GenValue, L) ->
    [GenValue(Code, X) || X <- L].


-spec non_neg_integer_to_varint/2 :: (
    Code :: piqirun_code(),
    X :: non_neg_integer()) -> iolist().

-spec integer_to_signed_varint/2 :: (
    Code :: piqirun_code(),
    X :: integer()) -> iolist().

-spec integer_to_zigzag_varint/2 :: (
    Code :: piqirun_code(),
    X :: integer()) -> iolist().

-spec boolean_to_varint/2 :: (
    Code :: piqirun_code(),
    X :: boolean()) -> iolist().

-spec gen_bool/2 :: (
    Code :: piqirun_code(),
    X :: boolean()) -> iolist().

-spec non_neg_integer_to_fixed32/2 :: (
    Code :: piqirun_code(),
    X :: non_neg_integer()) -> iolist().

-spec integer_to_signed_fixed32/2 :: (
    Code :: piqirun_code(),
    X :: integer()) -> iolist().

-spec non_neg_integer_to_fixed64/2 :: (
    Code :: piqirun_code(),
    X :: non_neg_integer()) -> iolist().

-spec integer_to_signed_fixed64/2 :: (
    Code :: piqirun_code(),
    X :: non_neg_integer()) -> iolist().

-spec float_to_fixed64/2 :: (
    Code :: piqirun_code(),
    X :: float() | integer() ) -> iolist().

-spec float_to_fixed32/2 :: (
    Code :: piqirun_code(),
    X :: float() | integer() ) -> iolist().

-spec binary_to_block/2 :: (
    Code :: piqirun_code(),
    X :: binary() | string() ) -> iolist().


non_neg_integer_to_varint(Code, X) when X >= 0 ->
    encode_varint_field(Code, X).

integer_to_signed_varint(Code, X) when X >= 0 ->
    encode_varint_field(Code, X);
integer_to_signed_varint(Code, X) -> % when X < 0
    encode_varint_field(Code, X + (1 bsl 64)).


integer_to_zigzag_varint(Code, X) when X >= 0 ->
    encode_varint_field(Code, X bsl 1);
integer_to_zigzag_varint(Code, X) -> % when  X < 0
    encode_varint_field(Code, bnot (X bsl 1)).


boolean_to_varint(Code, true) ->
    encode_varint_field(Code, 1);
boolean_to_varint(Code, false) ->
    encode_varint_field(Code, 0).


gen_bool(Code, X) -> boolean_to_varint(Code, X).


non_neg_integer_to_fixed32(Code, X) when X >= 0 ->
    integer_to_signed_fixed32(Code, X).

integer_to_signed_fixed32(Code, X) ->
    [encode_field_tag(Code, ?TYPE_32BIT), <<X:32/little-integer>>].


non_neg_integer_to_fixed64(Code, X) when X >= 0 ->
    integer_to_signed_fixed64(Code, X).

integer_to_signed_fixed64(Code, X) ->
    [encode_field_tag(Code, ?TYPE_64BIT), <<X:64/little-integer>>].


float_to_fixed64(Code, X) when is_float(X) ->
    [encode_field_tag(Code, ?TYPE_64BIT), <<X:64/little-float>>];
float_to_fixed64(Code, X) when is_integer(X) ->
    float_to_fixed64(Code, X + 0.0).


float_to_fixed32(Code, X) when is_float(X) ->
    [encode_field_tag(Code, ?TYPE_32BIT), <<X:32/little-float>>];
float_to_fixed32(Code, X) when is_integer(X) ->
    float_to_fixed32(Code, X + 0.0).


binary_to_block(Code, X) when is_binary(X) ->
    [encode_field_tag(Code, ?TYPE_STRING), encode_varint(size(X)), X];
binary_to_block(Code, X) when is_list(X) ->
    binary_to_block(Code, list_to_binary(X)).


%
% Decoders and parsers
%

-type parsed_field() ::
    {FieldCode :: pos_integer(), FieldValue :: piqirun_buffer()}.

-spec parse_field_header/1 :: ( Bytes :: binary() ) ->
    {Code :: pos_integer(), WireType :: field_type(), Rest :: binary()}.

parse_field_header(Bytes) ->
    {Tag, Rest} = decode_varint(Bytes),
    Code = Tag bsr 3,
    WireType = Tag band 7,
    {Code, WireType, Rest}.


-spec parse_field/1 :: (
    Bytes :: binary() ) -> {parsed_field(), Rest :: binary()}.

parse_field(Bytes) ->
    {FieldCode, WireType, Content} = parse_field_header(Bytes),
    {FieldValue, Rest} =
        case WireType of
            ?TYPE_VARINT -> decode_varint(Content);
            ?TYPE_STRING ->
                {Length, R1} = decode_varint(Content),
                {Value, R2} = split_binary(R1, Length),
                {{'block', Value}, R2};
            ?TYPE_64BIT ->
                split_binary(Content, 8);
            ?TYPE_32BIT ->
                split_binary(Content, 4)
        end,
    {{FieldCode, FieldValue}, Rest}.


-spec parse_record/1 :: (
    piqirun_buffer() ) -> [ parsed_field() ].

-spec parse_record_buf/1 :: (
    Bytes :: binary() ) -> [ parsed_field() ].

-spec parse_variant/1 :: (
    piqirun_buffer() ) -> parsed_field().

-spec parse_list/2 :: (
    ParseValue :: fun (( piqirun_buffer() ) -> any()),
    piqirun_buffer() ) -> [ any() ].


parse_record({'block', Bytes}) ->
    parse_record_buf(Bytes).


parse_record_buf(Bytes) ->
    parse_record_buf(Bytes, []).

parse_record_buf(<<>>, Accu) ->
    lists:reverse(Accu);
parse_record_buf(Bytes, Accu) ->
    {Value, Rest} = parse_field(Bytes),
    parse_record_buf(Rest, [Value | Accu]).


parse_variant(X) ->
    [Res] = parse_record(X),
    Res.


parse_list(ParseValue, X) ->
    L = parse_record(X),
    % NOTE: expecting "1" as list element's code
    [ ParseValue(Y) || {1, Y} <- L ].


-spec find_fields/2 :: (
        Code :: pos_integer(),
        L :: [ parsed_field() ] ) ->
    { Found ::[ piqirun_buffer() ], Rest :: [ parsed_field() ]}.

% find record field by code
find_fields(Code, L) ->
    find_fields(Code, L, [], []).


find_fields(_Code, [], Accu, Rest) ->
    {lists:reverse(Accu), lists:reverse(Rest)};
find_fields(Code, [{Code, X} | T], Accu, Rest) ->
    find_fields(Code, T, [X | Accu], Rest);
find_fields(Code, [H | T], Accu, Rest) ->
    find_fields(Code, T, Accu, [H | Rest]).


% strings are encoded as variable-length blocks 
parse_string(X) -> binary_of_block(X).


parse_binobj(Binobj) ->
    L = parse_record_buf(Binobj),
    case L of
        [{2, X}] -> % anonymous binobj
            {'undefined', X};
        [{1, Nameobj}, {2, X}] -> % named binobj
            Name = parse_string(Nameobj),
            {Name, X}
    end.


parse_default(X) ->
  {_, Res} = parse_binobj(X),
  Res.


-spec error/1 :: (any()) -> no_return().

error(X) ->
    throw({'piqirun_error', X}).


-type decode_fun() :: fun( (piqirun_buffer()) -> any() ).

-spec parse_req_field/3 :: (
    Code :: pos_integer(),
    ParseValue :: decode_fun(),
    L :: [parsed_field()] ) -> { Res :: any(), Rest :: [parsed_field()] }.

-spec parse_opt_field/3 :: (
    Code :: pos_integer(),
    ParseValue :: decode_fun(),
    L :: [parsed_field()] ) -> { Res :: 'undefined' | any(), Rest :: [parsed_field()] }.

-spec parse_opt_field/4 :: (
    Code :: pos_integer(),
    ParseValue :: decode_fun(),
    L :: [parsed_field()],
    Default :: binary() ) -> { Res :: any(), Rest :: [parsed_field()] }.

-spec parse_rep_field/3 :: (
    Code :: pos_integer(),
    ParseValue :: decode_fun(),
    L :: [parsed_field()] ) -> { Res :: [any()], Rest :: [parsed_field()] }.

-spec parse_flag/2 :: (
    Code :: pos_integer(),
    L :: [parsed_field()] ) -> { Res :: boolean(), Rest :: [parsed_field()] }.


parse_req_field(Code, ParseValue, L) ->
    case parse_opt_field(Code, ParseValue, L) of
        {'undefined', _Rest} -> error({'missing_field', Code});
        X -> X
    end.


parse_opt_field(Code, ParseValue, L, Default) ->
    case parse_opt_field(Code, ParseValue, L) of
        {'undefined', Rest} ->
            Res = ParseValue(parse_default(Default)),
            {Res, Rest};
        X -> X
    end.


parse_opt_field(Code, ParseValue, L) ->
    {Fields, Rest} = find_fields(Code, L),
    Res = 
        case Fields of
            [] -> 'undefined';
            [X|_] ->
                % NOTE: handling field duplicates without failure
                % XXX, TODO: produce a warning
                ParseValue(X)
        end,
    {Res, Rest}.


parse_flag(Code, L) ->
    % flags are represeted as booleans
    case parse_opt_field(Code, fun parse_bool/1, L) of
        {'undefined', Rest} -> {false, Rest};
        X = {true, _Rest} -> X;
        {false, _} -> error({'invalid_flag_encoding', Code})
    end.


parse_rep_field(Code, ParseValue, L) ->
    {Fields, Rest} = find_fields(Code, L),
    Res = [ ParseValue(X) || X <- Fields ],
    {Res, Rest}.


% XXX, TODO: print warnings on unrecognized fields
check_unparsed_fields(_L) -> ok.

error_enum_const(X) -> error({'unknown_enum_const', X}).

error_enum_obj(X) -> error({'invalid_enum_object', X}).

error_option(_X, Code) -> error({'unknown_option', Code}).



-spec non_neg_integer_of_varint/1 :: (
    piqirun_buffer()) -> non_neg_integer().

-spec integer_of_signed_varint/1 :: (
    piqirun_buffer()) -> integer().

-spec integer_of_zigzag_varint/1 :: (
    piqirun_buffer()) -> integer().

-spec boolean_of_varint/1 :: (
    piqirun_buffer()) -> boolean().

-spec parse_bool/1 :: (
    piqirun_buffer()) -> boolean().

-spec non_neg_integer_of_fixed32/1 :: (
    piqirun_buffer()) -> non_neg_integer().

-spec integer_of_signed_fixed32/1 :: (
    piqirun_buffer()) -> integer().

-spec non_neg_integer_of_fixed64/1 :: (
    piqirun_buffer()) -> non_neg_integer().

-spec integer_of_signed_fixed64/1 :: (
    piqirun_buffer()) -> integer().

-spec float_of_fixed64/1 :: (
    piqirun_buffer()) -> float().

-spec float_of_fixed32/1 :: (
    piqirun_buffer()) -> float().

-spec binary_of_block/1 :: (
    piqirun_buffer()) -> binary().


non_neg_integer_of_varint(X) when is_integer(X) -> X.


integer_of_signed_varint(X)
        when is_integer(X) andalso (X band 16#8000000000000000 =/= 0) ->
    X - 16#10000000000000000;
integer_of_signed_varint(X) -> X.


integer_of_zigzag_varint(X) when is_integer(X) ->
    (X bsr 1) bxor (-(X band 1)).


boolean_of_varint(1) -> true;
boolean_of_varint(0) -> false.


parse_bool(X) -> boolean_of_varint(X).


non_neg_integer_of_fixed32(<<X:32/little-unsigned-integer>>) -> X.

integer_of_signed_fixed32(<<X:32/little-signed-integer>>) -> X.


non_neg_integer_of_fixed64(<<X:64/little-unsigned-integer>>) -> X.

integer_of_signed_fixed64(<<X:64/little-signed-integer>>) -> X.


float_of_fixed64(<<X:64/little-float>>) -> X + 0.0.

float_of_fixed32(<<X:32/little-float>>) -> X + 0.0.


binary_of_block({'block', X}) -> X.

