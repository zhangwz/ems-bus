#!/bin/sh
#
# author Everton de Vargas Agilar <<evertonagilar@gmail.com>>
#
current_dir=`pwd`
erl -pa $current_dir/ebin deps/mochiweb/ebin deps/jiffy/ebin deps/ecsv/ebin deps/jsx/ebin deps/poolboy/ebin -sname emsbus -setcookie erlangms -eval "ems_bus:start()" -boot start_sasl -config ./priv/conf/elog
