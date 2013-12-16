%%------------------------------------------------------------------------------
%% Copyright 2012 FlowForwarding.org
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
%%-----------------------------------------------------------------------------

%% @author Erlang Solutions Ltd. <openflow@erlang-solutions.com>
%% @copyright 2012 FlowForwarding.org
%% @doc Utility module for nicer tests.
-module(linc_us5_test_utils).

-export([mock/1,
         unmock/1,
         mock_reset/1,
         check_output_on_ports/0,
         check_output_to_groups/0,
         check_output_to_controllers/0,
         check_if_called/1,
         check_if_called/2,
         add_logic_path/0]).
-include_lib("of_protocol/include/of_protocol.hrl").

mock([]) ->
    mocked;
mock([flow | Rest]) ->
    ok = meck:new(linc_us5_flow),
    ok = meck:expect(linc_us5_flow, delete_where_group,
                     fun(_, _) ->
                             ok
                     end),
    ok = meck:expect(linc_us5_flow, initialize,
                fun(_) ->
                        ok
                end),
    mock(Rest);
mock([logic | Rest]) ->
    ok = meck:new(linc_logic),
    ok = meck:expect(linc_logic, send_to_controllers,
                     fun(_, _) ->
                             ok
                     end),
    mock(Rest);
mock([meter | Rest]) ->
    ok = meck:new(linc_us5_meter),
    ok = meck:expect(linc_us5_meter, is_valid,
                     fun (_, X) when X < 8 ->
                             true;
                         (_, _) ->
                             false
                     end),
    meck:expect(linc_us5_meter, apply,
                fun(_, 1, _Pkt) ->
                        drop;
                   (_, _, Pkt) ->
                        {continue, Pkt}
                end),
    mock(Rest);
mock([port | Rest]) ->
    ok = meck:new(linc_us5_port),
    ok = meck:expect(linc_us5_port, send,
                     fun(_, _) ->
                             ok
                     end),
    ok = meck:expect(linc_us5_port, is_valid,
                     fun (_, X) when X>32 ->
                             false;
                         (_, _) ->
                             true
                     end),
    ok = meck:expect(linc_us5_port, initialize,
                     fun(_, _) ->
                             ok
                     end),
    mock(Rest);
mock([port_native | Rest]) ->
    ok = meck:new(linc_us5_port_native),
    ok = meck:expect(linc_us5_port_native, eth,
                     fun(_) ->
                             {socket, 0, pid, <<1,1,1,1,1,1>>}
                     end),
    ok = meck:expect(linc_us5_port_native, tap,
                     fun(_, _) ->
                             {port, pid, <<1,1,1,1,1,1>>}
                     end),
    ok = meck:expect(linc_us5_port_native, close,
                     fun(_) ->
                             ok
                     end),
    ok = meck:expect(linc_us5_port_native, send,
                     fun(_, _, _) ->
                             ok
                     end),
    mock(Rest);
mock([group | Rest]) ->
    ok = meck:new(linc_us5_groups),
    ok = meck:expect(linc_us5_groups, apply,
                     fun(_GroupId, _Pkt) ->
                             ok
                     end),
    ok = meck:expect(linc_us5_groups, is_valid,
                     fun (_, X) when X>32 ->
                             false;
                         (_, _) ->
                             true
                     end),
    ok = meck:expect(linc_us5_groups, update_reference_count,
                     fun(_SwitchId, _GroupId, _Incr) ->
                             ok
                     end),
    ok = meck:expect(linc_us5_groups, initialize,
                     fun(_) ->
                             ok
                     end),
    mock(Rest);
mock([instructions | Rest]) ->
    ok = meck:new(linc_us5_instructions),
    ok = meck:expect(linc_us5_instructions, apply,
                     fun(Pkt, _) ->
                             {stop, Pkt}
                     end),
    mock(Rest);
mock([sup | Rest]) ->
    ok = meck:new(linc_us5_sup),
    ok = meck:expect(linc_us5_sup, start_backend_sup,
                  fun(_) ->
                          {ok, ok}
                  end),
    mock(Rest).

unmock([]) ->
    unmocked;
unmock([flow | Rest]) ->
    ok = meck:unload(linc_us5_flow),
    unmock(Rest);
unmock([logic | Rest]) ->
    ok = meck:unload(linc_logic),
    unmock(Rest);
unmock([meter | Rest]) ->
    ok = meck:unload(linc_us5_meter),
    unmock(Rest);
unmock([port | Rest]) ->
    ok = meck:unload(linc_us5_port),
    unmock(Rest);
unmock([port_native | Rest]) ->
    ok = meck:unload(linc_us5_port_native),
    unmock(Rest);
unmock([group | Rest]) ->
    ok = meck:unload(linc_us5_groups),
    unmock(Rest);
unmock([instructions | Rest]) ->
    ok = meck:unload(linc_us5_instructions),
    unmock(Rest);
unmock([sup | Rest]) ->
    ok = meck:unload(linc_us5_sup),
    unmock(Rest).

mock_reset([]) ->
    ok;
mock_reset([port | Rest]) ->
    ok = meck:reset(linc_us5_port),
    mock_reset(Rest);
mock_reset([_ | Rest]) ->
    mock_reset(Rest).

check_output_on_ports() ->
    [{Pkt, PortNo}
     || {_, {_, send, [Pkt, PortNo]}, ok} <- meck:history(linc_us5_port)].

check_output_to_groups() ->
    [{Pkt, GroupId}
     || {_, {_, apply, [Pkt, GroupId]}, ok} <- meck:history(linc_us5_group)].

check_output_to_controllers() ->
    [{SwitchId, Type, Body}
     || {_, {_, send_to_controllers, [SwitchId, #ofp_message{type = Type,
                                                             body = Body}]}, ok} <- 
            meck:history(linc_logic)].

check_if_called({Module, Fun, Arity}) ->
    check_if_called({Module, Fun, Arity}, {1, times}).

check_if_called({Module, Fun, Arity}, {Times, times}) ->
    History = meck:history(Module),
    case Arity of
        0 ->
            [x || {_, {_, F, []}, _} <- History, F == Fun];
        1 ->
            [x || {_, {_, F, [_]}, _} <- History, F == Fun];
        2 ->
            [x || {_, {_, F, [_, _]}, _} <- History, F == Fun];
        3 ->
            [x || {_, {_, F, [_, _, _]}, _} <- History, F == Fun];
        4 ->
            [x || {_, {_, F, [_, _, _, _]}, _} <- History, F == Fun]
    end == [x || _ <- lists:seq(1, Times)].

add_logic_path() ->
    true = code:add_path("../../linc/ebin").
