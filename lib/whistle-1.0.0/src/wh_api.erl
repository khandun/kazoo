%%%-------------------------------------------------------------------
%%% @author James Aimonetti <james@2600hz.org>
%%% @copyright (C) 2010, VoIP INC
%%% @doc
%%% Whistle API Helpers
%%%
%%% Most API functions take a proplist, filter it against required headers
%%% and optional headers, and return either the JSON string if all
%%% required headers (default AND API-call-specific) are present, or an
%%% error if some headers are missing.
%%%
%%% To only check the validity, use the api call's corresponding *_v/1 function.
%%% This will parse the proplist and return a boolean()if the proplist is valid
%%% for creating a JSON message.
%%%
%%% @end
%%% Created : 19 Aug 2010 by James Aimonetti <james@2600hz.org>
%%%-------------------------------------------------------------------
-module(wh_api).

%% API
-export([default_headers/5, extract_defaults/1]).

%% In-Call
-export([error_resp/1]).

%% Maintenance API calls
-export([mwi_update/1]).

%% Conference Members
-export([conference_participants_req/1, conference_participants_resp/1, conference_play_req/1, conference_deaf_req/1,
         conference_undeaf_req/1, conference_mute_req/1, conference_unmute_req/1, conference_kick_req/1,
         conference_move_req/1, conference_discovery_req/1
	]).

-export([error_resp_v/1]).

-export([conference_participants_req_v/1, conference_participants_resp_v/1, conference_play_req_v/1, conference_deaf_req_v/1
         ,conference_undeaf_req_v/1, conference_mute_req_v/1, conference_unmute_req_v/1, conference_kick_req_v/1
         ,conference_move_req_v/1, conference_discovery_req_v/1, mwi_update_v/1
	]).

%% Other AMQP API validators can use these helpers
-export([build_message/3, build_message_specific/3, build_message_specific_headers/3
	 ,validate/4, validate_message/4]).

%% FS-specific routines
-export([convert_fs_evt_name/1, convert_whistle_app_name/1]).

-include("wh_api.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc Default Headers in all messages - see wiki
%% Creates the seed proplist for the eventual message to be sent
%% All fields are required general headers.
%% @end
%%--------------------------------------------------------------------
-spec default_headers/5 :: (ServerID, EvtCat, EvtName, AppName, AppVsn) -> proplist() when
      ServerID :: binary(),
      EvtCat :: binary(),
      EvtName :: binary(),
      AppName :: binary(),
      AppVsn :: binary().
default_headers(ServerID, EvtCat, EvtName, AppName, AppVsn) ->
    [{<<"Server-ID">>, ServerID}
     ,{<<"Event-Category">>, EvtCat}
     ,{<<"Event-Name">>, EvtName}
     ,{<<"App-Name">>, AppName}
     ,{<<"App-Version">>, AppVsn}
    ].

%%--------------------------------------------------------------------
%% @doc Extract just the default headers from a message
%% @end
%%--------------------------------------------------------------------
-spec extract_defaults/1 :: (Prop) -> proplist() when
      Prop :: proplist() | json_object().
extract_defaults({struct, Prop}) ->
    extract_defaults(Prop);
extract_defaults(Prop) ->
    lists:foldl(fun(H, Acc) ->
			case props:get_value(H, Prop) of
			    undefined -> Acc;
			    V -> [{H, V} | Acc]
			end
		end, [], ?DEFAULT_HEADERS ++ ?OPTIONAL_DEFAULT_HEADERS).

%%--------------------------------------------------------------------
%% @doc Format an error event
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec error_resp/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
error_resp({struct, Prop}) ->
    error_resp(Prop);
error_resp(Prop) ->
    case error_resp_v(Prop) of
	true -> build_message(Prop, ?ERROR_RESP_HEADERS, ?OPTIONAL_ERROR_RESP_HEADERS);
	false -> {error, "Proplist failed validation for error_resp"}
    end.

-spec error_resp_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
error_resp_v({struct, Prop}) ->
    error_resp_v(Prop);
error_resp_v(Prop) ->
    validate(Prop, ?ERROR_RESP_HEADERS, ?ERROR_RESP_VALUES, ?ERROR_RESP_TYPES).

%%--------------------------------------------------------------------
%% @doc MWI - Update the Message Waiting Indicator on a device - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec mwi_update/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
      Prop :: proplist() | json_object().
mwi_update({struct, Prop}) ->
    mwi_update(Prop);
mwi_update(Prop) ->
    case mwi_update_v(Prop) of
	true -> build_message(Prop, ?MWI_REQ_HEADERS, ?OPTIONAL_MWI_REQ_HEADERS);
	false -> {error, "Proplist failed validation for mwi_req"}
    end.

-spec mwi_update_v/1 :: (Prop) -> boolean() when
      Prop :: proplist() | json_object().
mwi_update_v({struct, Prop}) ->
    mwi_update_v(Prop);
mwi_update_v(Prop) ->
    validate(Prop, ?MWI_REQ_HEADERS, ?MWI_REQ_VALUES, ?MWI_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::discovery - Used to identify the conference ID
%% if not provided, locate the conference focus, and return sip url
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_discovery_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_discovery_req({struct, Prop}) ->
    conference_discovery_req(Prop);
conference_discovery_req(Prop) ->
    case conference_discovery_req_v(Prop) of
	true -> build_message(Prop, ?CONF_DISCOVERY_REQ_HEADERS, ?OPTIONAL_CONF_DISCOVERY_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_discovery_req"}
    end.

-spec conference_discovery_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_discovery_req_v({struct, Prop}) ->
    conference_discovery_req_v(Prop);
conference_discovery_req_v(Prop) ->
    validate(Prop, ?CONF_DISCOVERY_REQ_HEADERS, ?CONF_DISCOVERY_REQ_VALUES, ?CONF_DISCOVERY_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::participants - Lists all participants of a conference
%%     or details about certain participants - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_participants_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_participants_req({struct, Prop}) ->
    conference_participants_req(Prop);
conference_participants_req(Prop) ->
    case conference_participants_req_v(Prop) of
	true -> build_message(Prop, ?CONF_PARTICIPANTS_REQ_HEADERS, ?OPTIONAL_CONF_PARTICIPANTS_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_participants_req"}
    end.

-spec conference_participants_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_participants_req_v({struct, Prop}) ->
    conference_participants_req_v(Prop);
conference_participants_req_v(Prop) ->
    validate(Prop, ?CONF_PARTICIPANTS_REQ_HEADERS, ?CONF_PARTICIPANTS_REQ_VALUES, ?CONF_PARTICIPANTS_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::participants - The response to participants - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_participants_resp/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_participants_resp({struct, Prop}) ->
    conference_participants_resp(Prop);
conference_participants_resp(Prop) ->
    case conference_participants_resp_v(Prop) of
	true -> build_message(Prop, ?CONF_PARTICIPANTS_RESP_HEADERS, ?OPTIONAL_CONF_PARTICIPANTS_RESP_HEADERS);
	false -> {error, "Proplist failed validation for conference_participants_resp"}
    end.

-spec conference_participants_resp_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_participants_resp_v({struct, Prop}) ->
    conference_participants_resp_v(Prop);
conference_participants_resp_v(Prop) ->
    validate(Prop, ?CONF_PARTICIPANTS_RESP_HEADERS, ?CONF_PARTICIPANTS_RESP_VALUES, ?CONF_PARTICIPANTS_RESP_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::play - Play audio to all or a single
%%     conference participant - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_play_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_play_req({struct, Prop}) ->
    conference_play_req(Prop);
conference_play_req(Prop) ->
    case conference_play_req_v(Prop) of
	true -> build_message(Prop, ?CONF_PLAY_REQ_HEADERS, ?OPTIONAL_CONF_PLAY_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_play_req"}
    end.

-spec conference_play_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_play_req_v({struct, Prop}) ->
    conference_play_req_v(Prop);
conference_play_req_v(Prop) ->
    validate(Prop, ?CONF_PLAY_REQ_HEADERS, ?CONF_PLAY_REQ_VALUES, ?CONF_PLAY_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::deaf - Make a conference participant deaf - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_deaf_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_deaf_req({struct, Prop}) ->
    conference_deaf_req(Prop);
conference_deaf_req(Prop) ->
    case conference_deaf_req_v(Prop) of
	true -> build_message(Prop, ?CONF_DEAF_REQ_HEADERS, ?OPTIONAL_CONF_DEAF_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_deaf_req"}
    end.

-spec conference_deaf_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_deaf_req_v({struct, Prop}) ->
    conference_deaf_req_v(Prop);
conference_deaf_req_v(Prop) ->
    validate(Prop, ?CONF_DEAF_REQ_HEADERS, ?CONF_DEAF_REQ_VALUES, ?CONF_DEAF_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::undeaf - Allows a specific conference participant to
%%     hear if they where marked deaf - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_undeaf_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_undeaf_req({struct, Prop}) ->
    conference_undeaf_req(Prop);
conference_undeaf_req(Prop) ->
    case conference_undeaf_req_v(Prop) of
	true -> build_message(Prop, ?CONF_UNDEAF_REQ_HEADERS, ?OPTIONAL_CONF_UNDEAF_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_undeaf_req"}
    end.

-spec conference_undeaf_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_undeaf_req_v({struct, Prop}) ->
    conference_undeaf_req_v(Prop);
conference_undeaf_req_v(Prop) ->
    validate(Prop, ?CONF_UNDEAF_REQ_HEADERS, ?CONF_UNDEAF_REQ_VALUES, ?CONF_UNDEAF_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::mute - Mutes a specific participant in a
%%     conference - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_mute_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_mute_req({struct, Prop}) ->
    conference_mute_req(Prop);
conference_mute_req(Prop) ->
    case conference_mute_req_v(Prop) of
	true -> build_message(Prop, ?CONF_MUTE_REQ_HEADERS, ?OPTIONAL_CONF_MUTE_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_mute_req"}
    end.

-spec conference_mute_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_mute_req_v({struct, Prop}) ->
    conference_mute_req_v(Prop);
conference_mute_req_v(Prop) ->
    validate(Prop, ?CONF_MUTE_REQ_HEADERS, ?CONF_MUTE_REQ_VALUES, ?CONF_MUTE_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::unmute - Unmutes a specific participant in a
%%     conference - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_unmute_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_unmute_req({struct, Prop}) ->
    conference_unmute_req(Prop);
conference_unmute_req(Prop) ->
    case conference_unmute_req_v(Prop) of
	true -> build_message(Prop, ?CONF_UNMUTE_REQ_HEADERS, ?OPTIONAL_CONF_UNMUTE_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_unmute_req"}
    end.

-spec conference_unmute_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_unmute_req_v({struct, Prop}) ->
    conference_unmute_req_v(Prop);
conference_unmute_req_v(Prop) ->
    validate(Prop, ?CONF_UNMUTE_REQ_HEADERS, ?CONF_UNMUTE_REQ_VALUES, ?CONF_UNMUTE_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::kick - Removes a participant from a conference - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_kick_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_kick_req({struct, Prop}) ->
    conference_kick_req(Prop);
conference_kick_req(Prop) ->
    case conference_kick_req_v(Prop) of
	true -> build_message(Prop, ?CONF_KICK_REQ_HEADERS, ?OPTIONAL_CONF_KICK_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_kick_req"}
    end.

-spec conference_kick_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_kick_req_v({struct, Prop}) ->
    conference_kick_req_v(Prop);
conference_kick_req_v(Prop) ->
    validate(Prop, ?CONF_KICK_REQ_HEADERS, ?CONF_KICK_REQ_VALUES, ?CONF_KICK_REQ_TYPES).

%%--------------------------------------------------------------------
%% @doc Conference::move - Transfers a participant between to
%%     conferences - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec conference_move_req/1 :: (Prop) -> {'ok', iolist()} | {'error', string()} when
    Prop :: proplist() | json_object().
conference_move_req({struct, Prop}) ->
    conference_move_req(Prop);
conference_move_req(Prop) ->
    case conference_move_req_v(Prop) of
	true -> build_message(Prop, ?CONF_MOVE_REQ_HEADERS, ?OPTIONAL_CONF_MOVE_REQ_HEADERS);
	false -> {error, "Proplist failed validation for conference_move_req"}
    end.

-spec conference_move_req_v/1 :: (Prop) -> boolean() when
    Prop :: proplist() | json_object().
conference_move_req_v({struct, Prop}) ->
    conference_move_req_v(Prop);
conference_move_req_v(Prop) ->
    validate(Prop, ?CONF_MOVE_REQ_HEADERS, ?CONF_MOVE_REQ_VALUES, ?CONF_MOVE_REQ_TYPES).

%% given a proplist of a FS event, return the Whistle-equivalent app name(s).
%% a FS event could have multiple Whistle equivalents
-spec convert_fs_evt_name/1 :: (EvtName) -> [binary(),...] | [] when
      EvtName :: binary().
convert_fs_evt_name(EvtName) ->
    [ WhAppEvt || {FSEvt, WhAppEvt} <- ?SUPPORTED_APPLICATIONS, FSEvt =:= EvtName].

%% given a Whistle Dialplan Application name, return the FS-equivalent event name
%% A Whistle Dialplan Application name is 1-to-1 with the FS-equivalent
-spec convert_whistle_app_name/1 :: (App) -> [binary(),...] | [] when
      App :: binary().
convert_whistle_app_name(App) ->
    [EvtName || {EvtName, AppName} <- ?SUPPORTED_APPLICATIONS, App =:= AppName].

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec validate/4 :: (Prop, ReqHeaders, DefValues, DefTypes) -> boolean() when
      Prop :: proplist(),
      ReqHeaders :: [binary(),...] | [],
      DefValues :: proplist(),
      DefTypes :: proplist().
validate(Prop, ReqH, Vals, Types) ->
    has_all(Prop, ?DEFAULT_HEADERS) andalso
	validate_message(Prop, ReqH, Vals, Types).

-spec validate_message/4 :: (Prop, ReqHeaders, DefValues, DefTypes) -> boolean() when
      Prop :: proplist(),
      ReqHeaders :: [binary(),...] | [],
      DefValues :: proplist(),
      DefTypes :: proplist().
validate_message(Prop, ReqH, Vals, Types) ->
    has_all(Prop, ReqH) andalso
	values_check(Prop, Vals) andalso
	type_check(Prop, Types).

-spec build_message/3 :: (Prop, ReqHeaders, OptHeaders) -> {'ok', iolist()} | {'error', string()} when
      Prop :: proplist(),
      ReqHeaders :: [binary(),...] | [],
      OptHeaders:: [binary(),...] | [].
build_message(Prop, ReqH, OptH) ->
    case defaults(Prop) of
	{error, _Reason}=Error ->
	    io:format("Build Error: ~p~nDefHeaders: ~p~nPassed: ~p~n", [Error, ?DEFAULT_HEADERS, Prop]),
	    Error;
	HeadAndProp ->
	    case build_message_specific_headers(HeadAndProp, ReqH, OptH) of
		{ok, FinalHeaders} -> headers_to_json(FinalHeaders);
		Err -> Err
	    end
    end.

-spec build_message_specific_headers/3 :: (Msg, ReqHeaders, OptHeaders) -> {'ok', proplist()} | {'error', string()} when
      Msg :: proplist() | {[binary(),...] | [], proplist()},
      ReqHeaders :: [binary(),...] | [],
      OptHeaders :: [binary(),...] | [].
build_message_specific_headers({Headers, Prop}, ReqH, OptH) ->
    case update_required_headers(Prop, ReqH, Headers) of
	{error, _Reason} = Error ->
	    io:format("Build Error: ~p~nReqHeaders: ~p~nPassed: ~p~n", [Error, ReqH, Prop]),
	    Error;
	{Headers1, Prop1} ->
	    {Headers2, _Prop2} = update_optional_headers(Prop1, OptH, Headers1),
	    {ok, Headers2}
    end;
build_message_specific_headers(Prop, ReqH, OptH) ->
    build_message_specific_headers({[], Prop}, ReqH, OptH).

-spec build_message_specific/3 :: (Msg, ReqHeaders, OptHeaders) -> {'ok', iolist()} | {'error', string()} when
      Msg :: proplist() | {[binary(),...] | [], proplist()},
      ReqHeaders :: [binary(),...] | [],
      OptHeaders :: [binary(),...] | [].
build_message_specific({Headers, Prop}, ReqH, OptH) ->
    case update_required_headers(Prop, ReqH, Headers) of
	{error, _Reason} = Error ->
	    io:format("Build Error: ~p~nReqHeaders: ~p~nPassed: ~p~n", [Error, ReqH, Prop]),
	    Error;
	{Headers1, Prop1} ->
	    {Headers2, _Prop2} = update_optional_headers(Prop1, OptH, Headers1),
	    headers_to_json(Headers2)
    end;
build_message_specific(Prop, ReqH, OptH) ->
    build_message_specific({[], Prop}, ReqH, OptH).

-spec headers_to_json/1 :: (HeadersProp) -> {'ok', iolist()} | {'error', string()} when
      HeadersProp :: proplist().
headers_to_json(HeadersProp) ->
    try
	{ok, mochijson2:encode({struct, HeadersProp})}
    catch
	_What:_Why -> {error, io_lib:format("WHISTLE TO_JSON ERROR(~p): ~p~n~p", [_What, _Why, HeadersProp])}
    end.

%% Checks Prop for all default headers, throws error if one is missing
%% defaults(PassedProps) -> { Headers, NewPropList } | {error, Reason}
-spec defaults/1 :: (Prop) -> {proplist(), proplist()} | {'error', string()} when
      Prop :: proplist() | json_object().
defaults(Prop) ->
    defaults(Prop, []).
defaults(Prop, Headers) ->
    case update_required_headers(Prop, ?DEFAULT_HEADERS, Headers) of
	{error, _Reason} = Error ->
	    Error;
	{Headers1, Prop1} ->
	    update_optional_headers(Prop1, ?OPTIONAL_DEFAULT_HEADERS, Headers1)
    end.

-spec update_required_headers/3 :: (Prop, Fields, Headers) -> {proplist(), proplist()} | {'error', string()} when
      Prop :: proplist(),
      Fields :: [binary(),...] | [],
      Headers :: proplist().
update_required_headers(Prop, Fields, Headers) ->
    case has_all(Prop, Fields) of
	true ->
	    add_headers(Prop, Fields, Headers);
	false ->
	    {error, "All required headers not defined"}
    end.

-spec update_optional_headers/3 :: (Prop, Fields, Headers) -> {proplist(), proplist()} when
      Prop :: proplist(),
      Fields :: [binary(),...] | [],
      Headers :: proplist().
update_optional_headers(Prop, Fields, Headers) ->
    case has_any(Prop, Fields) of
	true ->
	    add_optional_headers(Prop, Fields, Headers);
	false ->
	    {Headers, Prop}
    end.

%% add [Header] from Prop to HeadProp
-spec add_headers/3 :: (Prop, Fields, Headers) -> {proplist(), proplist()} when
      Prop :: proplist(),
      Fields :: [binary(),...] | [],
      Headers :: proplist().
add_headers(Prop, Fields, Headers) ->
    lists:foldl(fun(K, {Headers1, KVs}) ->
			{[{K, props:get_value(K, KVs)} | Headers1], props:delete(K, KVs)}
		end, {Headers, Prop}, Fields).

-spec add_optional_headers/3 :: (Prop, Fields, Headers) -> {proplist(), proplist()} when
      Prop :: proplist(),
      Fields :: [binary(),...] | [],
      Headers :: proplist().
add_optional_headers(Prop, Fields, Headers) ->
    lists:foldl(fun(K, {Headers1, KVs}) ->
			case props:get_value(K, KVs) of
			    undefined ->
				{Headers1, KVs};
			    V ->
				{[{K, V} | Headers1], props:delete(K, KVs)}
			end
		end, {Headers, Prop}, Fields).

%% Checks Prop against a list of required headers, returns true | false
-spec has_all/2 :: (Prop, Headers) -> boolean() when
      Prop :: proplist(),
      Headers :: [binary(),...] | [].
has_all(Prop, Headers) ->
    lists:all(fun(Header) ->
		      case props:is_defined(Header, Prop) of
			  true -> true;
			  false ->
			      io:format("WHISTLE_API.has_all: Failed to find ~p~nProp: ~p~n", [Header, Prop]),
			      false
		      end
	      end, Headers).

%% Checks Prop against a list of optional headers, returns true | false if at least one if found
-spec has_any/2 :: (Prop, Headers) -> boolean() when
      Prop :: proplist(),
      Headers :: [binary(),...] | [].
has_any(Prop, Headers) ->
    lists:any(fun(Header) -> props:is_defined(Header, Prop) end, Headers).

%% checks Prop against a list of values to ensure known key/value pairs are correct (like Event-Category
%% and Event-Name). We don't care if a key is defined in Values and not in Prop; that is handled by has_all/1
values_check(Prop, Values) ->
    lists:all(fun({Key, Vs}) when is_list(Vs) ->
		      case props:get_value(Key, Prop) of
			  undefined -> true; % isn't defined in Prop, has_all will error if req'd
			  V -> case lists:member(V, Vs) of
				   true -> true;
				   false ->
				       io:format("WHISTLE_API.values_check: K: ~p V: ~p not in ~p~n", [Key, V, Vs]),
				       false
			       end
		      end;
		 ({Key, V}) ->
		      case props:get_value(Key, Prop) of
			  undefined -> true; % isn't defined in Prop, has_all will error if req'd
			  V -> true;
			  _Val ->
			      io:format("WHISTLE_API.values_check: Key: ~p Set: ~p Expected: ~p~n", [Key, _Val, V]),
			      false
		      end
	      end, Values).

%% checks Prop against a list of {Key, Fun}, running the value of Key through Fun, which returns a
%% boolean.
type_check(Prop, Types) ->
    lists:all(fun({Key, Fun}) ->
		      case props:get_value(Key, Prop) of
			  undefined -> true; % isn't defined in Prop, has_all will error if req'd
			  Value -> try case Fun(Value) of % returns boolean
					   true -> true;
					   false ->
					       io:format("WHISTLE_API.type_check: K: ~p V: ~p failed fun~n", [Key, Value]),
					       false
				       end
				   catch _:_ -> io:format("WHISTLE_API.type_check: K: ~p V: ~p threw exception~n", [Key, Value]),
						false
				   end
		      end
	      end, Types).

%% EUNIT TESTING

-include_lib("eunit/include/eunit.hrl").
-ifdef(TEST).

has_all_test() ->
    Prop = [{<<"k1">>, <<"v1">>}
	    ,{<<"k2">>, <<"v2">>}
	    ,{<<"k3">>, <<"v3">>}
	    ],
    Headers = [<<"k1">>, <<"k2">>, <<"k3">>],
    ?assertEqual(true, has_all(Prop, Headers)),
    ?assertEqual(false, has_all(Prop, [<<"k4">> | Headers])),
    ok.

has_any_test() ->
    Prop = [{<<"k1">>, <<"v1">>}
	    ,{<<"k2">>, <<"v2">>}
	    ,{<<"k3">>, <<"v3">>}
	   ],
    Headers = [<<"k1">>, <<"k2">>, <<"k3">>],
    ?assertEqual(true, has_any(Prop, Headers)),
    ?assertEqual(false, has_any(Prop, [<<"k4">>])),
    ok.

-endif.
