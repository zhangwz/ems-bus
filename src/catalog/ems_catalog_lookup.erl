%%********************************************************************
%% @title Module ems_catalog_lookup
%% @version 1.0.0
%% @doc Module responsible for catalog lookup
%% @author Everton de Vargas Agilar <evertonagilar@gmail.com>
%% @copyright ErlangMS Team
%%********************************************************************

-module(ems_catalog_lookup).

-include("../include/ems_config.hrl").
-include("../include/ems_schema.hrl").

-export([lookup/1, 
		 lookup/2,
		 find_fs/2,  
		 list_kernel_catalog/0, 
		 list_re_catalog/0]).

-spec find_fs(catalog_get_fs | catalog_post_fs | catalog_put_fs | catalog_delete_fs | catalog_options_fs | catalog_kernel_fs, non_neg_integer()) -> {ok, #service{}} | {error, atom()}.
find_fs(Table, Rowid) ->
	case ems_db:find_first(Table, [{rowid, "==", Rowid}]) of
		{error, Reason} -> {error, Reason};
		Record -> {ok, setelement(1, Record, service)}
	end.


lookup(Request = #request{type = Type, rowid = Rowid, params_url = ParamsMap}) ->	
	case Type of
		"GET" -> EtsLookup = ets_get;
		"POST" -> EtsLookup = ets_post;
		"PUT" -> EtsLookup = ets_put;
		"DELETE" -> EtsLookup = ets_delete;
		"OPTIONS" -> EtsLookup = ets_options;
		"HEAD" -> EtsLookup = ets_get;
		"INFO" -> EtsLookup = ets_get
	end,
	case ets:lookup(EtsLookup, Rowid) of
		[] -> % is regular expression??
			case lookup_re(Request, list_re_catalog()) of
				{error, enoent} = Error -> Error;
				{Service, ParamsMapRE} -> 
					Querystring = processa_querystring(Service, Request),
					{Service, ParamsMapRE, Querystring}
			end;
		[{_Rowid, Service}] -> 
			Querystring = processa_querystring(Service, Request),
			{Service, ParamsMap, Querystring}
	end.

lookup(Method, Uri) ->
	case ems_util:encode_request(Method, Uri) of
		{ok, Request} -> lookup(Request);
		Error -> Error
	end.

-spec list_kernel_catalog() -> list(tuple()).
list_kernel_catalog() ->
	case mnesia:table_info(catalog_kernel_fs, size) == 0 of
		true -> 
			Conf = ems_config:getConfig(),
			case ems_json_scan:scan_with_filter(Conf#config.cat_path_search, Conf, <<"type">>, <<"KERNEL">>) of
				{ok, CatKernel} -> 
					CatKernel2 = [ems_catalog:new_service_from_map(Map, Conf) || Map <- CatKernel],
					CatKernel3 = [Cat || {Reason, Cat} <- CatKernel2, Reason == ok],
					CatKernel3;
				Error -> Error
			end;
		false ->
			case ems_db:all(catalog_kernel_fs) of
				{ok, CatKernel} -> [setelement(1, Cat, service) || Cat <- CatKernel];
				Error -> Error
			end
	end.

list_re_catalog() ->
	case ets:lookup(ets_ems_catalog, cat) of
		[] -> {error, enoent};
		[{cat, {_, CatRE, _}}] -> CatRE
	end.
    
    
%%====================================================================
%% Funções internas
%%====================================================================

processa_querystring(Service, Request) ->
	%% Querystrings do módulo ems_static_file_service e ems_options_service não são processados.
	QuerystringUser = Request#request.querystring_map,
	case Service#service.module of
		ems_static_file_service -> QuerystringUser;
		ems_options_service -> QuerystringUser;
		_ ->
			QuerystringServico = Service#service.querystring,
			case QuerystringUser =:= #{} of
				true -> 
					case QuerystringServico =:= [] of
						true -> QuerystringUser;
						false -> valida_querystring(QuerystringServico, QuerystringUser, [])
					end;
				false -> 
					case QuerystringServico =:= [] of
						true -> #{};
						false -> valida_querystring(QuerystringServico, QuerystringUser, [])
					end
			end
	end.

valida_querystring([], _QuerystringUser, QuerystringList) -> maps:from_list(QuerystringList);
valida_querystring([H|T], QuerystringUser, QuerystringList) ->
	%% Verifica se encontra a query na querystring do usuário
	NomeQuery = maps:get(<<"name">>, H),
	case maps:find(NomeQuery, QuerystringUser) of
		{ok, Value} -> 
			valida_querystring(T, QuerystringUser, [{NomeQuery, Value} | QuerystringList]);
		error ->
			%% se o usuário não informou a querystring, verifica se tem valor default na definição do serviço
			case maps:get(<<"default">>, H, enoent) of
				enoent -> [];
				Value -> valida_querystring(T, QuerystringUser, [{NomeQuery, Value} | QuerystringList])
			end
	end.

lookup_re(_, []) -> {error, enoent};
lookup_re(Request = #request{type = Type, url = Url}, [H|T]) ->
	try
		RE = H#service.id_re_compiled,
		PatternKey = ems_util:make_rowid_from_url(Url, Type),
		case re:run(PatternKey, RE, [{capture,all_names,binary}]) of
			match -> {H, #{}};
			{match, Params} -> 
				{namelist, ParamNames} = re:inspect(RE, namelist),
				ParamsMap = maps:from_list(lists:zip(ParamNames, Params)),
				{H, ParamsMap};
			nomatch -> lookup_re(Request, T);
			{error, _ErrType} -> {error, enoent}
		end
	catch 
		_Exception:_Reason -> {error, enoent}
	end.


