%%********************************************************************
%% @title ems_schema
%% @version 1.0.0
%% @doc It contains definitions of the data structures used.
%% @author Everton de Vargas Agilar <evertonagilar@gmail.com>
%% @copyright ErlangMS Team
%%********************************************************************

-record(sequence, {key :: atom(), 
				   index :: non_neg_integer()}).

-record(counter, {key :: atom(), 
     			  index :: non_neg_integer()}).

-record(user, {id :: non_neg_integer(), 					%% id (required)
			   codigo :: non_neg_integer(),					%% identificador externo (aceita duplicados)
			   login :: binary(),							%% login do usuário (required)
			   name :: binary(), 							%% nome do usuário
			   cpf :: binary(),
			   email :: binary(), 
			   password :: binary(),
			   type :: non_neg_integer(),					%% 0 = interno  1 = tecnico  2 = docente  3 = discente
			   subtype :: non_neg_integer(),				%% se aluno,  1 = extensao 2 = graduacao 3 = aperfeicoamento 4 = especializacao 5 = mestrado 6 = doutorado 7 = pos-doutorado 8 = residencia 9 = aluno especial - graduacao 10 = aluno especial - pos-graduacao 11 = estagio em pos-graduacao
			   passwd_crypto :: binary(),					%% Algoritmo criptografia: SHA1
			   type_email :: non_neg_integer(),				%% 1 = Institucional  2 = Pessoal
			   active :: boolean(),
			   endereco :: binary(),
			   complemento_endereco :: binary(),
			   bairro :: binary(),
			   cidade :: binary(),
			   uf :: binary(),
			   cep :: binary(),
			   rg :: binary(),
			   data_nascimento :: binary(),
			   sexo :: non_neg_integer(),
			   telefone :: binary(),
			   celular :: binary(),
			   ddd :: binary(),
			   matricula :: non_neg_integer(),
			   lotacao :: binary(),
			   lotacao_sigla :: binary(),
			   lotacao_centro :: binary(),
			   lotacao_codigo_funcao :: non_neg_integer(),
			   lotacao_funcao :: binary(),
			   lotacao_orgao :: binary(),
			   lotacao_codigo_cargo :: non_neg_integer(),
			   lotacao_cargo :: binary(),
			   ctrl_insert,
			   ctrl_update 
		}).
		
-record(user_permission, {id :: non_neg_integer(),	
						  hash :: non_neg_integer(),
						  hash2 :: non_neg_integer(),
						  name :: binary(),
						  url :: binary(),
						  grant_get :: boolean(),
						  grant_post :: boolean(),
						  grant_put :: boolean(),
						  grant_delete :: boolean(),
						  user_id :: non_neg_integer(),
						  sis_id :: non_neg_integer(),
						  perfil_id :: non_neg_integer(),
						  ctrl_insert,
						  ctrl_update
          }).


-record(user_perfil, {id :: non_neg_integer(), 					
					  perfil_id :: non_neg_integer(),					
					  user_id :: non_neg_integer(),					
					  name :: binary(), 
					  description :: binary(),
					  ctrl_insert,
					  ctrl_update 
		}).
          

-record(client, {id :: non_neg_integer(), 					
				 codigo :: non_neg_integer(),				
				 name :: binary(), 
			     description :: binary(),
			     secret :: binary(),
				 redirect_uri :: binary(),
				 active :: boolean(),
				 scope :: binary(),
				 ctrl_insert,
				 ctrl_update 
		}).






-record(ctrl_params, {name :: string(),
					  value
		}).

			   
-record(request, {
					  rid,       								%% Request ID (Identificador da requisição gerada automaticamente)
					  rowid,									%% Identificador interno da requisição
					  service,   								%% Contrato que estabelece o serviço que vai atender a requisição
					  timestamp, 								%% Timestamp de quando que a requisição ocorreu
					  latency :: non_neg_integer(),				%% Latência (tempo que levou para processar a requisição)
					  code = 200 :: non_neg_integer(), 			%% Código de retorno HTTP (Ex.: 202 OK, 404 Não Encontrado)
					  reason = ok :: atom(),					%% Registra a mensagem de erro, quando status indicar um erro
					  type :: string(),							%% Verbo HTTP (GET, POST, PUT, DELETE e OPTIONS)
					  uri :: string(),							%% URI da requisição do serviço
					  url :: string(),							%% URL da requisição do serviço
					  version :: string(),						%% Versão do cabeçalho HTTP
					  payload :: binary(),						%% Corpo da requisição (aceita somente JSON)
					  payload_map :: map(),						%% Corpo da requisição convertida para map após o parser e validação
					  querystring :: binary(),					%% Querystring da requisição
					  querystring_map,							%% Querystring convertida para map após o parser e validação
					  params_url,								%% Map com os parâmetros da URL
					  content_type_in :: binary(),				%% Tipo de conteúdo enviado ao barramento (Ex.: application/json, application/pdf)
					  content_length :: non_neg_integer(), 		%% Largura da requisição
					  content_type :: string(),					%% Tipo de conteúdo (Ex.: application/json)
					  accept :: binary(),						%% Parâmetro ACCEPT HTTP
					  user_agent :: binary(),					%% Parâmetro USER_AGENT HTTP
					  accept_encoding :: string(),				%% Parâmetro ACCEPT_ENCODING HTTP
					  cache_control :: binary(),				%% Parâmetro CACHE-CONTROL HTTP
					  etag :: string(),							%% Parâmetro ETag
					  if_modified_since :: string(),			%% Parâmetro If-Modified-Since
					  if_none_match :: string(),			    %% Parâmetro If-None-Match
					  ip :: tuple(),
					  ip_bin :: binary(),						%% Peer que iniciou a requisição
					  t1,										%% Utilizado para cálculo da latência (Tempo inicial em milisegundos)
					  socket :: gen_tcp:socket(),				%% Socket da requisição
					  worker :: pid(),							%% Processo worker http que vai atender a requisição
					  status_send,								%% Registra que a mensagem foi entregue ou o erro ocorrido na entrega
					  authorization :: binary(),				%% Dados da autenticação da requisição
					  client :: #client{},
					  user :: #user{},							%% Usuário da requisição ou public
					  node_exec = undefined,					%% Node que foi enviado a solicitação
					  status = latency,							%% status: latency, req_done, req_send
					  worker_send,
					  protocol :: atom(),						%% Protocol (http, ldap)
					  protocol_bin :: binary(),	
					  port :: non_neg_integer(),				
					  result_cache = false :: boolean(),
					  result_cache_rid,
					  response_data = <<>>,
					  response_header = #{},
					  req_hash,
					  host :: binary(),							%% Ip do barramento
					  filename :: string(),
					  referer :: binary(),
					  access_token :: binary(),
					  scope :: binary(),
					  oauth2_grant_type :: binary(),
					  oauth2_access_token :: binary(),
					  oauth2_refresh_token :: binary()
					  
				  }).


-record(service_datasource, {id :: non_neg_integer(),
							 rowid :: non_neg_integer(),
							 type :: atom(),
							 driver :: atom(),
							 connection = <<>> :: binary(),
							 table_name = <<>> :: binary(),
							 primary_key = <<>> :: binary(),
							 csv_delimiter = <<";">> :: binary(),
							 sql = <<>> :: binary(),
							 timeout = 30000 :: non_neg_integer(),
							 max_pool_size = 1 :: non_neg_integer(),
							 conn_ref,
							 pid_module,
							 pid_module_ref,
							 owner,
							 owner_ref,
							 pool_name :: string(),
							 parent = undefined :: string()
							}).


-record(service_owner, {  id :: non_neg_integer(),
						   name :: string(),
						   title :: string(),
						   comment :: string()
						}).


-record(service, {  id :: non_neg_integer(), 					%% Id do serviço
					codigo :: non_neg_integer(),				%% Id do serviço banco externo
					rowid,				  						%% Identificador interno do contrato (utilizado para localizar o contrato)
					name :: binary(), 							%% Nome do contrato do serviço (Por default usa-se a própria URL como name)
					url :: string(),  							%% URL do contrato do serviço
					type = <<"GET">> :: binary(),				%% Verbo HTTP do contrato (GET, POST, PUT, DELETE e OPTIONS) ou KERNEL para módulos do barramento
					service :: binary(),						%% Serviço que será executado no contrato
					middleware :: atom(),						%% Miidleware definido para pós processamento do serviço
					module_name :: string(), 					%% Nome do módulo do serviço que vai atender a requisição. Ex.: br.erlangms.HelloWorldService  
					module_name_canonical :: string(), 			%% Nome do módulo canonico do serviço que vai atender a requisição. Ex.: HelloWorldService  
					module :: atom(),  							%% Atom do processo do módulo de serviço que vai atender a requisição
					function_name :: string(),					%% Nome da mensagem ou função que vai ser invocada no processo que vai atender a requisição
					function :: atom(),  						%% Atom da mensagem ou função que vai ser invocada no processo que vai atender a requisição
					id_re_compiled,   							%% Identificador da expressão regular que vai verificar se a URL bate com a URL da requisição
					public = true :: boolean(), 				%% Indica se o contrato estará listado no Portal API Management
					comment :: binary(), 						%% Comentário sobre o que o contrato oferece em termos de serviço
					version = "1.0.0" :: binary(), 				%% Versão do contrato do serviço
					owner :: binary(),  						%% Quem é o proprietário pelo serviço
					async = false :: boolean(),					%% Indica se o serviço será processado em segundo plano (chamada assíncrona)
					querystring :: list(map()),					%% Definição da querystring para o contrato do serviço
					qtd_querystring_req :: non_neg_integer(), 	%% Indica quantas querystrings são obrigatórias
					host :: atom(),  							%% Atom do host onde está o módulo do serviço que vai processar a requisição
					host_name,				  					%% Nome do host onde está o módulo do serviço que vai processar a requisição
					result_cache :: non_neg_integer(), 			%% Indica quanto tempo em milisegundos o resultado vai ficar armazenado em cache (somente para o módulo msbus_static_file_service)
					authorization :: atom(),					%% Forma de autenticação (public, basic, oauth2)
					page,										%% Page django file
					page_module,								%% Page module django file compiled
					page_mime_type = <<"text/html">>,			%% Page mime type
					node,										%% Node ou lista de node onde os serviços estão publicados
					lang = "erlang" :: binary(),				%% Linguagem que foi utilizada para implementar o serviço
					datasource :: #service_datasource{},		%% Datasource para a fonte de dados
					debug = false :: boolean(),					%% Permite habilitar um modo debug (depende da implementação do serviço)
					schema_in :: non_neg_integer(),
					schema_out :: non_neg_integer(),
					pool_size :: non_neg_integer(),
					pool_max :: non_neg_integer(),
					timeout :: non_neg_integer(),
					expires :: non_neg_integer(),
					cache_control :: binary(),
					enable = false :: boolean(),
					content_type :: binary(),					%% Tipo de conteúdo (Ex.: application/json, application/pdf)
					catalog_path :: string(),					%% Local de onde o catálogo foi carregado
					catalog_file :: string(),					%% Nome do arquivo onde está especificado o catálogo
					path :: string(),							%% Local para carregar arquivos estáticos
					redirect_url :: binary(),					%% redirect url						
					tcp_listen_address,
					tcp_listen_address_t,
					tcp_allowed_address,
					tcp_allowed_address_t,
					tcp_max_connections,
					tcp_port,
					tcp_is_ssl = false,
					tcp_ssl_cacertfile,
					tcp_ssl_certfile,
					tcp_ssl_keyfile,
					protocol :: binary(),
					oauth2_with_check_constraint = false :: boolean(),
					oauth2_token_encrypt = false :: boolean(),
					properties :: map(),						%% Outros parâmetros
				    ctrl_insert,
					ctrl_update 
				}).


-record(ctrl_sqlite_table, {file_name :: string(), 
							last_modified :: file:date_time()}).
					

-record(catalog_schema, {id :: non_neg_integer(), 
						 name :: string(),	
						 description :: string(),
						 json_schema :: map()
						}).

-record(schema_type, {id :: non_neg_integer(), 
					  name :: string(),	
					  description :: string(),
					  json_schema :: map()
				}).


-record(produto, {id :: non_neg_integer(), 
				  name :: string(), 
				  price :: non_neg_integer()}).


