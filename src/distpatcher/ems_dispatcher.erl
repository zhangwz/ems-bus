%%********************************************************************
%% @title Module ems_dispatcher
%% @version 1.0.0
%% @doc Responsible for forwarding the requests to services.
%% @author Everton de Vargas Agilar <evertonagilar@gmail.com>
%% @copyright ErlangMS Team
%%********************************************************************

-module(ems_dispatcher).

-include("../include/ems_config.hrl").
-include("../include/ems_schema.hrl").
-include("../include/ems_http_messages.hrl").

%% Client API
-export([start/0, dispatch_request/1]).


start() -> 
	ets:new(ctrl_node_dispatch, [set, named_table, public]),
	ems_dispatcher_cache:start().


dispatch_request(Request = #request{type = "GET", 
									url_hash = UrlHash, 
									t1 = Timestamp}) -> 
	case ems_dispatcher_cache:lookup(UrlHash, Timestamp) of
		{true, RequestCache} -> 
			?DEBUG("Lookup request in cache. Request: ~p.", [RequestCache]),
			{ok, Request#request{result_cache = true,
								 code = RequestCache#request.code,
								 reason = RequestCache#request.reason,
								 response_data = RequestCache#request.response_data,
								 response_header = RequestCache#request.response_header,
								 result_cache_rid = RequestCache#request.rid,
								 latency = RequestCache#request.latency}};
		false -> lookup_request(Request)
	end;
dispatch_request(Request) -> lookup_request(Request).
	
lookup_request(Request = #request{type = Type,
								  url = Url,
								  rowid = Rowid}) -> 
	?DEBUG("Lookup request ~p.", [Request]),
	case ems_catalog:lookup(Request) of
		{Service, ParamsMap, QuerystringMap} -> 
			% Autenticate user request
			case ems_auth_user:autentica(Service, Request) of
				{ok, User} ->
					% get a worker node to process a service	
					case get_work_node(Service#service.host, 
									   Service#service.host,	
									   Service#service.host_name, 
									   Service#service.module_name, 1) of
						{ok, Node} ->
							Request2 = Request#request{user = User, 
													   node_exec = Node,
													   service = Service,
													   params_url = ParamsMap,
													   querystring_map = QuerystringMap},
							case ems_web_service:execute(Request2) of
								{ok, Request3} -> 
									case Type =:= "POST" orelse Type =:= "PUT" orelse Type =:= "DELETE" of
										true -> 
											% After POST, PUT or DELETE operation, invalidate request get cache
											ems_dispatcher_cache:invalidate(Rowid);
										false -> ok
									end,
									{ok, Request3};
								{error, Request3} -> {error, request, Request3}
							end;
						Error ->  Error
					end;
				Error -> Error
			end;
		{error, Reason} = Error -> 
			ems_logger:info("Lookup request ~p fail. Reason: ~p.", [Url, Reason]),
			Error
	end.



get_work_node('', _, _, _, _) -> {ok, node()};
get_work_node([], _, _, _, _) -> {error, eunavailable_service};
get_work_node([_|T], HostList, HostNames, ModuleName, Tentativa) -> 
	QtdHosts = length(HostList),
	case QtdHosts == 1 of
		true -> Node = hd(HostList);
		false ->
			% ========= faz round robin ===========
			%% Localiza a entrada do módulo na tabela hash
			case ets:lookup(ctrl_node_dispatch, ModuleName) of
				[] -> 
					% não encontrou, vamos selecionar o primeiro host mas o próximo será o segundo
					Index = 2,
					Node = hd(HostList);
				[{_, Idx}] -> 
					% Se o idx não existe pega o primeiro e o próximo será o segundo
					case Idx > QtdHosts of
						true -> 
							Index = 2,
							Node = hd(HostList);
						false -> 
							Node = lists:nth(Idx, HostList),
							Index = Idx + 1
					end
			end,
			% Inserimos na tabela hash os dados de controle
			ets:insert(ctrl_node_dispatch, {ModuleName, Index})
	end,

	
	% Este node está vivo? Temos que rotear para um node existente
	Ping = net_adm:ping(Node),
	?DEBUG("Ping ~p: ~p.", [Node, Ping]),
	case Ping of
		pong -> {ok, Node};
		pang -> get_work_node(T, HostList, HostNames, ModuleName, Tentativa)
	end.
		
