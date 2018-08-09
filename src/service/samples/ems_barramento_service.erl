%%********************************************************************
%% @title Module ems_barramento_service
%% @version 1.0.0
%% @doc It provides information about cluster.
%% @author Everton de Vargas Agilar <evertonagilar@gmail.com>
%% @copyright ErlangMS Team
%%********************tn************************************************


%% rr("/home/rcarauta/desenvolvimento/barramento/ems-bus/include/ems_config.hrl").

-module(ems_barramento_service).

-include("../include/ems_config.hrl").
-include("../include/ems_schema.hrl").

-export([execute/1]).
  
execute(Request) -> 
	Conf = ems_config:getConfig(),
	AppName = ems_util:get_param_url(<<"name">>, undefined, Request),
	case ems_client:find_by_name(AppName) of
		{ok, Client} ->

			ContentData = iolist_to_binary([<<"{"/utf8>>,
				<<"\"ip\":\""/utf8>>, Conf#config.tcp_listen_main_ip, <<"\","/utf8>>,
				<<"\"http_port\":"/utf8>>, integer_to_binary(2301), <<","/utf8>>,
				<<"\"https_port\":"/utf8>>, integer_to_binary(2344), <<","/utf8>>,
				<<"\"base_url\":\""/utf8>>, <<"http://"/utf8>>, Conf#config.tcp_listen_main_ip, <<":"/utf8>>, <<"2301"/utf8>>, <<"\","/utf8>>,
				<<"\"auth_url\":\""/utf8>>, <<"http://"/utf8>>, Conf#config.tcp_listen_main_ip, <<":"/utf8>>, <<"2301"/utf8>>, <<"/authorize\","/utf8>>,
				<<"\"auth_protocol\":\"auth2\","/utf8>>,
				<<"\"app_id\":"/utf8>>, integer_to_binary(Client#client.id), <<","/utf8>>,
				<<"\"app_name\":\""/utf8>>, Client#client.name, <<"\","/utf8>>,
				<<"\"app_version\":\""/utf8>>, Client#client.version, <<"\","/utf8>>,
				<<"\"environment\":\"desenv\","/utf8>>,
				<<"\"docker_version\":\"\","/utf8>>,
				<<"\"url_mask\":false,"/utf8>>,
				<<"\"erlangms_version\":\""/utf8>>, list_to_binary(ems_util:version()), <<"\""/utf8>>,
				<<"}"/utf8>>]),
			{ok, Request#request{code = 200,
				response_data = ContentData}
			};

		_ ->

			Username = "erlangms",
			Password = "5outLag1",
			Type = "application/x-www-form-urlencoded",
			Payload = "grant_type=password&username="++Username++"&password="++Password,
			{ok, {{"HTTP/1.1", 200, _ReasonPhrase}, _Headers, _Body}} = httpc:request(post, {[Conf#config.rest_auth_url], [],Type,Payload}, [], []),
			DecodeJson = ems_util:json_decode(_Body),

			case DecodeJson of
				{_Client,_AccessToken,_Expiress,_Resource,_Scope,_RefreshToken,_RefreshTokenIn,_TokenType} ->
					GetHeader = [{"Authentication","Bearer "++binary_to_list(_AccessToken)}],
					{ok, {{"HTTP/1.1", 200, _ReasonPhrase}, _Headers, _Body}} = httpc:request(get,{Conf#config.rest_base_url, GetHeader,"application/json",""},[],[]),
						io:format(_Body)
			end,

			io:format("Body >>>>>>>>>>>>>>>>> ~p~n~n",_Body),
			io:format("Chegou até aqui >>>>>>>> ~n~n~n")
	end.






