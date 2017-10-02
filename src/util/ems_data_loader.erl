%%********************************************************************
%% @title Module ems_data_loader
%% @version 1.0.0
%% @doc ems_data_loader
%% @author Everton de Vargas Agilar <evertonagilar@gmail.com>
%% @copyright ErlangMS Team
%%********************************************************************

-module(ems_data_loader).

-behavior(gen_server). 

-include("../include/ems_config.hrl").
-include("../include/ems_schema.hrl").

%% Server API
-export([start/1, stop/0]).


%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/1, handle_info/2, terminate/2, code_change/3, 
		 last_update/0, is_empty/0, size_table/0, sync/0, pause/0, resume/0]).

% estado do servidor
-record(state, {name,
			    datasource,
				update_checkpoint,
				last_update,
				allow_load_aluno,
				table,
				last_update_param_name,
				sql_load,
				sql_update,
				middleware
			}).

-define(SERVER, ?MODULE).

%%====================================================================
%% Server API
%%====================================================================

start(Service#service{name = Name}) -> 
    gen_server:start_link({local, ?SERVER}, ?MODULE, Service, []).
 
stop() ->
    gen_server:cast(?SERVER, shutdown).
 
last_update() -> ems_db:get_param(<<"ems_data_loader_lastupdate">>).
	
is_empty() -> mnesia:table_info(catalog, size) == 0.

size_table() -> mnesia:table_info(catalog, size).

sync() -> 
	gen_server:cast(?SERVER, force_load_catalogs),
	ok.

pause() ->
	gen_server:cast(?SERVER, pause),
	ok.

resume() ->
	gen_server:cast(?SERVER, resume),
	ok.

 
%%====================================================================
%% gen_server callbacks
%%====================================================================
 
init(#service{name = Name, 
			  datasource = Datasource, 
			  middleware = Middleware, 
			  properties = Props}) ->
	LastUpdateParamName = binary_to_atom(maps:get(<<"last_update_param_name">>, Props, <<>>)),
	LastUpdate = ems_db:get_param(LastUpdateParamName),
	UpdateCheckpoint = maps:get(<<"update_checkpoint">>, Props, ?USER_LOADER_UPDATE_CHECKPOINT),
	SqlLoad = binary_to_list(maps:get(<<"sql_load">>, Props, <<>>)),
	SqlUpdate = binary_to_list(maps:get(<<"sql_update">>, Props, <<>>)),
	Table = binary_to_list(maps:get(<<"table">>, Props, <<>>)),
	erlang:send_after(60000 * 60, self(), check_force_load_catalogs),
	State = #state{name = Name,
				   datasource = Datasource, 
				   update_checkpoint = UpdateCheckpoint,
				   last_update_param_name = LastUpdateParamName,
				   last_update = LastUpdate,
				   sql_load = SqlLoad,
				   sql_update = SqlUpdate,
				   table = Table,
				   middleware = Middleware},
	{ok, State, 7000}.
    
handle_cast(shutdown, State) ->
    {stop, normal, State};

handle_cast(force_load_catalogs, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	State2 = State#state{last_update = undefined},
	case update_or_load_catalogs(State2) of
		{ok, State3} ->  {noreply, State3, UpdateCheckpoint};
		_Error -> {noreply, State, UpdateCheckpoint}
	end;

handle_cast(pause, State) ->
	ems_logger:info("ems_data_loader paused."),
	{noreply, State};

handle_cast(resume, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	ems_logger:info("ems_data_loader resume."),
	{noreply, State, UpdateCheckpoint};

handle_cast(_Msg, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	{noreply, State, UpdateCheckpoint}.

handle_call(Msg, _From, State) ->
	{reply, Msg, State}.

handle_info(State = #state{update_checkpoint = UpdateCheckpoint}) ->
   {noreply, State, UpdateCheckpoint}.

handle_info(check_force_load_catalogs, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	{{_, _, _}, {Hour, _, _}} = calendar:local_time(),
	case Hour >= 4 andalso Hour =< 6 of
		true ->
			ems_logger:info("ems_data_loader force load catalogs checkpoint."),
			State2 = State#state{last_update = undefined},
			case update_or_load_catalogs(State2) of
				{ok, State3} ->
					erlang:send_after(86400 * 1000, self(), check_force_load_catalogs),
					{noreply, State3, UpdateCheckpoint};
				{error, _Reason} -> 
					erlang:send_after(86400 * 1000, self(), check_force_load_catalogs),
					{noreply, State, UpdateCheckpoint}
			end;
		_ -> 
			erlang:send_after(60000 * 60, self(), check_force_load_catalogs),
			{noreply, State, UpdateCheckpoint}
	end;

handle_info(timeout, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	case update_or_load_catalogs(State) of
		{ok, State2} ->	{noreply, State2, UpdateCheckpoint};
		{error, eunavailable_odbc_connection} -> 
			ems_logger:warn("ems_data_loader wait 5 minutes for next checkpoint while has no connection to load catalogs."),
			{noreply, State};
		_Error -> {noreply, State, UpdateCheckpoint}
	end;
			
handle_info({_Pid, {error, Reason}}, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	ems_logger:warn("ems_data_loader is unable to load or update catalogs. Reason: ~p.", [Reason]),
	{noreply, State, UpdateCheckpoint};
			
handle_info(_, State = #state{update_checkpoint = UpdateCheckpoint}) ->
	{noreply, State, UpdateCheckpoint}.
			
terminate(Reason, _State) ->
    ems_logger:warn("ems_data_loader was terminated. Reason: ~p.", [Reason]),
    ok.
 
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

	

%%====================================================================
%% Internal functions
%%====================================================================


update_or_load_catalogs(State = #state{datasource = Datasource,
									   last_update_param_name = LastUpdateParamName,
									   last_update = LastUpdate}) ->
	NextUpdate = ems_util:date_dec_minute(calendar:local_time(), 6), % garante que os dados serão atualizados mesmo que as datas não estejam sincronizadas
	LastUpdateStr = ems_util:timestamp_str(),
	case is_empty() orelse LastUpdate == undefined of
		true -> 
			?DEBUG("ems_data_loader checkpoint. operation: load_catalogs."),
			case load_catalogs_from_datasource(Datasource, LastUpdateStr, State) of
				ok -> 
					ems_db:set_param(LastUpdateParamName, NextUpdate),
					State2 = State#state{last_update = NextUpdate},
					{ok, State2};
				Error -> Error
			end;
		false ->
			?DEBUG("ems_data_loader checkpoint. operation: update_records   last_update: ~s.", [ems_util:timestamp_str(LastUpdate)]),
			case update_records_from_datasource(Datasource, LastUpdate, LastUpdateStr, State) of
				ok -> 
					ems_db:set_param(LastUpdateParamName, NextUpdate),
					State2 = State#state{last_update = NextUpdate},
					{ok, State2};
				Error -> Error
			end
	end.


load_catalogs_from_datasource(Datasource, CtrlInsert, #state{table = Table,
															 sql_load = SqlLoad,
															 middleware = Middleware}) -> 
	try
		case ems_odbc_pool:get_connection(Datasource) of
			{ok, Datasource2} -> 
				?DEBUG("ems_data_loader load_catalogs_from_datasource use datasource ~p.", [Datasource2#service_datasource.id]),
				Result = case ems_odbc_pool:param_query(Datasource2, SqlLoadUsersTipoPessoa, []) of
					{_,_,[]} -> 
						ems_odbc_pool:release_connection(Datasource2),
						?DEBUG("ems_data_loader did not load any catalogs tipo pessoa."),
						ok;
					{_, _, Records} ->
						ems_odbc_pool:release_connection(Datasource2),
						case mnesia:clear_table(table) of
							{atomic, ok} ->
								ems_db:init_sequence(table, 0),
								InsertFunc = fun() ->
									CountRecords = insert_records(Records, 0, CtrlInsert, Middleware),
									ems_logger:info("ems_data_loader load ~p catalogs tipo pessoa.", [CountRecords])
								end,
								mnesia:activity(transaction, InsertFunc),
								ok;
							_ ->
								ems_logger:error("ems_data_loader could not clear catalog table before load catalogs. Load catalogs cancelled!"),
								{error, efail_load_catalogs}
						end;
					{error, Reason2} = Error -> 
						ems_odbc_pool:release_connection(Datasource2),
						ems_logger:error("ems_data_loader load catalogs tipo pessoa query error: ~p.", [Reason2]),
						Error
				end,
				Result;
			Error2 -> 
				ems_logger:warn("ems_data_loader has no connection to load catalogs from database."),
				Error2
		end
	catch
		_Exception:Reason3 -> 
			ems_logger:error("ems_data_loader load catalogs exception error: ~p.", [Reason3]),
			{error, Reason3}
	end.

update_records_from_datasource(Datasource, LastUpdate, CtrlUpdate, #state{sql_update = SqlUpdate,	
																		  middleware = Middleware}) -> 
	try
		case ems_odbc_pool:get_connection(Datasource) of
			{ok, Datasource2} -> 
				?DEBUG("ems_data_loader update_records_from_datasource use datasource ~p.", [Datasource2#service_datasource.id]),
				{{Year, Month, Day}, {Hour, Min, _}} = LastUpdate,
				% Zera os segundos
				DateInitial = {{Year, Month, Day}, {Hour, Min, 0}},
				Params = [{sql_timestamp, [DateInitial]},
						  {sql_timestamp, [DateInitial]},
						  {sql_timestamp, [DateInitial]}],
				Result = case ems_odbc_pool:param_query(Datasource2, SqlUpdate, Params) of
					{_,_,[]} -> 
						ems_odbc_pool:release_connection(Datasource2),
						?DEBUG("ems_data_loader did not update any catalogs tipo pessoa."),
						ok;
					{_, _, Records} ->
						ems_odbc_pool:release_connection(Datasource2),
						LastUpdateStr = ems_util:timestamp_str(LastUpdate),
						UpdateFunc = fun() ->
							CountRecords = update_records(Records, 0, CtrlUpdate, Middleware),
							ems_logger:info("ems_data_loader update ~p catalogs tipo pessoa since ~s.", [CountRecords, LastUpdateStr])
						end,
						mnesia:activity(transaction, UpdateFunc),
						ok;
					{error, Reason} = Error -> 
						ems_odbc_pool:release_connection(Datasource2),
						ems_logger:error("ems_data_loader update catalogs tipo pessoa error: ~p.", [Reason]),
						Error
				end,
				Result;
			Error2 -> 
				ems_logger:warn("ems_data_loader has no connection to update catalogs from database."),
				Error2
		end
	catch
		_Exception:Reason3 -> 
			ems_logger:error("ems_data_loader udpate catalogs exception error: ~p.", [Reason3]),
			{error, Reason3}
	end.


insert_records([], Count, _CtrlInsert, _Middleware) -> Count;
insert_records([H|T], Count, CtrlInsert, Middleware) ->
	NewRecord = apply(Middleware, insert, [H]),
	mnesia:write(User),
	insert_records(T, Count+1, CtrlInsert).


update_records([], Count, _CtrlUpdate, _Middleware) -> Count;
update_records([H|T], Count, CtrlUpdate, Middleware) ->
	UpdatedRecord = apply(Middleware, update, [H]),
	mnesia:write(User2),
	?DEBUG("ems_data_loader update catalog: ~p.\n", [User2]),
	update_records(T, Count+1, CtrlUpdate).


